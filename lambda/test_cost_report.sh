#!/bin/bash

# URL del endpoint desplegado en API Gateway
ENDPOINT="https://gl6otrq289.execute-api.eu-north-1.amazonaws.com/Prod/cost-report"

# Ruta del archivo JSON relativo a este script
EVENT_FILE="lambda/event.json"

# Verifica que el archivo exista
if [ ! -f "$EVENT_FILE" ]; then
  echo " Error: No se encontró el archivo $EVENT_FILE"
  exit 1
fi

# Ejecuta la solicitud POST
echo "🚀 Enviando POST a $ENDPOINT..."
curl -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -d @"$EVENT_FILE"

echo -e "\n Petición enviada correctamente."
