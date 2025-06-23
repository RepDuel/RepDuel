from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field


class MessageBase(BaseModel):
    content: str = Field(..., example="Hello, world!")


class MessageCreate(MessageBase):
    channel_id: UUID


class MessageRead(MessageBase):
    id: UUID = Field(..., alias="id")
    author_id: UUID = Field(..., alias="authorId")
    channel_id: UUID = Field(..., alias="channelId")
    created_at: datetime = Field(..., alias="createdAt")
    updated_at: datetime = Field(..., alias="updatedAt")

    model_config = {
        "from_attributes": True,
        "populate_by_name": True
    }
