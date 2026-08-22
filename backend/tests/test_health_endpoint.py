from fastapi.testclient import TestClient

from app.main import app


def test_health_endpoint_requires_no_auth():
    client = TestClient(app)
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_chat_requires_auth():
    client = TestClient(app)
    resp = client.post("/api/v1/chat", json={"message": "hi"})
    assert resp.status_code == 401
    assert resp.json()["detail"]["error"]["code"] == "unauthorized"
