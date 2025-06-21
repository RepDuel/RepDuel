from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from uuid import UUID

from app.schemas.message import MessageRead
from app.services.message_service import get_messages_by_channel
from app.core.auth import get_current_user
from app.api.v1.deps import get_db

router = APIRouter()

@router.get("/messages/channel/{channel_id}", response_model=List[MessageRead])
async def get_messages_for_channel(
    channel_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    messages = await get_messages_by_channel(db, channel_id)
    if not messages:
        return []
    return messages
