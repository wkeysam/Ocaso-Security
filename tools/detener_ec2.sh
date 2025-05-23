#!/bin/bash
PROFILE="sediaz"
REGION="eu-north-1"

echo "[INFO] Apagando EC2..."
INSTANCES=$(aws ec2 describe-instances   --filters "Name=instance-state-name,Values=running"   --query "Reservations[*].Instances[*].InstanceId"   --region "$REGION" --profile "$PROFILE" --output text)

if [[ -n "$INSTANCES" ]]; then
  aws ec2 stop-instances --instance-ids $INSTANCES     --region "$REGION" --profile "$PROFILE"
  echo "[OK] Instancias EC2 detenidas: $INSTANCES"
else
  echo "[INFO] No hay instancias EC2 en ejecución."
fi
