#!/bin/bash

echo "[INFO] Autorizando IP actual en Security Group..."

MY_IP=$(curl -s ifconfig.me)
CIDR="${MY_IP}/32"

EXISTE=$(aws ec2 describe-security-groups \
  --group-ids "$SECURITY_GROUP_ID" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\`].IpRanges[?CidrIp==\`${CIDR}\`]" \
  --output text)

if [ -z "$EXISTE" ]; then
    aws ec2 authorize-security-group-ingress \
      --group-id "$SECURITY_GROUP_ID" \
      --protocol tcp \
      --port 5432 \
      --cidr "$CIDR" \
      --region "$REGION" \
      --profile "$PROFILE"
    echo "[OK] IP $CIDR autorizada correctamente en Security Group."
else
    echo "[OK] IP $CIDR ya tenía acceso autorizado."
fi
