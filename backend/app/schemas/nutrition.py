from pydantic import BaseModel, Field


class NutritionItem(BaseModel):
    name: str
    estimated_grams: float
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float


class NutritionResult(BaseModel):
    meal_name: str
    items: list[NutritionItem] = Field(default_factory=list)
    total_calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float | None = None
    confidence: float | None = None
    clarifying_question: str | None = None


class NutritionTextRequest(BaseModel):
    text: str
    prior_estimate: NutritionResult | None = None
