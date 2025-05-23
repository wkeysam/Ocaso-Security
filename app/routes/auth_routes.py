from flask import Blueprint, render_template, redirect, url_for, request, session, flash, jsonify
from app.models import db, User
import os
from datetime import datetime
from functools import wraps
from middleware.require_jwt import require_jwt

auth_bp = Blueprint("auth", __name__)
RECAPTCHA_SECRET_KEY = os.getenv("RECAPTCHA_SECRET_KEY")


# ================================
# DECORADORES
# ================================

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get("autenticado"):
            flash("Necesitas iniciar sesión", "warning")
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated

def solo_admin(f):
    @wraps(f)
    def decorado(*args, **kwargs):
        if not session.get("autenticado") or not session.get("es_admin"):
            flash("Acceso denegado. Solo administradores", "danger")
            return redirect(url_for("auth.verificar_pin"))
        return f(*args, **kwargs)
    return decorado


# ================================
# RUTAS PÚBLICAS
# ================================
@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username")
        pin = request.form.get("pin")

        user = User.query.filter_by(username=username).first()

        if not user or not user.check_pin(pin):
            flash("Credenciales incorrectas", "error")
            return redirect(url_for("auth.login"))

        # Guardamos en la sesión
        session["user_id"] = user.id
        session["username"] = user.username
        session["autenticado"] = False
        session["es_admin"] = user.es_admin

        return redirect(url_for("auth.verificar_pin"))

    return render_template("login.html")


@auth_bp.route("/registro", methods=["GET", "POST"])
def registro():
    if request.method == "POST":
        username = request.form.get("username")
        pin = request.form.get("pin")

        if not username or not pin:
            flash("Todos los campos son obligatorios", "danger")
            return redirect(url_for("auth.registro"))

        if User.query.filter_by(username=username).first():
            flash("Este nombre de usuario ya está registrado", "warning")
            return redirect(url_for("auth.registro"))

        user = User(username=username)
        user.set_pin(pin)

        db.session.add(user)
        db.session.commit()

        # Guardar en sesión
        session["username"] = username
        session["user_id"] = user.id
        session["email"] = username  # ✅ IMPORTANTE para que aparezca en /verificar-pin
        session["autenticado"] = False

        flash("Usuario registrado correctamente. Verifica tu PIN", "success")
        return redirect(url_for("auth.verificar_pin"))

    return render_template("registro.html")

@auth_bp.route("/verificar-pin", methods=["GET", "POST"])
def verificar_pin():
    username = session.get("username")  # Lo obtenemos al inicio

    if not username:
        flash("Primero debes iniciar sesión", "danger")
        return redirect(url_for("auth.login"))

    if request.method == "POST":
        pin = request.form.get("pin")
        user = User.query.filter_by(username=username).first()

        if user and user.check_pin(pin):
            session["autenticado"] = True
            session["es_admin"] = user.es_admin
            flash("Verificación completada", "success")
            return redirect(url_for("main.dashboard"))
        else:
            flash("PIN incorrecto", "danger")

    return render_template("verificar_pin.html")
    
@auth_bp.route("/logout")
def logout():
    session.clear()
    flash("Sesión cerrada correctamente", "success")
    return redirect(url_for("auth.login"))


@auth_bp.route("/solicitar-cambio", methods=["GET", "POST"])
def solicitar_cambio():
    if request.method == "POST":
        email = request.form.get("email")
        mensaje = request.form.get("mensaje", "")

        if not email:
            flash("El campo de correo o usuario es obligatorio", "danger")
            return redirect(url_for("auth.solicitar_cambio"))

        # Guardar la solicitud en el sistema manual (CSV)
        from tools.manual_pin_change import registrar_solicitud
        registrar_solicitud(email=email, mensaje=mensaje)

        flash("Solicitud enviada correctamente. Un administrador la revisará.", "success")
        return redirect(url_for("auth.login"))

    return render_template("solicitar_cambio.html")

# ================================
# RUTAS PROTEGIDAS
# ================================

@auth_bp.route("/dashboard")
@login_required
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


# ================================
# ADMIN
# ================================

@auth_bp.route("/admin/solicitudes", methods=["GET", "POST"])
@solo_admin
def ver_solicitudes():
    from manual_pin_change import listar_solicitudes
    solicitudes = listar_solicitudes()

    email_filtro = request.args.get('email')
    fecha_inicio = request.args.get('fecha_inicio')
    fecha_fin = request.args.get('fecha_fin')

    if email_filtro:
        solicitudes = [s for s in solicitudes if s['email'] == email_filtro]

    if fecha_inicio and fecha_fin:
        try:
            inicio = datetime.strptime(fecha_inicio, "%Y-%m-%d")
            fin = datetime.strptime(fecha_fin, "%Y-%m-%d")
            solicitudes = [s for s in solicitudes if inicio <= datetime.strptime(s['fecha'], "%Y-%m-%d") <= fin]
        except ValueError:
            flash("Formato de fecha incorrecto. Usa YYYY-MM-DD.", "danger")

    return render_template("admin_solicitudes.html", solicitudes=solicitudes)


@auth_bp.route("/admin/solicitud/<int:solicitud_id>/atender")
@solo_admin
def atender_solicitud(solicitud_id):
    from tools.manual_pin_change import marcar_como_atendida
    if marcar_como_atendida(solicitud_id):
        flash("Solicitud marcada como atendida", "success")
    else:
        flash("No se pudo actualizar la solicitud", "danger")
    return redirect(url_for("auth.ver_solicitudes"))


@auth_bp.route("/convertirme-admin")
def convertirme_admin():
    if not session.get("autenticado"):
        flash("Debes iniciar sesión para hacerte admin", "warning")
        return redirect(url_for("auth.verificar_pin"))

    if os.getenv("ENABLE_ADMIN_CONVERSION", "false").lower() != "true":
        flash("Función desactivada por seguridad", "danger")
        return redirect(url_for("main.home"))

    username = session.get("username")
    user = User.query.filter_by(username=username).first()

    if user:
        user.es_admin = True
        db.session.commit()
        session["es_admin"] = True
        flash("¡Ahora eres administrador!", "success")
    else:
        flash("Usuario no encontrado", "danger")

    return redirect(url_for("main.home"))



# ================================
# API PROTEGIDA
# ================================

@auth_bp.route("/api/protegido", methods=["GET"])
@require_jwt
def ruta_protegida():
    return jsonify({"message": "Acceso permitido. Token válido."}), 200
