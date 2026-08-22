from typing import Any, Literal

from pydantic import BaseModel, Field


class MetricSnapshot(BaseModel):
    """Pre-computed by the client's BaselineCalculator. The backend never
    computes statistics itself — see docs/ARCHITECTURE.md §9/§42."""

    today: float | None = None
    baseline_7d: float | None = None
    baseline_30d: float | None = None
    baseline_90d: float | None = None
    stddev_30d: float | None = None
    trend: Literal["up", "down", "flat"] | None = None
    percent_change: float | None = None


class RecentActivity(BaseModel):
    type: str
    days_ago: int
    duration_min: int | None = None


class ChatContext(BaseModel):
    metrics: dict[str, MetricSnapshot] = Field(default_factory=dict)
    recent_activities: list[RecentActivity] = Field(default_factory=list)


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    message: str
    context: ChatContext = Field(default_factory=ChatContext)
    conversation_summary: str | None = None
    recent_messages: list[ChatMessage] = Field(default_factory=list)


class HealthCard(BaseModel):
    type: Literal["sleep", "activity", "nutrition", "heart", "generic"]
    title: str
    fields: dict[str, Any] = Field(default_factory=dict)


class ChatResponse(BaseModel):
    reply: str
    cards: list[HealthCard] = Field(default_factory=list)
    suggested_followups: list[str] = Field(default_factory=list)
    safety_flag: str | None = None
