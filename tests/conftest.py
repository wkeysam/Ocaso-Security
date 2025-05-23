import pytest
from app import create_app, db

@pytest.fixture
def app():
    """
    Crea la aplicación en modo testing, levanta las tablas en memoria
    y las destruye al acabar.
    """
    app = create_app("testing")          # ← usa TestingConfig
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()

@pytest.fixture
def client(app):
    """Cliente de pruebas de Flask."""
    return app.test_client()
