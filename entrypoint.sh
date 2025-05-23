#!/bin/bash

echo "[INFO] Iniciando entorno AWSVersion1.5..."

# ======== Login automático AWS SSO ========
if [ -f "/app/scripts/aws_sso_auto_login.sh" ]; then
  bash /app/scripts/aws_sso_auto_login.sh
else
  echo "[WARN] Script de login SSO no encontrado. Continuando de todos modos..."
fi

# ======== Bootstrap de infraestructura ========
if [ -f "/app/scripts/bootstrap.sh" ]; then
  bash /app/scripts/bootstrap.sh
fi

# ======== Configuración de entorno ========
APP_ENV=${APP_ENV:-development}
echo "[INFO] Entorno detectado: $APP_ENV"

# ======== Lanzar aplicación ========
if [ "$APP_ENV" == "production" ]; then
  echo "[INFO] Lanzando Gunicorn en modo producción..."
  exec gunicorn run:app \
    --bind 0.0.0.0:5000 \
    --workers 4 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile -
else
  echo "[INFO] Lanzando en modo desarrollo (python run.py)..."
  exec python /app/run.py
fi
