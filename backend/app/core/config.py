# backend/app/core/config.py

from pydantic import PostgresDsn, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_URL: str
    BASE_URL: str
    DATABASE_URL: PostgresDsn

    JWT_SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # ⬇️ Added for refresh-token flow
    JWT_REFRESH_SECRET_KEY: str
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    REVENUECAT_WEBHOOK_AUTH_TOKEN: str
    STRIPE_SECRET_KEY: str
    STRIPE_WEBHOOK_SECRET: str

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    @model_validator(mode="after")
    def normalize_base_url(self) -> "Settings":
        self.BASE_URL = self.BASE_URL.rstrip("/")
        return self


settings = Settings()
