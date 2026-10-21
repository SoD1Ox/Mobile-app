"""Application settings loaded from environment variables / .env file."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    # --- Database (PostgreSQL) ---
    db_host: str = "127.0.0.1"
    db_port: int = 5432
    db_name: str = "mobile_app"
    db_user: str = "app_user"
    db_password: str = "app_pass"

    # --- Security / JWT ---
    secret_key: str = "change-me-in-production-9f8a7b6c5d4e3f2a1b0c"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 7

    # --- API meta ---
    api_title: str = "Mobile-app API"
    api_version: str = "1.0.0"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


@lru_cache
def get_settings() -> "Settings":
    return Settings()


settings = get_settings()
