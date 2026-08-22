"""Server-side Garmin OAuth2 PKCE endpoints (docs/ARCHITECTURE.md §6).

Closes the gap flagged in mobile/README.md "Garmin OAuth notes": the mobile
`GarminProvider` already calls `GET /garmin/oauth/authorize-url` and expects
Garmin's own redirect chain to end at `GET /garmin/oauth/callback`.
"""
import logging

from fastapi import APIRouter, Depends, Query
from fastapi.responses import RedirectResponse

from app.config.settings import get_settings
from app.garmin import pkce, session_store
from app.garmin.oauth import GarminOAuthError, build_authorization_url, exchange_code_for_tokens
from app.security.auth import AuthenticatedUser, get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/garmin/oauth/authorize-url")
async def garmin_authorize_url(user: AuthenticatedUser = Depends(get_current_user)) -> dict:
    verifier = pkce.generate_verifier()
    challenge = pkce.generate_challenge(verifier)
    state = pkce.generate_state()
    session_store.store_pending(state, code_verifier=verifier, uid=user.uid)

    url = build_authorization_url(state=state, code_challenge=challenge)
    return {"authorize_url": url}


@router.get("/garmin/oauth/callback")
async def garmin_oauth_callback(code: str = Query(...), state: str = Query(...)) -> RedirectResponse:
    """Garmin redirects the user's webview here directly — this endpoint is
    intentionally unauthenticated (Garmin cannot present a Firebase bearer
    token); the `state` parameter is what ties this callback back to the
    family member who started the flow (see `session_store.store_pending`).
    """
    settings = get_settings()
    scheme = settings.garmin_app_redirect_scheme

    pending = session_store.pop_pending(state)
    if pending is None:
        return RedirectResponse(f"{scheme}://oauth?status=error&error=expired_or_invalid_state")

    try:
        tokens = await exchange_code_for_tokens(code, pending.code_verifier)
    except GarminOAuthError as exc:
        logger.error("Garmin token exchange failed: %s", exc)
        return RedirectResponse(f"{scheme}://oauth?status=error&error=token_exchange_failed")

    session_ref = pkce.generate_session_ref()
    session_store.store_session(session_ref, uid=pending.uid, refresh_token=tokens.refresh_token)

    return RedirectResponse(f"{scheme}://oauth?status=connected&session_ref={session_ref}")
