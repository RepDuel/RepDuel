# backend/app/core/config.py

from typing import List, Optional, Union
from pydantic import (
    AnyHttpUrl,
    Field,
    AliasChoices,
    PostgresDsn,
    field_validator,
    model_validator,
)
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # App & infrastructure
    APP_URL: str
    BASE_URL: str
    DATABASE_URL: PostgresDsn

    # JWT / Auth
    JWT_SECRET_KEY: str
    REFRESH_JWT_SECRET_KEY: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("REFRESH_JWT_SECRET_KEY", "JWT_REFRESH_SECRET_KEY", "jwt_refresh_secret_key"),
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Third-party
    REVENUECAT_WEBHOOK_AUTH_TOKEN: str
    STRIPE_SECRET_KEY: str
    STRIPE_WEBHOOK_SECRET: str

    # CORS
    FRONTEND_ORIGINS: List[AnyHttpUrl] = Field(
        default_factory=list,
        validation_alias=AliasChoices("FRONTEND_ORIGINS", "CORS_ALLOW_ORIGINS", "cors_allow_origins"),
    )

    # Cookie settings
    COOKIE_SAMESITE: str = Field(
        default="None",
        validation_alias=AliasChoices("COOKIE_SAMESITE", "REFRESH_COOKIE_SAMESITE", "refresh_cookie_samesite"),
    )
    COOKIE_SECURE: bool = Field(
        default=True,
        validation_alias=AliasChoices("COOKIE_SECURE", "REFRESH_COOKIE_SECURE", "refresh_cookie_secure"),
    )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @field_validator("FRONTEND_ORIGINS", mode="before")
    @classmethod
    def _parse_origins(cls, v: Union[str, List[str], List[AnyHttpUrl]]):
        if v is None or v == "":
            return []
        if isinstance(v, list):
            return v
        if isinstance(v, str):
            s = v.strip()
            if s.startswith("[") and s.endswith("]"):
                try:
                    import json
                    arr = json.loads(s)
                    if isinstance(arr, list):
                        return [item.strip() for item in arr]
                except Exception:
                    pass
            return [item.strip() for item in s.split(",") if item.strip()]
        return v

    @model_validator(mode="after")
    def _normalize(self) -> "Settings":
        self.BASE_URL = self.BASE_URL.rstrip("/")
        if not self.REFRESH_JWT_SECRET_KEY:
            self.REFRESH_JWT_SECRET_KEY = self.JWT_SECRET_KEY
        if self.COOKIE_SAMESITE:
            self.COOKIE_SAMESITE = self.COOKIE_SAMESITE.capitalize()
        return self


settings = Settings()
