#!/bin/bash

# Config
BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
CHAT_ID="${TELEGRAM_CHAT_ID}"
API_URL="https://api.telegram.org/bot${BOT_TOKEN}"
REGION="eu-north-1"
PROFILE="sediaz"

echo "[INFO] Bot de Telegram arrancado..."

get_instance_id() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=Ocaso-Server" "Name=instance-state-name,Values=running" \
    --profile "$PROFILE" --region "$REGION" \
    --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null
}

get_lambda_name() {
  aws lambda list-functions \
    --query "Functions[?contains(FunctionName, 'Ocaso')].FunctionName" \
    --region "$REGION" --profile "$PROFILE" \
    --output text | head -n 1
}

send_message() {
  local text="$1"
  curl -s -X POST "$API_URL/sendMessage" -d chat_id="$CHAT_ID" -d text="$text"
}

while true; do
  UPDATES=$(curl -s "$API_URL/getUpdates?offset=-1")
  MESSAGE=$(echo "$UPDATES" | grep -oP '"text":"\K[^"]+')

  case "$MESSAGE" in
    "/start")
      send_message " ¡Hola! Soy el bot de control de Ocaso. Comandos disponibles:\n\n/estado – Ver recursos activos\n/apagar – Apagar EC2 y Lambda\n/help – Ayuda"
      ;;
    "/estado")
      INSTANCE_ID=$(get_instance_id)
      LAMBDA_NAME=$(get_lambda_name)
      send_message " Estado actual:\nEC2: ${INSTANCE_ID:-No activa}\nLambda: ${LAMBDA_NAME:-No encontrada}"
      ;;
    "/apagar")
      INSTANCE_ID=$(get_instance_id)
      LAMBDA_NAME=$(get_lambda_name)

      if [[ "$INSTANCE_ID" != "None" && "$INSTANCE_ID" != "" ]]; then
        aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --profile "$PROFILE"
        send_message " EC2 ($INSTANCE_ID) detenida."
      else
        send_message " No se encontró instancia EC2 activa con tag Ocaso-Server."
      fi

      if [[ "$LAMBDA_NAME" != "" ]]; then
        aws lambda update-function-configuration --function-name "$LAMBDA_NAME" \
          --region "$REGION" --profile "$PROFILE" --enabled false
        send_message " Lambda ($LAMBDA_NAME) desactivada temporalmente."
      else
        send_message " No se encontró ninguna Lambda Ocaso activa."
      fi
      ;;
    "/help")
      send_message "ℹ Comandos disponibles:\n/start\n/estado\n/apagar"
      ;;
  esac

  sleep 5
done

