#!/bin/bash

echo "[INFO] Verificando existencia del bucket S3: $BUCKET_NAME..."

aws s3api head-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --profile "$PROFILE" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "[OK] El bucket S3 '$BUCKET_NAME' ya existe."
else
    echo "[INFO] Bucket no encontrado. Intentando crear el bucket..."

    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION" \
        --profile "$PROFILE"

    if [ $? -eq 0 ]; then
        echo "[OK] Bucket S3 '$BUCKET_NAME' creado exitosamente."
    else
        echo "[ERROR] Error al crear el bucket S3. Abortando."
        exit 1
    fi
fi
