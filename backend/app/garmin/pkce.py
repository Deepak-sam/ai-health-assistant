"""PKCE (RFC 7636) helpers for the server-side half of Garmin's OAuth2 flow.

The mobile app never generates or sees a code verifier/challenge — see
docs/ARCHITECTURE.md §6 and mobile/README.md "Garmin OAuth notes".
"""
import base64
import hashlib
import secrets


def generate_verifier() -> str:
    return base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode("ascii")


def generate_challenge(verifier: str) -> str:
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")


def generate_state() -> str:
    return secrets.token_urlsafe(24)


def generate_session_ref() -> str:
    return secrets.token_urlsafe(32)
