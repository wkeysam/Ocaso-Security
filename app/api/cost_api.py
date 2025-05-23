from flask import Blueprint, request, jsonify, session
import boto3
import gzip
import psycopg2
from io import BytesIO
import os
import json
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

cost_api_bp = Blueprint("cost_api", __name__)

def get_db_credentials(secret_name="rds-db-credentials/agasmau", region="eu-north-1"):
    secrets_client = boto3.client("secretsmanager", region_name=region)
    secret_value = secrets_client.get_secret_value(SecretId=secret_name)
    return json.loads(secret_value["SecretString"])

def procesar_batch(cur, batch, current_date):
    """Procesar un batch de registros e insertarlos en la DB."""
    for line in batch:
        try:
            servicio, costo = line.split(":")
            servicio = servicio.strip()
            costo = float(costo.strip().replace("$", ""))
            cur.execute(
                "INSERT INTO aws_costs (fecha, servicio, costo) VALUES (%s, %s, %s)",
                (current_date, servicio, costo)
            )
        except Exception as parse_err:
            logger.error(f"Error procesando línea: {line} - {parse_err}")

@cost_api_bp.route("/procesar-costos", methods=["POST"])
def procesar_costos():
    if not session.get("autenticado"):
        logger.warning("Intento de acceso no autorizado")
        return jsonify({"error": "No autorizado"}), 403

    if "archivo" not in request.files:
        logger.error("No se proporcionó un archivo en la solicitud")
        return jsonify({"error": "Archivo no proporcionado"}), 400

    archivo = request.files["archivo"]
    if not archivo.filename.endswith(".csv.gz"):
        logger.error("Archivo recibido no es .csv.gz")
        return jsonify({"error": "El archivo debe ser .csv.gz"}), 400

    conn = None

    try:
        # Obtener credenciales
        db_credentials = get_db_credentials()
        db_name = "postgres"
        db_host = db_credentials["host"]
        db_port = db_credentials["port"]
        db_user = db_credentials["username"]
        db_pass = db_credentials["password"]

        # Descomprimir archivo
        with gzip.GzipFile(fileobj=BytesIO(archivo.read())) as gz:
            content = gz.read().decode('utf-8')
            lines = content.strip().split('\n')

        conn = psycopg2.connect(
            dbname=db_name,
            user=db_user,
            password=db_pass,
            host=db_host,
            port=db_port
        )

        with conn:
            with conn.cursor() as cur:
                current_date = None
                batch = []
                chunk_size = 1000  # Procesar 1000 líneas a la vez

                for i, line in enumerate(lines, 1):
                    line = line.strip()
                    if not line:
                        continue
                    if line.startswith("Fecha:"):
                        current_date = line.split("Fecha:")[1].strip()
                        logger.info(f"Detectada nueva fecha: {current_date}")
                    elif ":" in line and current_date:
                        batch.append(line)

                        if len(batch) >= chunk_size:
                            procesar_batch(cur, batch, current_date)
                            batch = []

                # Procesar cualquier batch restante
                if batch:
                    procesar_batch(cur, batch, current_date)

        logger.info("Archivo procesado e insertado correctamente en la base de datos")
        return jsonify({"mensaje": "Datos procesados e insertados correctamente."})

    except Exception as e:
        logger.exception(f"Error durante el procesamiento del archivo: {e}")
        return jsonify({"error": f"Error interno: {str(e)}"}), 500
    finally:
        if conn:
            conn.close()
            logger.info("Conexión a base de datos cerrada.")

