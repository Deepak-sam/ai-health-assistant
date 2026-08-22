import json
from unittest.mock import AsyncMock

import pytest

from app.ai.gemini_client import GeminiResponse
from app.alerts.compiler import compile_alert_rule


@pytest.mark.asyncio
async def test_compile_threshold_rule():
    fake_client = AsyncMock()
    fake_client.generate_text.return_value = GeminiResponse(
        text=json.dumps(
            {
                "metric_type": "resting_heart_rate",
                "condition": {
                    "type": "threshold",
                    "operator": ">",
                    "threshold": 90,
                    "baseline_window_days": None,
                    "baseline_multiplier": None,
                    "consecutive_count": None,
                },
                "window": "daily",
                "confirmation_text": "I'll alert you when your resting heart rate goes above 90.",
            }
        )
    )

    response = await compile_alert_rule(
        "Tell me if my resting heart rate goes above 90.", gemini_client=fake_client
    )

    assert response.rule.metric_type == "resting_heart_rate"
    assert response.rule.condition.type == "threshold"
    assert response.rule.condition.threshold == 90
    assert "90" in response.confirmation_text


@pytest.mark.asyncio
async def test_compile_baseline_relative_rule_with_consecutive_days():
    fake_client = AsyncMock()
    fake_client.generate_text.return_value = GeminiResponse(
        text=json.dumps(
            {
                "metric_type": "resting_heart_rate",
                "condition": {
                    "type": "baseline_relative",
                    "operator": ">",
                    "threshold": None,
                    "baseline_window_days": 30,
                    "baseline_multiplier": 1.10,
                    "consecutive_count": 3,
                },
                "window": "rolling",
                "confirmation_text": "I'll alert you when your resting heart rate is more than 10% above your 30-day average for 3 consecutive days.",
            }
        )
    )

    response = await compile_alert_rule(
        "Notify me if my resting HR increases more than 10% above my 30-day average for three days.",
        gemini_client=fake_client,
    )

    assert response.rule.condition.type == "baseline_relative"
    assert response.rule.condition.baseline_multiplier == 1.10
    assert response.rule.condition.consecutive_count == 3
