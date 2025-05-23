#!/bin/bash

PROFILE="xxxxxxx"
MAX_RETRIES=3
RETRY_INTERVAL=5

echo "[INFO] Verificando sesión SSO activa para el perfil '$PROFILE'..."

for ((i=1; i<=MAX_RETRIES; i++)); do
    aws sts get-caller-identity --profile "$PROFILE" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "[OK] Sesión SSO válida detectada en intento $i."
        exit 0
    else
        echo "[WARN] No hay sesión activa. Intentando login SSO (intento $i)..."
        aws sso login --profile "$PROFILE"
        sleep $RETRY_INTERVAL
    fi
done

echo "[ERROR] No se pudo establecer una sesión SSO tras varios intentos. Abortando."
exit 1


