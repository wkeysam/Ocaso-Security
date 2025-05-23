import boto3
import gzip
import psycopg2
from io import BytesIO
import json

#import socket

#def lambda_handler(event, context):
  #  try:
     #   host = "proyectodtbia.cluster-cdkg6qo6gdcz.eu-north-1.rds.amazonaws.com"
     #   port = 5432
     #   socket.setdefaulttimeout(5)
     #  s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
     #   s.connect((host, port))
     #   print("Conexión exitosa al puerto 5432")
     #   s.close()
     #  except Exception as e:
     #   print(f"Fallo de conexión: {e}")
#Este fragmento sirve para una prueba de socket de red por si da algún fallo, basado en experiencias que he tenido.

def get_db_credentials(secret_name="rds-db-credentials/agasmau", region="eu-north-1"):
    secrets_client = boto3.client("secretsmanager", region_name=region)
    secret_value = secrets_client.get_secret_value(SecretId=secret_name)
    return json.loads(secret_value["SecretString"])

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    db_credentials = get_db_credentials()

    db_name = "postgres"
    db_host = db_credentials["host"]
    db_port = db_credentials["port"]
    db_user = db_credentials["username"]
    db_pass = db_credentials["password"]

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        print(f"Procesando archivo: s3://{bucket}/{key}")

        # Leer y descomprimir el archivo .gz
        try:
            response = s3.get_object(Bucket=bucket, Key=key)
            with gzip.GzipFile(fileobj=BytesIO(response['Body'].read())) as gz:
                content = gz.read().decode('utf-8')
                lines = content.strip().split('\n')
        except Exception as e:
            print(f"Error al leer el archivo S3: {e}")
            continue

        # Conectar e insertar en la base de datos
        conn = None
        try:
            conn = psycopg2.connect(
                dbname=db_name,
                user=db_user,
                password=db_pass,
                host=db_host,
                port=db_port
                connect_timeout=5
            )
            with conn:
                with conn.cursor() as cur:
                    current_date = None
                    for line in lines:
                        line = line.strip()
                        if not line:
                            continue
                        if line.startswith("Fecha:"):
                            current_date = line.split("Fecha:")[1].strip()
                        elif ":" in line and current_date:
                            try:
                                servicio, costo = line.split(":")
                                servicio = servicio.strip()
                                costo = float(costo.strip().replace("$", ""))
                                cur.execute(
                                    "INSERT INTO aws_costs (fecha, servicio, costo) VALUES (%s, %s, %s)",
                                    (current_date, servicio, costo)
                                )
                            except Exception as parse_err:
                                print(f"Error procesando línea: {line} - {parse_err}")
            print("Datos insertados correctamente.")
        except Exception as db_err:
            print(f"Error al conectar o insertar en la base de datos: {db_err}")
        finally:
            if conn:
                conn.close()

    print("Finalizando función...")






