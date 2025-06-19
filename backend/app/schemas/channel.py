from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional


class ChannelCreate(BaseModel):
    name: str
    guild_id: UUID


class ChannelRead(ChannelCreate):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True
