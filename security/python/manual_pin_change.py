import sqlite3
from datetime import datetime

DB = 'users.db'

def registrar_solicitud(email, mensaje):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("INSERT INTO solicitudes_pin (email, mensaje, fecha) VALUES (?, ?, ?)", (email, mensaje, datetime.now().strftime("%Y-%m-%d")))
    conn.commit()
    conn.close()

def listar_solicitudes():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("SELECT id, email, mensaje, fecha, atendida FROM solicitudes_pin ORDER BY fecha DESC")
    data = c.fetchall()
    conn.close()
    solicitudes = []
    for s in data:
        solicitudes.append({
            "id": s[0],
            "email": s[1],
            "mensaje": s[2],
            "fecha": s[3],
            "atendida": bool(s[4])
        })
    return solicitudes

def marcar_como_atendida(solicitud_id):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("UPDATE solicitudes_pin SET atendida = 1 WHERE id = ?", (solicitud_id,))
    conn.commit()
    updated = c.rowcount
    conn.close()
    return updated > 0

def crear_tabla_si_no_existe():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        CREATE TABLE IF NOT EXISTS solicitudes_pin (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL,
            mensaje TEXT,
            fecha TEXT,
            atendida INTEGER DEFAULT 0
        )
    """)
    conn.commit()
    conn.close()
