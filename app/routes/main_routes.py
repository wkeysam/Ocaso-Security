from flask import Blueprint, render_template, redirect, url_for, session, flash
from app.models import User, Reflexion
from functools import wraps
from datetime import datetime
from middleware.require_auth import require_login_y_pin
main_bp = Blueprint("main", __name__)

# Decorador login_required
def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get("autenticado"):
            flash("Necesitas iniciar sesión", "warning")
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated

# Ruta raíz que decide a dónde enviar al usuario
@main_bp.route("/")
def home():
    if not session.get("user_id"):
        return redirect(url_for("auth.login"))
    if not session.get("autenticado"):
        return redirect(url_for("auth.verificar_pin"))
    return redirect(url_for("main.dashboard"))

# Dashboard con datos reales
@main_bp.route("/dashboard")
@require_login_y_pin
def dashboard():
    user_id = session.get("user_id")
    user = User.query.get(user_id)

    notas = Reflexion.query.filter_by(usuario_id=user_id).order_by(Reflexion.fecha_creacion.desc()).all()

    resumen = {}
    for nota in notas:
        fecha = nota.fecha_creacion.strftime("%Y-%m-%d")
        resumen[fecha] = resumen.get(fecha, 0) + 1

    fechas = list(resumen.keys())
    cantidades = list(resumen.values())

    return render_template(
        "index.html",
        notas_reflexion=notas,
        fechas=fechas,
        cantidades=cantidades,
        total_reflexiones=len(notas),
        ultima_fecha=notas[0].fecha_creacion.strftime('%d/%m/%Y') if notas else "N/A"
    )

# Logout del sistema
@main_bp.route("/logout")
def logout():
    session.clear()
    flash("Sesión cerrada correctamente", "success")
    return redirect(url_for("auth.login"))
