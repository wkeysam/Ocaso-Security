#!/bin/bash

echo "[INFO] Verificando existencia de API Gateway: $REPO_NAME..."

API_ID=$(aws apigateway get-rest-apis \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "items[?name=='$REPO_NAME'].id" \
    --output text)

if [ -z "$API_ID" ]; then
    echo "[INFO] API Gateway no encontrada. Creando nueva API Gateway..."

    API_ID=$(aws apigateway create-rest-api \
        --name "$REPO_NAME" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --query "id" \
        --output text)

    ROOT_ID=$(aws apigateway get-resources \
        --rest-api-id "$API_ID" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --query "items[0].id" \
        --output text)

    aws apigateway put-method \
        --rest-api-id "$API_ID" \
        --resource-id "$ROOT_ID" \
        --http-method GET \
        --authorization-type "NONE" \
        --region "$REGION" \
        --profile "$PROFILE"

    aws apigateway put-integration \
        --rest-api-id "$API_ID" \
        --resource-id "$ROOT_ID" \
        --http-method GET \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$LAMBDA_NAME/invocations" \
        --region "$REGION" \
        --profile "$PROFILE"

    aws apigateway create-deployment \
        --rest-api-id "$API_ID" \
        --stage-name prod \
        --region "$REGION" \
        --profile "$PROFILE"

    aws lambda add-permission \
        --function-name "$LAMBDA_NAME" \
        --statement-id "apigateway-access" \
        --action "lambda:InvokeFunction" \
        --principal "apigateway.amazonaws.com" \
        --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/GET/" \
        --region "$REGION" \
        --profile "$PROFILE" > /dev/null 2>&1

    echo "[OK] API Gateway y Lambda desplegados correctamente."
else
    echo "[OK] API Gateway ya existente con ID: $API_ID."
fi
