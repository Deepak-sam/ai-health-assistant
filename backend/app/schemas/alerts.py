from typing import Literal

from pydantic import BaseModel


class AlertCondition(BaseModel):
    type: Literal["threshold", "baseline_relative", "consecutive_day"]
    operator: Literal[">", "<", ">=", "<="]
    threshold: float | None = None
    baseline_window_days: int | None = None
    baseline_multiplier: float | None = None
    consecutive_count: int | None = None


class AlertRule(BaseModel):
    metric_type: str
    condition: AlertCondition
    window: Literal["daily", "rolling"] = "daily"


class AlertCompileRequest(BaseModel):
    text: str


class AlertCompileResponse(BaseModel):
    rule: AlertRule
    confirmation_text: str
