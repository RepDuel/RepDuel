# backend/app/schemas/social.py

from uuid import UUID

from pydantic import BaseModel


class SocialUser(BaseModel):
    id: UUID
    username: str
    avatar_url: str | None = None

    model_config = {"from_attributes": True}


class SocialListResponse(BaseModel):
    items: list[SocialUser]
    count: int
    total: int
    offset: int
    next_offset: int | None = None
