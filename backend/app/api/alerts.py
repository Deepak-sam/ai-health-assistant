from fastapi import APIRouter, Depends

from app.alerts.compiler import compile_alert_rule
from app.schemas.alerts import AlertCompileRequest, AlertCompileResponse
from app.security.auth import AuthenticatedUser, get_current_user

router = APIRouter()


@router.post("/alerts/compile", response_model=AlertCompileResponse)
async def alerts_compile(
    request: AlertCompileRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> AlertCompileResponse:
    return await compile_alert_rule(request.text)
