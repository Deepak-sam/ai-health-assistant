"""Internal specialist system prompts (§5). Never exposed to the user as
separate bots — the orchestrator silently picks one per turn."""

BASE_SAFETY_RULES = """
You are "Family Health AI", a private wellness assistant for one family's
members. You are NOT a doctor and must never diagnose disease. Use the
pre-computed numbers given to you; do not invent statistics or recompute
them yourself. Compare the user to their own historical baseline, not to
generic population norms, since that data is provided. If the user
describes symptoms that could be acute or serious (e.g. chest pain,
fainting, severe shortness of breath, signs of stroke), respond with brief
empathy plus a clear recommendation to seek appropriate medical care, and
avoid further speculation. Keep replies conversational and concise, like a
knowledgeable friend, not a clinical report.
""".strip()

SPECIALISTS: dict[str, str] = {
    "sleep": f"{BASE_SAFETY_RULES}\n\nFocus: sleep duration, sleep score, sleep stages, and how tonight/this week compares to the user's own baseline.",
    "recovery": f"{BASE_SAFETY_RULES}\n\nFocus: resting heart rate, HRV, and recovery readiness relative to the user's own baseline. Give a clear, actionable read on whether today looks like a good day to train hard, train light, or rest.",
    "fitness": f"{BASE_SAFETY_RULES}\n\nFocus: steps, activity minutes, workouts, and training load trends relative to the user's own baseline.",
    "nutrition": f"{BASE_SAFETY_RULES}\n\nFocus: calories and macronutrients relative to the user's stated targets and recent intake pattern.",
    "lifestyle": f"{BASE_SAFETY_RULES}\n\nFocus: general trends across multiple metrics over weeks/months, highlighting only meaningful, non-obvious changes.",
    "general": BASE_SAFETY_RULES,
}


def _contains_any(text: str, keywords: tuple[str, ...]) -> bool:
    lowered = text.lower()
    return any(k in lowered for k in keywords)


def classify_intent(message: str) -> str:
    """Cheap, free, deterministic fast-path intent classification.

    Covers the majority of example queries in the product brief (§1)
    without spending an LLM call just to route the request (§29). Falls
    back to "general" when nothing matches, which still only costs the one
    generation call the orchestrator was going to make anyway.
    """
    if _contains_any(message, ("sleep", "slept", "bedtime", "wake up", "woke up")):
        return "sleep"
    if _contains_any(message, ("recover", "hrv", "resting heart rate", "resting hr", "train today", "should i train", "readiness")):
        return "recovery"
    if _contains_any(message, ("steps", "workout", "run", "exercise", "activity", "calories burned", "active minutes")):
        return "fitness"
    if _contains_any(message, ("eat", "food", "meal", "calorie", "protein", "carb", "fat ", "nutrition", "diet")):
        return "nutrition"
    if _contains_any(message, ("this month", "trend", "compare", "improving", "changed", "over time")):
        return "lifestyle"
    return "general"
