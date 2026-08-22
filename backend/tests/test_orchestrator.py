from unittest.mock import AsyncMock

import pytest

from app.ai.gemini_client import GeminiResponse
from app.ai.orchestrator import ChatOrchestrator
from app.schemas.chat import ChatRequest


@pytest.mark.asyncio
async def test_safety_flag_set_for_concerning_symptoms():
    fake_client = AsyncMock()
    fake_client.generate_text.return_value = GeminiResponse(
        text="That sounds serious, please seek care.\nFOLLOWUPS:"
    )
    orchestrator = ChatOrchestrator(gemini_client=fake_client)

    response = await orchestrator.handle(ChatRequest(message="I have chest pain and can't breathe"))

    assert response.safety_flag == "seek_medical_attention"


@pytest.mark.asyncio
async def test_normal_message_has_no_safety_flag_and_parses_followups():
    fake_client = AsyncMock()
    fake_client.generate_text.return_value = GeminiResponse(
        text="You slept 7h18m, close to your baseline.\nFOLLOWUPS: Show my sleep trend | Should I train today?"
    )
    orchestrator = ChatOrchestrator(gemini_client=fake_client)

    response = await orchestrator.handle(ChatRequest(message="How did I sleep?"))

    assert response.safety_flag is None
    assert response.reply == "You slept 7h18m, close to your baseline."
    assert response.suggested_followups == ["Show my sleep trend", "Should I train today?"]


@pytest.mark.asyncio
async def test_backend_never_receives_full_history_only_narrowed_context():
    """Regression guard for §6/§29: the orchestrator must forward exactly the
    pre-computed context it was given, never fetch or fabricate additional
    health data itself."""
    fake_client = AsyncMock()
    fake_client.generate_text.return_value = GeminiResponse(text="ok\nFOLLOWUPS:")
    orchestrator = ChatOrchestrator(gemini_client=fake_client)

    request = ChatRequest(
        message="Should I train today?",
        context={"metrics": {"resting_heart_rate": {"today": 58, "baseline_30d": 59.2}}},
    )
    await orchestrator.handle(request)

    _, kwargs = fake_client.generate_text.call_args
    assert "58" in kwargs["user_prompt"]
    assert "59.2" in kwargs["user_prompt"]
