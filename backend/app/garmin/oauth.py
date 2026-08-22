"""Server-side half of Garmin's OAuth2 PKCE flow (docs/ARCHITECTURE.md §6).

Garmin's client secret must never ship inside the mobile app, so the
authorization-code -> token exchange (and refresh) happens here. The mobile
app only ever sees a short-lived session reference, never the Garmin
refresh token itself.

This is a genuinely usable implementation, but Garmin Health API access is
gated behind Garmin's own developer approval process, which is outside this
session's control (see docs/ARCHITECTURE.md §1 risk table) — it ships behind
the `garmin_enabled`-equivalent client feature flag until that approval
exists.
"""
from dataclasses import dataclass

import httpx

from app.config.settings import get_settings

_AUTHORIZE_URL = "https://connect.garmin.com/oauth2Confirm"
_TOKEN_URL = "https://diauth.garmin.com/di-oauth2-service/oauth/token"


class GarminOAuthError(RuntimeError):
    pass


@dataclass
class GarminTokens:
    access_token: str
    refresh_token: str
    expires_in: int


def build_authorization_url(state: str, code_challenge: str) -> str:
    settings = get_settings()
    if not settings.garmin_client_id:
        raise GarminOAuthError("GARMIN_CLIENT_ID is not configured.")
    return (
        f"{_AUTHORIZE_URL}?client_id={settings.garmin_client_id}"
        f"&response_type=code&redirect_uri={settings.garmin_redirect_uri}"
        f"&state={state}&code_challenge={code_challenge}&code_challenge_method=S256"
    )


async def exchange_code_for_tokens(code: str, code_verifier: str) -> GarminTokens:
    settings = get_settings()
    if not settings.garmin_client_secret:
        raise GarminOAuthError("GARMIN_CLIENT_SECRET is not configured.")

    data = {
        "grant_type": "authorization_code",
        "code": code,
        "client_id": settings.garmin_client_id,
        "client_secret": settings.garmin_client_secret,
        "redirect_uri": settings.garmin_redirect_uri,
        "code_verifier": code_verifier,
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(_TOKEN_URL, data=data)
    if resp.status_code != 200:
        raise GarminOAuthError(f"Garmin token exchange failed: {resp.status_code} {resp.text}")
    payload = resp.json()
    return GarminTokens(
        access_token=payload["access_token"],
        refresh_token=payload["refresh_token"],
        expires_in=payload["expires_in"],
    )


async def refresh_access_token(refresh_token: str) -> GarminTokens:
    settings = get_settings()
    data = {
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": settings.garmin_client_id,
        "client_secret": settings.garmin_client_secret,
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(_TOKEN_URL, data=data)
    if resp.status_code != 200:
        raise GarminOAuthError(f"Garmin token refresh failed: {resp.status_code} {resp.text}")
    payload = resp.json()
    return GarminTokens(
        access_token=payload["access_token"],
        refresh_token=payload.get("refresh_token", refresh_token),
        expires_in=payload["expires_in"],
    )
