# backend/app/schemas/user.py

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr


class UserBase(BaseModel):
    username: str
    email: EmailStr
    avatar_url: str | None = None
    subscription_level: str = "free"


class UserCreate(UserBase):
    password: str


class UserRead(UserBase):
    id: UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime
    avatar_url: str | None = None
    weight: float | None = None
    gender: str | None = None
    weight_multiplier: float = 1.0
    subscription_level: str = "free"

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    username: str | None = None
    email: EmailStr | None = None
    avatar_url: str | None = None
    weight: float | None = None
    gender: str | None = None
    password: str | None = None
    weight_multiplier: float | None = None
    subscription_level: str | None = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str
