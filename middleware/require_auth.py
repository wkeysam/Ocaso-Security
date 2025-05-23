from flask import session, redirect, url_for, flash, request
from functools import wraps

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get("autenticado"):
            # Solo mostrar mensaje si no venimos ya del login
            if not request.path.startswith("/login"):
                flash("Necesitas iniciar sesión", "warning")
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated
def require_login_y_pin(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get("user_id"):
            flash("Debes iniciar sesión primero", "warning")
            return redirect(url_for("auth.login"))
        if not session.get("autenticado"):
            flash("Primero verifica tu contraseña", "warning")
            return redirect(url_for("auth.verificar_pin"))
        return f(*args, **kwargs)
    return decorated
