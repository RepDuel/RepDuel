# backend/app/schemas/social.py

from uuid import UUID

from pydantic import BaseModel, FieldSerializationInfo, field_serializer

from app.utils.storage import build_public_url


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

    @field_serializer("avatar_url")
    def _serialize_avatar_url(
        self, value: str | None, info: FieldSerializationInfo
    ) -> str | None:
        return build_public_url(value)


class SocialListResponse(BaseModel):
    items: list[SocialUser]
    count: int
    total: int
    offset: int
    next_offset: int | None = None
