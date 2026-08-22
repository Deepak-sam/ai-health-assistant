from fastapi import APIRouter, Depends

from app.ai.orchestrator import ChatOrchestrator
from app.schemas.chat import ChatRequest, ChatResponse
from app.security.auth import AuthenticatedUser, get_current_user

router = APIRouter()
_orchestrator = ChatOrchestrator()


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> ChatResponse:
    return await _orchestrator.handle(request)
