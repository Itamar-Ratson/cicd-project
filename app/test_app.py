import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_home(client):
    rv = client.get('/')
    assert rv.status_code == 200
    assert b'Hello World' in rv.data

def test_health(client):
    rv = client.get('/health')
    assert rv.status_code == 200
    assert b'healthy' in rv.data
