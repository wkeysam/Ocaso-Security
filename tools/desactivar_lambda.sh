#!/bin/bash
PROFILE="sediaz"
REGION="eu-north-1"

echo "[INFO] Desactivando funciones Lambda (que contengan 'Ocaso')..."
LAMBDAS=$(aws lambda list-functions   --query "Functions[?contains(FunctionName, 'Ocaso')].FunctionName"   --region "$REGION" --profile "$PROFILE" --output text)

if [[ -n "$LAMBDAS" ]]; then
  for LAMBDA in $LAMBDAS; do
    aws lambda put-function-concurrency       --function-name "$LAMBDA"       --reserved-concurrent-executions 0       --region "$REGION" --profile "$PROFILE"
    echo "[OK] Lambda desactivada: $LAMBDA"
  done
else
  echo "[INFO] No se encontraron Lambdas con nombre 'Ocaso'."
fi
