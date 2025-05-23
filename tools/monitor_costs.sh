#!/bin/bash
echo "[DEBUG] Script iniciado correctamente."
PROFILE="sediaz"
REGION="eu-north-1"
THRESHOLD=0.10
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)

COST=$(aws ce get-cost-and-usage \
  --time-period Start=$YESTERDAY,End=$TODAY \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'ResultsByTime[0].Total.UnblendedCost.Amount' \
  --output text)

echo "[INFO] Coste detectado: $COST USD"

if (( $(echo "$COST > $THRESHOLD" | bc -l) )); then
  echo ""
  echo "=============================="
  echo "[ALERTA] COSTE ANÓMALO DETECTADO: $COST USD"
  echo "=============================="

  # Detectar EC2 con tag Name=Ocaso-Server
  EC2_INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=Ocaso-Server" "Name=instance-state-name,Values=running" \
    --profile "$PROFILE" --region "$REGION" \
    --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null)

  # Detectar Lambda con tag Name=Ocaso-Lambda
  LAMBDA_NAME=$(aws lambda list-functions \
    --query "Functions[?contains(FunctionName, 'Ocaso')].FunctionName" \
    --region "$REGION" --profile "$PROFILE" \
    --output text | head -n 1)

  echo ""
  echo "1) Solo mostrar"
  echo "2) Enviar alerta a Telegram"
  echo "3) Apagar EC2 y Lambda ($EC2_INSTANCE_ID / $LAMBDA_NAME)"
  echo "4) Salir"
  read -p "Opción [1-4]: " OPCION

  case $OPCION in
    1)
      echo "[INFO] Mostrando coste sin acciones."
      ;;
    2)
      if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        echo "[ERROR] Variables TELEGRAM_BOT_TOKEN o TELEGRAM_CHAT_ID no definidas."
      else
        echo "[INFO] Enviando alerta a Telegram..."
        curl -s -X POST https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage \
          -d chat_id=${TELEGRAM_CHAT_ID} \
          -d text="Alerta de costos: $COST USD detectado el $TODAY"
      fi
      ;;
    3)
      if [[ "$EC2_INSTANCE_ID" != "None" && "$EC2_INSTANCE_ID" != "" ]]; then
        echo "[INFO] Deteniendo EC2 ($EC2_INSTANCE_ID)..."
        aws ec2 stop-instances --instance-ids "$EC2_INSTANCE_ID" --region "$REGION" --profile "$PROFILE"
      else
        echo "[WARN] No se encontró EC2 con tag Ocaso-Server"
      fi

      if [[ "$LAMBDA_NAME" != "" ]]; then
        echo "[INFO] Desactivando Lambda ($LAMBDA_NAME)..."
        aws lambda update-function-configuration --function-name "$LAMBDA_NAME" \
          --region "$REGION" --profile "$PROFILE" --timeout 1
      else
        echo "[WARN] No se encontró Lambda con nombre Ocaso"
      fi
      ;;
    4)
      echo "[INFO] Cancelado por el usuario."
      exit 0
      ;;
    *)
      echo "[ERROR] Opción inválida."
      ;;
  esac
else
  echo "[OK] Coste dentro del rango normal."
fi
