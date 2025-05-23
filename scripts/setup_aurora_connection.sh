#!/bin/bash

echo "[INFO] Verificando conexión a Aurora PostgreSQL..."

if ! command -v psql &> /dev/null; then
    echo "[INFO] psql no encontrado. Instalando cliente PostgreSQL..."
    sudo apt-get update && sudo apt-get install -y postgresql-client
fi

aurora_attempts=0
max_attempts=3

until psql "postgresql://${AURORA_USER}:${AURORA_PASSWORD}@${AURORA_HOST}:${AURORA_PORT}/${AURORA_DBNAME}" -c '\\q' 2>/dev/null || [ $aurora_attempts -ge $max_attempts ]; do
    echo "[WARNING] Fallo de conexión. Reintentando en 5 segundos..."
    sleep 5
    aurora_attempts=$((aurora_attempts + 1))
done

if [ $aurora_attempts -lt $max_attempts ]; then
    echo "[OK] Conexión a Aurora PostgreSQL exitosa."
else
    echo "[ERROR] No se pudo conectar a Aurora tras varios intentos. Abortando."
    exit 1
fi
