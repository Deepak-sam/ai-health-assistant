"""Chat orchestration: intent -> specialist prompt -> single Gemini call.

Follows docs/ARCHITECTURE.md §9 and the "AI interprets, code executes"
principle (§42): this module never computes health statistics itself — the
client already did that and handed pre-computed baselines in `context`.
"""
import json

from app.ai.gemini_client import GeminiClient
from app.ai.specialists import SPECIALISTS, classify_intent
from app.schemas.chat import ChatRequest, ChatResponse

_SAFETY_KEYWORDS = (
    "chest pain",
    "can't breathe",
    "cannot breathe",
    "fainted",
    "fainting",
    "severe pain",
    "numbness on one side",
    "slurred speech",
)


def _detect_safety_flag(message: str) -> str | None:
    lowered = message.lower()
    if any(k in lowered for k in _SAFETY_KEYWORDS):
        return "seek_medical_attention"
    return None


def _build_user_prompt(request: ChatRequest) -> str:
    context_json = request.context.model_dump_json(exclude_none=True)
    history = "\n".join(f"{m.role}: {m.content}" for m in request.recent_messages[-12:])
    summary = request.conversation_summary or ""
    return (
        f"Conversation summary so far: {summary}\n"
        f"Recent messages:\n{history}\n\n"
        f"Pre-computed health context (already correct, do not recompute): {context_json}\n\n"
        f"User's new message: {request.message}\n\n"
        "Reply conversationally in 1-4 sentences. Then, on a new line starting with "
        "'FOLLOWUPS:', give 0-3 short suggested follow-up questions separated by '|'. "
        "Do not include any other structure."
    )


def _parse_reply(raw_text: str) -> tuple[str, list[str]]:
    if "FOLLOWUPS:" in raw_text:
        reply, _, followup_line = raw_text.partition("FOLLOWUPS:")
        followups = [f.strip() for f in followup_line.split("|") if f.strip()]
        return reply.strip(), followups
    return raw_text.strip(), []


class ChatOrchestrator:
    def __init__(self, gemini_client: GeminiClient | None = None) -> None:
        self._gemini = gemini_client or GeminiClient()

    async def handle(self, request: ChatRequest) -> ChatResponse:
        safety_flag = _detect_safety_flag(request.message)

        intent = classify_intent(request.message)
        system_prompt = SPECIALISTS[intent]
        user_prompt = _build_user_prompt(request)

        response = await self._gemini.generate_text(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
        )
        reply, followups = _parse_reply(response.text)

        return ChatResponse(
            reply=reply,
            cards=[],
            suggested_followups=followups,
            safety_flag=safety_flag,
        )
