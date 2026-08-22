import json
import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.ai.gemini_client import GeminiError
from app.api.alerts import router as alerts_router
from app.api.chat import router as chat_router
from app.api.garmin import router as garmin_router
from app.api.nutrition import router as nutrition_router
from app.config.settings import get_settings

# Health/photo request bodies must never be logged (§25) — configure the
# access logger to omit them; uvicorn's default access log only logs the
# method/path/status, which is safe.
logging.basicConfig(level=logging.INFO)

app = FastAPI(title="Family Health AI Assistant API", version="0.1.0")

settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.allowed_origins.split(",")],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(chat_router, prefix="/api/v1")
app.include_router(nutrition_router, prefix="/api/v1")
app.include_router(alerts_router, prefix="/api/v1")
app.include_router(garmin_router, prefix="/api/v1")


@app.exception_handler(GeminiError)
async def gemini_error_handler(request: Request, exc: GeminiError) -> JSONResponse:
    logging.getLogger(__name__).error("Upstream Gemini error: %s", exc)
    return JSONResponse(
        status_code=502,
        content={"error": {"code": "upstream_ai_error", "message": "The AI service is temporarily unavailable."}},
    )


@app.exception_handler(json.JSONDecodeError)
async def json_error_handler(request: Request, exc: json.JSONDecodeError) -> JSONResponse:
    logging.getLogger(__name__).error("Failed to parse AI response as JSON: %s", exc)
    return JSONResponse(
        status_code=502,
        content={"error": {"code": "upstream_ai_error", "message": "The AI service returned an unexpected response."}},
    )


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
