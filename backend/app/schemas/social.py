# backend/app/schemas/social.py

from uuid import UUID

from pydantic import BaseModel


class SocialUser(BaseModel):
    id: UUID
    username: str
    display_name: str | None = None
    avatar_url: str | None = None
    is_following: bool
    is_followed_by: bool
    is_friend: bool
    is_self: bool

    model_config = {"from_attributes": True}


class SocialListResponse(BaseModel):
    items: list[SocialUser]
    count: int
    total: int
    offset: int
    next_offset: int | None = None
