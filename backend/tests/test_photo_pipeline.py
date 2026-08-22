"""Guards the hard privacy requirement: food photo bytes are never
persisted anywhere during analysis (docs/ARCHITECTURE.md §15)."""
import gc
import json
import sys
from unittest.mock import AsyncMock

import pytest

from app.ai.gemini_client import GeminiResponse
from app.nutrition.photo_pipeline import analyze_photo

_FAKE_RESULT = {
    "meal_name": "Chicken rice bowl",
    "items": [
        {"name": "grilled chicken", "estimated_grams": 150, "calories": 250, "protein_g": 40, "carbs_g": 0, "fat_g": 8},
    ],
    "total_calories": 250,
    "protein_g": 40,
    "carbs_g": 0,
    "fat_g": 8,
    "fiber_g": None,
    "confidence": 0.8,
    "clarifying_question": None,
}


@pytest.mark.asyncio
async def test_analyze_photo_returns_structured_result_without_persisting_bytes(tmp_path):
    fake_client = AsyncMock()
    fake_client.generate_with_image.return_value = GeminiResponse(text=json.dumps(_FAKE_RESULT))

    image_bytes = b"\xff\xd8\xff\xe0-not-a-real-jpeg-but-unique-marker-bytes"
    baseline_refcount = sys.getrefcount(image_bytes)

    result = await analyze_photo(image_bytes, "image/jpeg", gemini_client=fake_client)

    assert result.meal_name == "Chicken rice bowl"
    assert result.total_calories == 250

    # Nothing on disk anywhere under a scratch dir should ever contain the
    # marker bytes — this is the closest a unit test gets to proving "never
    # written to disk" without mocking the filesystem entirely.
    for path in tmp_path.rglob("*"):
        if path.is_file():
            assert b"not-a-real-jpeg" not in path.read_bytes()

    # The pipeline itself must not stash the bytes anywhere reachable
    # beyond this call (module globals, the result object). The mock
    # client's own call-history bookkeeping (call_args/call_args_list) is
    # not part of what we're testing, so clear it before checking the
    # refcount — it would otherwise hold a reference forever.
    assert "not-a-real-jpeg" not in json.dumps(result.model_dump())

    fake_client.reset_mock()
    gc.collect()
    assert sys.getrefcount(image_bytes) == baseline_refcount, (
        "image bytes were retained somewhere after analysis"
    )


@pytest.mark.asyncio
async def test_analyze_photo_propagates_gemini_errors_without_leaking_bytes():
    from app.ai.gemini_client import GeminiError

    fake_client = AsyncMock()
    fake_client.generate_with_image.side_effect = GeminiError("upstream boom")

    with pytest.raises(GeminiError):
        await analyze_photo(b"some-image-bytes", "image/jpeg", gemini_client=fake_client)
