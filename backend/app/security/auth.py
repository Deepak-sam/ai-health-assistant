"""Firebase ID token verification + family allowlist gate.

Kept deliberately simple for a 4-10 person family app (§12/§28): no custom
password stack, no per-request DB round trip beyond an in-process set lookup.
"""
from dataclasses import dataclass

import firebase_admin
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth as firebase_auth

from app.config.settings import get_settings


class AllowlistError(HTTPException):
    def __init__(self) -> None:
        super().__init__(
            status_code=403,
            detail={
                "error": {
                    "code": "not_allowlisted",
                    "message": "This account is not authorized for this family instance.",
                }
            },
        )


class UnauthorizedError(HTTPException):
    def __init__(self, message: str = "Missing or invalid authentication token.") -> None:
        super().__init__(
            status_code=401,
            detail={"error": {"code": "unauthorized", "message": message}},
        )


@dataclass(frozen=True)
class AuthenticatedUser:
    uid: str
    email: str


_bearer = HTTPBearer(auto_error=False)
_firebase_app: firebase_admin.App | None = None


def _ensure_firebase_app() -> None:
    global _firebase_app
    if _firebase_app is None:
        settings = get_settings()
        options = {"projectId": settings.firebase_project_id} if settings.firebase_project_id else None
        _firebase_app = firebase_admin.initialize_app(options=options)


def verify_id_token(token: str) -> AuthenticatedUser:
    """Verify a Firebase ID token and return the caller's identity.

    Split out from the FastAPI dependency so it can be unit tested without
    spinning up the full request/response cycle.
    """
    _ensure_firebase_app()
    try:
        decoded = firebase_auth.verify_id_token(token)
    except Exception as exc:  # firebase_admin raises several distinct exception types
        raise UnauthorizedError(f"Token verification failed: {exc}") from exc

    email = decoded.get("email")
    if not email:
        raise UnauthorizedError("Token does not carry a verified email.")
    return AuthenticatedUser(uid=decoded["uid"], email=email.lower())


def check_allowlist(user: AuthenticatedUser) -> None:
    settings = get_settings()
    if user.email not in settings.allowlisted_email_set:
        raise AllowlistError()


async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> AuthenticatedUser:
    if credentials is None or not credentials.credentials:
        raise UnauthorizedError()
    user = verify_id_token(credentials.credentials)
    check_allowlist(user)
    return user
