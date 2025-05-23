import boto3
import requests

def obtener_ip_publica():
    try:
        ip = requests.get("https://checkip.amazonaws.com", timeout=5).text.strip()
        return ip
    except Exception as e:
        print(f"[ERROR] No se pudo obtener la IP pública: {e}")
        return None

def autorizar_ip_en_security_group(ip_publica, security_group_id, region, profile_name):
    session = boto3.Session(profile_name=profile_name)
    ec2_client = session.client('ec2', region_name=region)

    try:
        ec2_client.authorize_security_group_ingress(
            GroupId=security_group_id,
            IpPermissions=[
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 5432,
                    'ToPort': 5432,
                    'IpRanges': [{'CidrIp': f"{ip_publica}/32"}]
                }
            ]
        )
        print(f"[OK] IP {ip_publica} autorizada correctamente en el Security Group.")
    except ec2_client.exceptions.ClientError as error:
        if 'InvalidPermission.Duplicate' in str(error):
            print(f"[INFO] La IP {ip_publica} ya estaba autorizada previamente.")
        else:
            print(f"[ERROR] Error al autorizar IP: {error}")

if __name__ == "__main__":
    # Variables que puedes adaptar según tu entorno
    SECURITY_GROUP_ID = "sg-xxxxxxxxxxxxx"
    REGION = "xx-xxxx-x"
    PROFILE_NAME = "xxxxxx"

    ip_publica = obtener_ip_publica()
    if ip_publica:
        autorizar_ip_en_security_group(ip_publica, SECURITY_GROUP_ID, REGION, PROFILE_NAME)
