# backend/app/core/config.py

import json
import os
from typing import List, Optional, Union

from pydantic import AnyHttpUrl, Field, AliasChoices, PostgresDsn, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_URL: str
    BASE_URL: str
    DATABASE_URL: PostgresDsn
    STATIC_PUBLIC_BASE: Optional[AnyHttpUrl] = Field(
        default=None,
        validation_alias=AliasChoices("STATIC_PUBLIC_BASE", "static_public_base"),
    )

    JWT_SECRET_KEY: str
    REFRESH_JWT_SECRET_KEY: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices(
            "REFRESH_JWT_SECRET_KEY", "JWT_REFRESH_SECRET_KEY", "jwt_refresh_secret_key"
        ),
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(
        default=30,
        validation_alias=AliasChoices("REFRESH_TOKEN_EXPIRE_DAYS", "refresh_token_expire_days"),
    )

    REVENUECAT_WEBHOOK_AUTH_TOKEN: str = Field(
        validation_alias=AliasChoices("REVENUECAT_WEBHOOK_AUTH_TOKEN", "revenuecat_webhook_auth_token"),
    )
    STRIPE_SECRET_KEY: str
    STRIPE_WEBHOOK_SECRET: str

    STATIC_STORAGE_DIR: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices(
            "STATIC_STORAGE_DIR",
            "static_storage_dir",
        ),
    )

    APPLE_TEAM_ID: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("APPLE_TEAM_ID", "apple_team_id"),
    )
    IOS_BUNDLE_ID: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("IOS_BUNDLE_ID", "ios_bundle_id"),
    )
    OPENAI_API_KEY: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("OPENAI_API_KEY", "openai_api_key"),
    )

    FRONTEND_ORIGINS: List[AnyHttpUrl] = Field(
        default_factory=list,
        validation_alias=AliasChoices(
            "FRONTEND_ORIGINS",
            "CORS_ALLOW_ORIGINS",
            "cors_allow_origins",
            "frontend_origins",
        ),
    )

    COOKIE_SAMESITE: str = Field(
        default="none",
        validation_alias=AliasChoices(
            "COOKIE_SAMESITE",
            "REFRESH_COOKIE_SAMESITE",
            "refresh_cookie_samesite",
            "cookie_samesite",
        ),
    )
    COOKIE_SECURE: bool = Field(
        default=True,
        validation_alias=AliasChoices(
            "COOKIE_SECURE",
            "REFRESH_COOKIE_SECURE",
            "refresh_cookie_secure",
            "cookie_secure",
        ),
    )
    COOKIE_DOMAIN: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices(
            "COOKIE_DOMAIN",
            "cookie_domain",
        ),
    )

    XP_MAX_LEVEL: int = Field(
        default=100,
        validation_alias=AliasChoices("XP_MAX_LEVEL", "xp_max_level"),
    )
    XP_CURVE_BASE: int = Field(
        default=100,
        validation_alias=AliasChoices("XP_CURVE_BASE", "xp_curve_base"),
    )

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
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
                    arr = json.loads(s)
                    if isinstance(arr, list):
                        return [str(item).strip() for item in arr]
                except Exception:
                    pass
            return [item.strip() for item in s.split(",") if item.strip()]
        return v

    @model_validator(mode="after")
    def _normalize(self) -> "Settings":
        self.BASE_URL = self.BASE_URL.rstrip("/")
        if self.STATIC_PUBLIC_BASE:
            self.STATIC_PUBLIC_BASE = str(self.STATIC_PUBLIC_BASE).rstrip("/")
        else:
            self.STATIC_PUBLIC_BASE = f"{self.BASE_URL.rstrip('/')}/static"

        default_static_dir = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "static")
        )
        static_dir = (self.STATIC_STORAGE_DIR or "").strip() if isinstance(self.STATIC_STORAGE_DIR, str) else None
        if static_dir:
            static_dir = os.path.abspath(os.path.expanduser(static_dir))
        else:
            static_dir = default_static_dir
        self.STATIC_STORAGE_DIR = static_dir

        if not self.REFRESH_JWT_SECRET_KEY:
            self.REFRESH_JWT_SECRET_KEY = self.JWT_SECRET_KEY
        if self.COOKIE_SAMESITE:
            self.COOKIE_SAMESITE = self.COOKIE_SAMESITE.strip().lower()
        if self.XP_MAX_LEVEL < 1:
            self.XP_MAX_LEVEL = 1
        if self.XP_CURVE_BASE < 1:
            self.XP_CURVE_BASE = 1
        if self.COOKIE_DOMAIN:
            self.COOKIE_DOMAIN = self.COOKIE_DOMAIN.strip()
        return self


settings = Settings()
