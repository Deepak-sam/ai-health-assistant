"""In-process, time-limited store for OAuth PKCE state and connected Garmin
sessions.

**Phase 1 limitation, documented deliberately rather than hidden**: this is
an in-memory dict, not a database. It is lost on redeploy/restart and is not
shared across Cloud Run instances if `min-instances`/`max-instances` ever
scale beyond one concurrent instance. For a 4-10 person family app this is an
acceptable tradeoff for Phase 1 (§28: no extra infra "just in case") — a
dropped OAuth attempt just means the user taps "Connect Garmin" again. If
this becomes a real problem, replace with a small Firestore collection
keyed by state/session_ref with a TTL, without changing the public API of
this module.
"""
import time
from dataclasses import dataclass

_PENDING_TTL_SECONDS = 10 * 60


@dataclass
class PendingAuthorization:
    code_verifier: str
    uid: str
    created_at: float


@dataclass
class GarminSession:
    uid: str
    refresh_token: str
    created_at: float


_pending: dict[str, PendingAuthorization] = {}
_sessions: dict[str, GarminSession] = {}


def _evict_expired_pending() -> None:
    now = time.time()
    expired = [state for state, p in _pending.items() if now - p.created_at > _PENDING_TTL_SECONDS]
    for state in expired:
        _pending.pop(state, None)


def store_pending(state: str, code_verifier: str, uid: str) -> None:
    _evict_expired_pending()
    _pending[state] = PendingAuthorization(code_verifier=code_verifier, uid=uid, created_at=time.time())


def pop_pending(state: str) -> PendingAuthorization | None:
    _evict_expired_pending()
    return _pending.pop(state, None)


def store_session(session_ref: str, uid: str, refresh_token: str) -> None:
    _sessions[session_ref] = GarminSession(uid=uid, refresh_token=refresh_token, created_at=time.time())


def get_session(session_ref: str) -> GarminSession | None:
    return _sessions.get(session_ref)


def clear_session(session_ref: str) -> None:
    _sessions.pop(session_ref, None)
