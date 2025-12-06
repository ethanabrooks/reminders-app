from functools import cache
from pathlib import Path

from fastmcp.dependencies import Depends
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from pydantic import Field, ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict

from google_tasks_client import GoogleTasksClient


class Settings(BaseSettings):
    """Configuration loaded from environment or .env."""

    credentials_path: Path = Field(
        default=Path("credentials.json"),
        description="Path to Google OAuth client credentials JSON (installed app).",
    )
    token_path: Path = Field(
        default=Path("token.json"),
        description="Path to stored OAuth access/refresh token.",
    )
    default_tasklist_id: str = Field(
        default="@default",
        description="Default task list id to use when none is provided.",
    )
    scopes: list[str] = Field(
        default_factory=lambda: ["https://www.googleapis.com/auth/tasks"],
        description="OAuth scopes for Google Tasks.",
    )

    model_config = SettingsConfigDict(env_file=".env")


@cache
def get_settings() -> Settings:
    return Settings()


def _load_credentials(settings: Settings) -> Credentials:
    if not settings.token_path.exists():
        raise ValueError(
            f"Token file not found at {settings.token_path}. "
            "Run the OAuth flow once to create it."
        )

    try:
        credentials = Credentials.from_authorized_user_file(
            str(settings.token_path), scopes=settings.scopes
        )
    except (OSError, ValidationError) as exc:
        raise ValueError(f"Failed to load token from {settings.token_path}") from exc

    if not credentials.valid and credentials.expired and credentials.refresh_token:
        credentials.refresh(Request())
        settings.token_path.write_text(credentials.to_json())

    if not credentials.valid:
        raise ValueError("Google credentials are invalid and could not be refreshed.")

    return credentials


def get_tasks_client(settings: Settings = Depends(get_settings)) -> GoogleTasksClient:
    """Provide an authenticated Google Tasks client wrapper."""
    credentials = _load_credentials(settings)
    return GoogleTasksClient(credentials=credentials)


def get_default_tasklist(settings: Settings = Depends(get_settings)) -> str:
    return settings.default_tasklist_id
