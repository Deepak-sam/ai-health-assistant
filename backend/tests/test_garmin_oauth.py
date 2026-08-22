import os
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.garmin import session_store
from app.garmin.oauth import GarminOAuthError, GarminTokens
from app.main import app
from app.security.auth import AuthenticatedUser, get_current_user

os.environ.setdefault("GARMIN_CLIENT_ID", "test-client-id")


@pytest.fixture
def client():
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="family-member-1", email="parent@example.com"
    )
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_authorize_url_requires_auth():
    resp = TestClient(app).get("/api/v1/garmin/oauth/authorize-url")
    assert resp.status_code == 401


def test_authorize_url_returns_url_and_stores_pending_state(client):
    resp = client.get("/api/v1/garmin/oauth/authorize-url")
    assert resp.status_code == 200
    url = resp.json()["authorize_url"]
    assert "code_challenge=" in url
    assert "state=" in url


def test_callback_rejects_unknown_state():
    resp = TestClient(app, follow_redirects=False).get(
        "/api/v1/garmin/oauth/callback", params={"code": "abc", "state": "never-issued"}
    )
    assert resp.status_code in (302, 307)
    assert "status=error" in resp.headers["location"]


@patch("app.api.garmin.exchange_code_for_tokens", new_callable=AsyncMock)
def test_callback_completes_flow_and_redirects_with_session_ref(mock_exchange, client):
    authorize_resp = client.get("/api/v1/garmin/oauth/authorize-url")
    url = authorize_resp.json()["authorize_url"]
    state = url.split("state=")[1].split("&")[0]

    mock_exchange.return_value = GarminTokens(access_token="a", refresh_token="r", expires_in=3600)

    resp = TestClient(app, follow_redirects=False).get(
        "/api/v1/garmin/oauth/callback", params={"code": "auth-code", "state": state}
    )
    assert resp.status_code in (302, 307)
    location = resp.headers["location"]
    assert "status=connected" in location
    assert "session_ref=" in location

    session_ref = location.split("session_ref=")[1]
    session = session_store.get_session(session_ref)
    assert session is not None
    assert session.uid == "family-member-1"
    assert session.refresh_token == "r"


@patch("app.api.garmin.exchange_code_for_tokens", new_callable=AsyncMock)
def test_callback_redirects_with_error_on_exchange_failure(mock_exchange, client):
    authorize_resp = client.get("/api/v1/garmin/oauth/authorize-url")
    state = authorize_resp.json()["authorize_url"].split("state=")[1].split("&")[0]
    mock_exchange.side_effect = GarminOAuthError("boom")

    resp = TestClient(app, follow_redirects=False).get(
        "/api/v1/garmin/oauth/callback", params={"code": "auth-code", "state": state}
    )
    assert "status=error" in resp.headers["location"]
