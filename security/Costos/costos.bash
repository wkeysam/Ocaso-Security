#!/bin/bash

echo
echo "=============================="
echo "     Análisis de Costos AWS    "
echo "=============================="

PROFILE="sediaz"
REGION="eu-north-1"

# Definir rango de fechas
START_DATE=$(date -d "-7 days" +"%Y-%m-%d")
END_DATE=$(date +"%Y-%m-%d")

echo "[INFO] Consultando costos de AWS desde $START_DATE hasta $END_DATE..."

# Llamada real a Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'ResultsByTime[].{Fecha:Start, Costo:Total.UnblendedCost.Amount}' \
  --output table

if [ $? -ne 0 ]; then
    echo "[ERROR] No se pudo obtener el reporte de costos. Verifica que Cost Explorer esté habilitado en tu cuenta AWS."
    exit 1
fi

echo
echo "[OK] Análisis de costos completado."
