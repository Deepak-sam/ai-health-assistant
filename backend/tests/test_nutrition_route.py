import io
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.schemas.nutrition import NutritionResult
from app.security.auth import AuthenticatedUser, get_current_user


@pytest.fixture
def client():
    # Scoped to this test module only — must not leak into other test
    # files, which rely on the real auth dependency being enforced.
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="1", email="parent@example.com"
    )
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.pop(get_current_user, None)


_FAKE_RESULT = NutritionResult(
    meal_name="Test meal",
    items=[],
    total_calories=500,
    protein_g=30,
    carbs_g=50,
    fat_g=10,
)


def test_nutrition_photo_rejects_unsupported_mime_type(client):
    resp = client.post(
        "/api/v1/nutrition/photo",
        files={"image": ("meal.gif", io.BytesIO(b"gif-bytes"), "image/gif")},
    )
    assert resp.status_code == 422
    assert resp.json()["detail"]["error"]["code"] == "invalid_request"


@patch("app.api.nutrition.analyze_photo", new_callable=AsyncMock)
def test_nutrition_photo_returns_structured_result(mock_analyze, client):
    mock_analyze.return_value = _FAKE_RESULT
    resp = client.post(
        "/api/v1/nutrition/photo",
        files={"image": ("meal.jpg", io.BytesIO(b"fake-jpeg-bytes"), "image/jpeg")},
    )
    assert resp.status_code == 200
    assert resp.json()["meal_name"] == "Test meal"
    mock_analyze.assert_awaited_once()
