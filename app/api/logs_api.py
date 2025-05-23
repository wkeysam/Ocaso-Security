from flask import Blueprint, Response
import os

api_logs_bp = Blueprint("logs_api", __name__)

@api_logs_bp.route("/api/logs-seguridad", methods=["GET"])
def obtener_logs_seguridad():
    ruta_logs = os.path.expanduser("~/wsl_x_display.log")  # o la ruta que prefieras

    if os.path.exists(ruta_logs):
        with open(ruta_logs, "r") as f:
            contenido = f.read()
        return Response(contenido, mimetype="text/plain")
    else:
        return Response(
            "⚠ El archivo de logs no existe. Posiblemente no estás en WSL o aún no se ha generado.",
            mimetype="text/plain"
    )