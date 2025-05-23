def test_index_route(client):
    """
    La ruta '/' redirige (302) al login/PIN,
    así que verificamos que no da 404.
    """
    response = client.get("/")
    assert response.status_code in (302, 301)


def test_register_route(client):
    """
    GET /registro debe existir (200) o redirigir (302)
    — depende de la lógica.
    """
    response = client.get("/registro")
    assert response.status_code in (200, 302)


def test_pin_route(client):
    """
    GET /verificar-pin también debe responder (200/302).
    """
    response = client.get("/verificar-pin")
    assert response.status_code in (200, 302)

