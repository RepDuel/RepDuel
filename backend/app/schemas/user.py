# backend/app/schemas/user.py

from datetime import datetime
from typing import Optional, Literal
from uuid import UUID

from pydantic import (
    BaseModel,
    EmailStr,
    FieldSerializationInfo,
    ValidationInfo,
    field_serializer,
    field_validator,
)

from app.utils.datetime import ensure_aware_utc
from app.utils.storage import build_public_url


class UserBase(BaseModel):
    username: str
    email: EmailStr
    avatar_url: str | None = None
    display_name: str | None = None
    subscription_level: str = "free"
    preferred_unit: Literal["kg", "lbs"] = "kg"


class UserCreate(UserBase):
    password: str


class UserRead(UserBase):
    id: UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime
    avatar_url: str | None = None
    display_name: str | None = None
    weight: float | None = None
    gender: str | None = None
    weight_multiplier: float = 1.0
    subscription_level: str = "free"
    energy: float | None = 0.0
    rank: str | None = "Unranked"
    original_transaction_id: str | None = None
    preferred_unit: Literal["kg", "lbs"] = "kg"

    model_config = {"from_attributes": True}

    @field_validator("created_at", "updated_at", mode="after")
    def _validate_timestamps(cls, value: datetime, info: ValidationInfo) -> datetime:
        return ensure_aware_utc(value, field_name=info.field_name, allow_naive=True)

    @field_serializer("avatar_url")
    def _serialize_avatar_url(
        self, value: str | None, info: FieldSerializationInfo
    ) -> str | None:
        return build_public_url(value)


class UserUpdate(BaseModel):
    username: str | None = None
    email: EmailStr | None = None
    avatar_url: str | None = None
    display_name: str | None = None
    weight: float | None = None
    gender: str | None = None
    password: str | None = None
    weight_multiplier: float | None = None
    subscription_level: str | None = None
    energy: float | None = None
    rank: str | None = None
    original_transaction_id: str | None = None
    preferred_unit: Literal["kg", "lbs"] | None = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str
