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
    db_name: str = "staffing_agency"
    db_user: str = "app_user"
    db_password: str = "app_pass"
    database_url: str | None = None  # env: DATABASE_URL

    def model_post_init(self, __context) -> None:
        """Build database_url from DB_* parts if DATABASE_URL is not set."""
        url = self.database_url or (
            f"postgresql+psycopg2://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )
        if not url.startswith(("postgresql://", "postgresql+")):
            raise ValueError("This application requires PostgreSQL.")
        if (
            len(self.secret_key.encode("utf-8")) < 32
            or self.secret_key.startswith("change-me-in-production")
            or self.secret_key.startswith("replace-with-")
        ):
            raise ValueError(
                "SECRET_KEY must be a unique random value of at least 32 bytes."
            )
        object.__setattr__(self, "database_url", url)

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
