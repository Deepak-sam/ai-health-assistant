"""Ephemeral food-photo analysis pipeline.

HARD PRIVACY REQUIREMENT (docs/ARCHITECTURE.md §15/§8): the image bytes
passed into `analyze_photo` are used only for the duration of this call and
are never written to disk, object storage, or logs, and never appear in the
returned value. If a future Gemini SDK forces a temp file, wrap it in
`tempfile.NamedTemporaryFile` inside a `try/finally` that unlinks it
unconditionally — see `backend/tests/test_photo_pipeline.py` for the
regression test that guards this.
"""
import json
import logging

from app.ai.gemini_client import GeminiClient
from app.schemas.nutrition import NutritionResult

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = """
You are a nutrition estimation assistant. Given a photo of a meal, identify
the food items, estimate portion sizes in grams, and estimate calories and
macronutrients (protein_g, carbs_g, fat_g) per item and in total. Respond
ONLY with JSON matching this schema, no prose:
{
  "meal_name": string,
  "items": [{"name": string, "estimated_grams": number, "calories": number, "protein_g": number, "carbs_g": number, "fat_g": number}],
  "total_calories": number,
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number,
  "fiber_g": number or null,
  "confidence": number between 0 and 1,
  "clarifying_question": string or null (populate only if confidence < 0.6 and one specific question would meaningfully improve the estimate)
}
""".strip()


async def analyze_photo(
    image_bytes: bytes,
    image_mime_type: str,
    gemini_client: GeminiClient | None = None,
) -> NutritionResult:
    """Analyze meal photo bytes in memory and return structured nutrition data.

    IMPORTANT: `image_bytes` must never be assigned anywhere it would
    outlive this function call (no module-level cache, no logging, no
    `open(..., "wb")`). The caller (the API route) must not persist it
    either — see app/api/nutrition.py.
    """
    client = gemini_client or GeminiClient()
    response = await client.generate_with_image(
        system_prompt=_SYSTEM_PROMPT,
        user_prompt="Analyze this meal photo and return the JSON described in the system prompt.",
        image_bytes=image_bytes,
        image_mime_type=image_mime_type,
    )
    # `image_bytes` is not referenced again after this point; it goes out of
    # scope when this function returns and is reclaimed by the interpreter.
    data = json.loads(response.text)
    return NutritionResult(**data)
