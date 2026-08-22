"""Thin client for the Gemini Generative Language API.

Deliberately minimal: one method for text generation, one for
text+image generation. No SDK dependency beyond httpx, so it's easy to
mock in tests and keeps the deployable footprint small (§28).
"""
import base64
from dataclasses import dataclass

import httpx

from app.config.settings import get_settings


class GeminiError(RuntimeError):
    pass


@dataclass
class GeminiResponse:
    text: str


class GeminiClient:
    def __init__(self, api_key: str | None = None, api_base: str | None = None) -> None:
        settings = get_settings()
        self._api_key = api_key or settings.gemini_api_key
        self._api_base = api_base or settings.gemini_api_base

    async def generate_text(
        self,
        *,
        system_prompt: str,
        user_prompt: str,
        model: str | None = None,
        response_mime_type: str = "text/plain",
    ) -> GeminiResponse:
        return await self._generate(
            model=model,
            system_prompt=system_prompt,
            parts=[{"text": user_prompt}],
            response_mime_type=response_mime_type,
        )

    async def generate_with_image(
        self,
        *,
        system_prompt: str,
        user_prompt: str,
        image_bytes: bytes,
        image_mime_type: str,
        model: str | None = None,
        response_mime_type: str = "application/json",
    ) -> GeminiResponse:
        # Image bytes are base64-encoded in-memory for this single outbound
        # request only, then this stack frame (and its local `parts`) is
        # discarded — nothing here is written to disk or logged.
        parts = [
            {"text": user_prompt},
            {
                "inline_data": {
                    "mime_type": image_mime_type,
                    "data": base64.b64encode(image_bytes).decode("ascii"),
                }
            },
        ]
        return await self._generate(
            model=model,
            system_prompt=system_prompt,
            parts=parts,
            response_mime_type=response_mime_type,
        )

    async def _generate(
        self,
        *,
        model: str | None,
        system_prompt: str,
        parts: list[dict],
        response_mime_type: str,
    ) -> GeminiResponse:
        settings = get_settings()
        model_name = model or settings.gemini_model
        if not self._api_key:
            raise GeminiError("GEMINI_API_KEY is not configured.")

        url = f"{self._api_base}/models/{model_name}:generateContent"
        payload = {
            "system_instruction": {"parts": [{"text": system_prompt}]},
            "contents": [{"role": "user", "parts": parts}],
            "generationConfig": {"response_mime_type": response_mime_type},
        }
        headers = {"x-goog-api-key": self._api_key, "Content-Type": "application/json"}

        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, json=payload, headers=headers)

        if resp.status_code != 200:
            raise GeminiError(f"Gemini API error {resp.status_code}: {resp.text}")

        data = resp.json()
        try:
            text = data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError) as exc:
            raise GeminiError(f"Unexpected Gemini response shape: {data}") from exc
        return GeminiResponse(text=text)
