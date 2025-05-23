#!/bin/bash
PROFILE="sediaz"
REGION="eu-north-1"

echo "[INFO] Apagando logs de CloudWatch innecesarios..."
LOG_GROUPS=$(aws logs describe-log-groups   --query "logGroups[?starts_with(logGroupName,'/aws/lambda/')].logGroupName"   --region "$REGION" --profile "$PROFILE" --output text)

if [[ -n "$LOG_GROUPS" ]]; then
  for LOG in $LOG_GROUPS; do
    aws logs delete-log-group --log-group-name "$LOG"       --region "$REGION" --profile "$PROFILE"
    echo "[OK] Grupo de logs eliminado: $LOG"
  done
else
  echo "[INFO] No se encontraron logs activos para eliminar."
fi
