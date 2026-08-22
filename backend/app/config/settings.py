"""Environment-driven configuration. Never hardcode secrets here."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Gemini
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"
    gemini_model_strong: str = "gemini-2.5-pro"
    gemini_api_base: str = "https://generativelanguage.googleapis.com/v1beta"

    # Firebase
    firebase_project_id: str = ""

    # Garmin (server-side OAuth2 PKCE token exchange)
    garmin_client_id: str = ""
    garmin_client_secret: str = ""
    garmin_redirect_uri: str = ""
    # Custom URL scheme the mobile app registers to catch the end of the
    # OAuth redirect chain (must match the app's GARMIN_REDIRECT_SCHEME
    # --dart-define — see mobile/README.md "Garmin OAuth notes").
    garmin_app_redirect_scheme: str = "familyhealth"

    # App
    backend_url: str = "http://localhost:8080"
    allowed_origins: str = "*"
    max_photo_bytes: int = 8 * 1024 * 1024

    # Auth: comma-separated list of allowlisted family emails, used only
    # when no external allowlist store is configured. In production this
    # would back onto a small Firestore collection or similar; a static
    # env var is a deliberately simple choice for a 4-10 person family app.
    allowlisted_emails: str = ""

    @property
    def allowlisted_email_set(self) -> set[str]:
        return {e.strip().lower() for e in self.allowlisted_emails.split(",") if e.strip()}


@lru_cache
def get_settings() -> Settings:
    return Settings()
