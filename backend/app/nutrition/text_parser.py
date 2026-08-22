"""Free-text food log parsing (§13). Same structured output contract as the
photo pipeline, no ephemeral-data handling needed since text carries no
comparable privacy risk."""
import json

from app.ai.gemini_client import GeminiClient
from app.schemas.nutrition import NutritionResult

_SYSTEM_PROMPT = """
You are a nutrition estimation assistant. Given a free-text description of
food eaten, identify the food items, estimate portion sizes in grams, and
estimate calories and macronutrients. Respond ONLY with JSON matching this
schema, no prose:
{
  "meal_name": string,
  "items": [{"name": string, "estimated_grams": number, "calories": number, "protein_g": number, "carbs_g": number, "fat_g": number}],
  "total_calories": number,
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number,
  "fiber_g": number or null,
  "confidence": number between 0 and 1,
  "clarifying_question": null
}
""".strip()


async def parse_food_text(
    text: str,
    prior_estimate: NutritionResult | None = None,
    gemini_client: GeminiClient | None = None,
) -> NutritionResult:
    client = gemini_client or GeminiClient()
    prompt = f"Food description: {text}"
    if prior_estimate is not None:
        prompt += (
            "\n\nThis clarifies a prior estimate: "
            f"{prior_estimate.model_dump_json(exclude_none=True)}. Update it accordingly."
        )
    response = await client.generate_text(
        system_prompt=_SYSTEM_PROMPT,
        user_prompt=prompt,
        response_mime_type="application/json",
    )
    data = json.loads(response.text)
    return NutritionResult(**data)
