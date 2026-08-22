from fastapi import APIRouter, Depends, HTTPException, UploadFile

from app.config.settings import get_settings
from app.nutrition.photo_pipeline import analyze_photo
from app.nutrition.text_parser import parse_food_text
from app.schemas.nutrition import NutritionResult, NutritionTextRequest
from app.security.auth import AuthenticatedUser, get_current_user

router = APIRouter()

_ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _invalid_request(message: str) -> HTTPException:
    return HTTPException(
        status_code=422,
        detail={"error": {"code": "invalid_request", "message": message}},
    )


@router.post("/nutrition/photo", response_model=NutritionResult)
async def nutrition_photo(
    image: UploadFile,
    user: AuthenticatedUser = Depends(get_current_user),
) -> NutritionResult:
    if image.content_type not in _ALLOWED_MIME_TYPES:
        raise _invalid_request(f"Unsupported image type: {image.content_type}")

    settings = get_settings()
    # Read fully into memory only — never `image.file` streamed to disk by
    # this code, and nothing here writes the bytes anywhere else.
    image_bytes = await image.read()
    if len(image_bytes) > settings.max_photo_bytes:
        raise _invalid_request("Image exceeds maximum allowed size.")

    try:
        result = await analyze_photo(image_bytes, image.content_type)
    finally:
        # Drop our only reference immediately after use so the bytes are
        # eligible for garbage collection as soon as possible, regardless
        # of whether analysis succeeded. Nothing above ever persisted them.
        image_bytes = b""

    return result


@router.post("/nutrition/text", response_model=NutritionResult)
async def nutrition_text(
    request: NutritionTextRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> NutritionResult:
    return await parse_food_text(request.text, request.prior_estimate)
