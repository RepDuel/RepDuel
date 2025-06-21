# backend/app/schemas/message.py

from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field


class MessageBase(BaseModel):
    content: str = Field(..., example="Hello, world!")


class MessageCreate(MessageBase):
    channel_id: UUID


class MessageRead(MessageBase):
    id: UUID
    author_id: UUID
    channel_id: UUID
    created_at: datetime
    updated_at: datetime

    model_config = {
        "from_attributes": True
    }
