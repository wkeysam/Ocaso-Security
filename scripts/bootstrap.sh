#!/bin/bash

# =========================
# Limpiar posibles conflictos de entorno
# =========================
unset AWS_REGION
unset AWS_DEFAULT_REGION

# =========================
# Configuración de logs automáticos
# =========================
LOG_DIR="$HOME/logs"
mkdir -p $LOG_DIR
exec > >(tee $LOG_DIR/deploy-$(date +"%Y%m%d-%H%M%S").log) 2>&1

echo "=============================="
echo " AWS Bootstrap - Infraestructura Completa "
echo "=============================="
# ========================
# FUNCIONES DE UTILIDAD
# ========================

check_script() {
    if [ ! -f "$1" ]; then
        echo "[ERROR] Script '$1' no encontrado. Abortando."
        exit 1
    fi
}

run_script() {
    echo "[INFO] Ejecutando $1..."
    bash "$1"
}

# ========================
# EJECUCIÓN SECUENCIAL
# ========================

# 1. Seguridad del entorno (si quieres integrarlo)
if [ -f "./scripts/secure_bashrc.sh" ]; then
    echo "[INFO] Aplicando configuraciones de seguridad de entorno gráfico..."
    bash ./scripts/secure_bashrc.sh
fi

# 2. Login AWS SSO
check_script "./scripts/setup_sso.sh"
run_script "./scripts/setup_sso.sh"

# 3. Autorizar IP en Security Group
check_script "./scripts/setup_security_group.sh"
run_script "./scripts/setup_security_group.sh"

# 4. Conexión a Aurora
check_script "./scripts/setup_aurora_connection.sh"
run_script "./scripts/setup_aurora_connection.sh"

# 5. Verificar/Crear ECR
check_script "./scripts/setup_ecr.sh"
run_script "./scripts/setup_ecr.sh"

# 6. Verificar/Crear API Gateway + Lambda
check_script "./scripts/setup_api_gateway.sh"
run_script "./scripts/setup_api_gateway.sh"

# 7. Validar API Gateway (HTTP 200)
check_script "./scripts/validate_api.sh"
run_script "./scripts/validate_api.sh"

# 8. Verificar/Crear Bucket S3
check_script "./scripts/setup_s3.sh"
run_script "./scripts/setup_s3.sh"

# ========================
# FINAL
# ========================
echo "[OK] Despliegue de infraestructura AWS completado correctamente."
