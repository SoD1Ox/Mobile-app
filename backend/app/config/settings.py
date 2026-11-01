"""Application settings loaded from environment variables / .env file."""

import os
from functools import lru_cache
from pathlib import Path

from pydantic import computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict

# .env is always resolved relative to the backend/ directory (the folder that
# contains this package), so commands work from any cwd: `cd backend` or repo root.
_BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(_BACKEND_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # --- Database (PostgreSQL) ---
    db_host: str = "127.0.0.1"
    db_port: int = 5432
    db_name: str = "staffing_agency"
    db_user: str = "app_user"
    db_password: str = "app_pass"
    @property
    def database_url_override(self) -> str | None:
        """Full override via env var DATABASE_URL (e.g. sqlite:///./test.db).

        Read straight from os.environ because pydantic-settings v2 maps the
        field name `database_url_override` to env var DATABASE_URL_OVERRIDE,
        not DATABASE_URL.
        """
        return os.getenv("DATABASE_URL") or None

    @computed_field  # type: ignore[prop-decorator]
    @property
    def database_url(self) -> str:
        """Final SQLAlchemy URL: explicit DATABASE_URL wins, else DB_* parts."""
        if self.database_url_override:
            return self.database_url_override
        return (
            f"postgresql+psycopg2://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )

    # --- Security / JWT ---
    secret_key: str = "change-me-in-production-9f8a7b6c5d4e3f2a1b0c"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 7

    # --- API meta ---
    api_title: str = "Staffing Agency API"
    api_version: str = "1.0.0"


@lru_cache
def get_settings() -> "Settings":
    return Settings()


settings = get_settings()
