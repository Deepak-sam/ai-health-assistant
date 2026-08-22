from app.ai.specialists import classify_intent


def test_sleep_intent():
    assert classify_intent("How did I sleep this week?") == "sleep"


def test_recovery_intent():
    assert classify_intent("Should I train today?") == "recovery"
    assert classify_intent("How is my recovery looking?") == "recovery"


def test_fitness_intent():
    assert classify_intent("Show my average steps over the last 30 days.") == "fitness"


def test_nutrition_intent():
    assert classify_intent("What should I eat for dinner?") == "nutrition"


def test_lifestyle_intent():
    assert classify_intent("What changed in my health this month?") == "lifestyle"


def test_general_fallback():
    assert classify_intent("hello there") == "general"
