# backend/app/schemas/guild.py

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ValidationInfo, field_validator

from app.utils.datetime import ensure_aware_utc


class GuildBase(BaseModel):
    name: str
    icon_url: str | None = None


class GuildCreate(GuildBase):
    pass


class GuildRead(GuildBase):
    id: UUID
    owner_id: UUID
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @field_validator("created_at", "updated_at", mode="after")
    def _validate_timestamps(cls, value: datetime, info: ValidationInfo) -> datetime:
        return ensure_aware_utc(value, field_name=info.field_name, allow_naive=True)
