"""Natural language -> structured AlertRule, compiled ONCE at creation time.

Evaluation is deterministic client-side code (see docs/ARCHITECTURE.md §10
and the Dart `AlertRuleEvaluator`) — this module is never invoked again once
a rule exists, which is what keeps alerting cost and behavior predictable.
"""
import json

from app.ai.gemini_client import GeminiClient
from app.schemas.alerts import AlertCompileResponse, AlertRule

_VALID_METRICS = (
    "heart_rate",
    "resting_heart_rate",
    "hrv",
    "steps",
    "sleep_duration",
    "sleep_score",
    "calories_active",
    "calories_total",
    "distance",
    "stress",
    "body_battery",
    "weight",
    "vo2_max",
    "blood_oxygen",
    "active_minutes",
)

_SYSTEM_PROMPT = f"""
You convert a family health app user's natural-language alert request into a
structured rule. Valid metric_type values: {", ".join(_VALID_METRICS)}.
Respond ONLY with JSON matching this schema, no prose:
{{
  "metric_type": string (one of the valid values above),
  "condition": {{
    "type": "threshold" | "baseline_relative" | "consecutive_day",
    "operator": ">" | "<" | ">=" | "<=",
    "threshold": number or null,
    "baseline_window_days": number or null,
    "baseline_multiplier": number or null,
    "consecutive_count": number or null
  }},
  "window": "daily" | "rolling",
  "confirmation_text": string (one plain sentence describing the rule back to the user, starting with "I'll alert you when")
}}

Use "threshold" for a fixed number (e.g. "above 90"). Use "baseline_relative"
when the user compares to their own average (e.g. "10% above my 30-day
average"). Use "consecutive_count" whenever the user mentions multiple
days/nights in a row; otherwise omit it (null) and default window to "daily".
""".strip()


async def compile_alert_rule(
    text: str,
    gemini_client: GeminiClient | None = None,
) -> AlertCompileResponse:
    client = gemini_client or GeminiClient()
    response = await client.generate_text(
        system_prompt=_SYSTEM_PROMPT,
        user_prompt=text,
        response_mime_type="application/json",
    )
    data = json.loads(response.text)
    confirmation_text = data.pop("confirmation_text")
    rule = AlertRule(**data)
    return AlertCompileResponse(rule=rule, confirmation_text=confirmation_text)
