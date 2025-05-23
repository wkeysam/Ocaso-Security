from app.models import db
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

# Roles permitidos
ROLES_VALIDOS = ["admin", "usuario", "supervisor", "auditor"]

class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(100), unique=True, nullable=False)
    pin_hash = db.Column(db.String(255), nullable=False)
    rol = db.Column(db.String(50), nullable=False, default="usuario")
    activo = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    def set_pin(self, pin):
        self.pin_hash = generate_password_hash(pin)

    def check_pin(self, pin):
        return check_password_hash(self.pin_hash, pin)

    def set_rol(self, nuevo_rol):
        """Asignar un nuevo rol al usuario validando contra la lista de roles permitidos."""
        if nuevo_rol in ROLES_VALIDOS:
            self.rol = nuevo_rol
        else:
            raise ValueError(f"Rol '{nuevo_rol}' no es válido. Roles permitidos: {ROLES_VALIDOS}")

    def desactivar(self):
        """Soft delete del usuario."""
        self.activo = False

    def __repr__(self):
        return f"<User {self.username} (Rol: {self.rol})>"
class Nota(db.Model):
    __tablename__ = "notas"

    id = db.Column(db.Integer, primary_key=True)
    contenido = db.Column(db.Text, nullable=False)
    visibilidad = db.Column(db.String(20), default="privada")  # privada, íntima, círculo, pública
    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)

    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
class ReflexionSugerida(db.Model):
    __tablename__ = "reflexiones"

    id = db.Column(db.Integer, primary_key=True)
    texto = db.Column(db.Text, nullable=False)
    fecha = db.Column(db.DateTime, default=datetime.utcnow)

    activa = db.Column(db.Boolean, default=True)
