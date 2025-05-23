# middleware/require_jwt.py
from functools import wraps
from flask import request, jsonify, current_app
import jwt, requests, os

COGNITO_REGION = os.getenv("COGNITO_REGION")
COGNITO_USER_POOL_ID = os.getenv("COGNITO_USER_POOL_ID")
DISABLE_JWT_VALIDATION = os.getenv("DISABLE_JWT_VALIDATION", "").lower() == "true"

def _get_jwks():
    """Descarga JWKS solo la primera vez que se necesite."""
    if not COGNITO_REGION or not COGNITO_USER_POOL_ID:
        raise RuntimeError("Variables COGNITO_REGION / COGNITO_USER_POOL_ID no definidas")
    jwks_url = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json"
    return requests.get(jwks_url, timeout=5).json()

_jwks_cache = None
def get_public_key(token):
    global _jwks_cache
    if _jwks_cache is None:
        _jwks_cache = _get_jwks()
    kid = jwt.get_unverified_header(token)["kid"]
    key = next((k for k in _jwks_cache["keys"] if k["kid"] == kid), None)
    if not key:
        raise Exception("Clave pública no encontrada")
    return jwt.algorithms.RSAAlgorithm.from_jwk(key)

def require_jwt(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if DISABLE_JWT_VALIDATION or current_app.config.get("TESTING"):
            # saltamos validación en tests
            return f(*args, **kwargs)

        auth_header = request.headers.get("Authorization")
        if not auth_header:
            return jsonify({"error": "Token no proporcionado"}), 401
        try:
            token = auth_header.split()[1]
            public_key = get_public_key(token)
            jwt.decode(
                token,
                public_key,
                algorithms=["RS256"],
                audience=os.getenv("COGNITO_APP_CLIENT_ID"),
                issuer=f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}",
            )
        except Exception as e:
            return jsonify({"error": f"Token inválido: {e}"}), 401
        return f(*args, **kwargs)
    return decorated

