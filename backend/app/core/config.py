# backend/app/core/config.py

from pydantic import AnyHttpUrl, PostgresDsn, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # App / DB
    APP_URL: AnyHttpUrl
    BASE_URL: AnyHttpUrl
    DATABASE_URL: PostgresDsn

    # JWT / access tokens
    JWT_SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # Refresh tokens
    JWT_REFRESH_SECRET_KEY: str
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Refresh cookie options (works for iOS + web)
    REFRESH_COOKIE_NAME: str = "refresh_token"
    REFRESH_COOKIE_PATH: str = "/api/v1/users"
    REFRESH_COOKIE_DOMAIN: str | None = None  # e.g. ".repduel.com" if subdomains
    REFRESH_COOKIE_SAMESITE: str = "lax"      # use "none" for cross-site
    REFRESH_COOKIE_SECURE: bool = True        # must be True in production

    # CORS (needed if frontend != backend domain)
    CORS_ALLOW_ORIGINS: list[AnyHttpUrl] = []

    # External services
    REVENUECAT_WEBHOOK_AUTH_TOKEN: str
    STRIPE_SECRET_KEY: str
    STRIPE_WEBHOOK_SECRET: str

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    @model_validator(mode="after")
    def normalize_base_url(self) -> "Settings":
        self.BASE_URL = str(self.BASE_URL).rstrip("/")
        return self


settings = Settings()
