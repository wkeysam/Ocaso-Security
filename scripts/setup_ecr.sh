#!/bin/bash

echo "[INFO] Verificando existencia del repositorio ECR: $REPO_NAME..."

aws ecr describe-repositories \
    --repository-names "$REPO_NAME" \
    --region "$REGION" \
    --profile "$PROFILE" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "[OK] El repositorio ECR '$REPO_NAME' ya existe."
else
    echo "[INFO] Repositorio no encontrado. Creándolo..."
    aws ecr create-repository \
        --repository-name "$REPO_NAME" \
        --region "$REGION" \
        --profile "$PROFILE"

    if [ $? -eq 0 ]; then
        echo "[OK] Repositorio ECR '$REPO_NAME' creado exitosamente."
    else
        echo "[ERROR] Error al crear el repositorio ECR. Abortando."
        exit 1
    fi
fi
