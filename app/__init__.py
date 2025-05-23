# app/__init__.py
import os
from flask import Flask, redirect, url_for, session
from flask_migrate import Migrate
from app.config import DevelopmentConfig, TestingConfig, ProductionConfig
from app.models import db                      # ← instancia única del ORM

migrate = Migrate()


def create_app(config_name: str = "development") -> Flask:
    app = Flask(__name__)

    # ---------- cargar configuración ----------
    config_map = {
        "development": DevelopmentConfig,
        "testing": TestingConfig,
        "production": ProductionConfig,
    }
    app.config.from_object(config_map[config_name])

    # En producción exigimos DATABASE_URL
    if config_name == "production" and not app.config.get("SQLALCHEMY_DATABASE_URI"):
        raise ValueError("DATABASE_URL no está configurada para producción")

    # ---------- inicializar extensiones ----------
    db.init_app(app)
    migrate.init_app(app, db)

    # ---------- blueprints ----------
    from app.routes.auth_routes import auth_bp
    from app.api import api_bp              # api_bp = contenedor /api/…

    app.register_blueprint(auth_bp)
    app.register_blueprint(api_bp)          # ya incluye cost_api y logs_api

    # ---------- ruta raíz ----------
    @app.route("/")
    def home():
        # Si el usuario es admin → a la subida de costes
        if session.get("autenticado") and session.get("es_admin"):
            return redirect(url_for("cost_api.procesar_costos"))
        # Si no, a la verificación de PIN
        return redirect(url_for("auth.verificar_pin"))

    return app




