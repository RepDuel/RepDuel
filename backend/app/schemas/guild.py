# backend/app/schemas/guild.py

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


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
