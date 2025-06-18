from pydantic import BaseModel
from uuid import UUID
from datetime import datetime


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

    class Config:
        from_attributes = True
