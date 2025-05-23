from flask import Blueprint, render_template
from bot.bot import obtener_ultima_reflexion

reflexion_bp = Blueprint("reflexion", __name__)

@reflexion_bp.route("/reflexion")
def reflexion():
    reflexion = obtener_ultima_reflexion()
    return render_template("reflexion.html", reflexion=reflexion)
