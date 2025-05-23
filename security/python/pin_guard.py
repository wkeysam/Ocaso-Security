from flask import request
from datetime import datetime, timedelta

# Diccionario para almacenar los intentos fallidos por IP
FAILED_ATTEMPTS = {}
BLOCKED_IPS = {}

def is_blocked(ip):
    now = datetime.utcnow()
    if ip in BLOCKED_IPS and BLOCKED_IPS[ip] > now:
        return True
    return False

def register_failed_attempt(ip):
    now = datetime.utcnow()
    if ip in FAILED_ATTEMPTS:
        FAILED_ATTEMPTS[ip]['count'] += 1
        if FAILED_ATTEMPTS[ip]['count'] >= 5:
            BLOCKED_IPS[ip] = now + timedelta(minutes=15)
            FAILED_ATTEMPTS[ip] = {'count': 0, 'last': now}
    else:
        FAILED_ATTEMPTS[ip] = {'count': 1, 'last': now}

def verify_pin(input_pin, actual_pin, ip):
    if is_blocked(ip):
        return False, "IP bloqueada temporalmente"
    if input_pin == actual_pin:
        FAILED_ATTEMPTS[ip] = {'count': 0, 'last': datetime.utcnow()}
        return True, "PIN correcto"
    else:
        register_failed_attempt(ip)
        return False, "PIN incorrecto"
