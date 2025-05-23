#!/bin/bash

echo "[INFO] Validando estado de la API Gateway..."

URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/"
MAX_RETRIES=2
retry_count=0

while true; do
    STATUS_CODE=$(curl --connect-timeout 5 --max-time 10 -s -o /dev/null -w "%{http_code}" "$URL")
    
    if [[ "$STATUS_CODE" == "200" ]]; then
        echo "[OK] API Gateway responde correctamente (HTTP 200)."
        break
    else
        if [[ $retry_count -ge $MAX_RETRIES ]]; then
            echo "[ERROR] API Gateway sigue sin responder correctamente tras varios intentos. Abortando."
            exit 1
        fi
        echo "[WARNING] API Gateway no responde correctamente (Status: $STATUS_CODE). Reintentando despliegue..."
        aws apigateway create-deployment \
            --rest-api-id "$API_ID" \
            --stage-name prod \
            --region "$REGION" \
            --profile "$PROFILE"
        sleep 5
        retry_count=$((retry_count + 1))
    fi
done
