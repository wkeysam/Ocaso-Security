# app/models/__init__.py
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()  # ← instancia única del ORM

# registra los modelos para que SQLAlchemy los detecte
from .user import User, Nota, ReflexionSugerida  # noqa: E402


