import os
from app import create_app
from tools.manual_pin_change import crear_tabla_si_no_existe
from app.models import db

env = os.getenv("APP_ENV", "development")

app = create_app(env)

crear_tabla_si_no_existe()

with app.app_context():
    db.create_all()

if __name__ == "__main__":
    debug_mode = env != "production"
    app.run(host="0.0.0.0", port=5000, debug=debug_mode)

