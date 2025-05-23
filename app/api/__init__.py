from flask import Blueprint

# Importa cada módulo de la API
from .cost_api import cost_api_bp         #  /api/procesar-costos
from .logs_api import api_logs_bp         #  /api/logs-seguridad

# Blueprint “contenedor” para /api
api_bp = Blueprint("api", __name__, url_prefix="/api")

# Se registran los sub-blueprints
api_bp.register_blueprint(cost_api_bp)
api_bp.register_blueprint(api_logs_bp)


