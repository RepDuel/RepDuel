# backend/app/services/message_service.py

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.models.message import Message
from app.schemas.message import MessageCreate


async def create_message(
    db: AsyncSession, message_in: MessageCreate, author_id: UUID
) -> Message:
    message = Message(
        content=message_in.content,
        channel_id=message_in.channel_id,
        author_id=author_id,
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)
    return message


async def get_messages_by_channel(
    db: AsyncSession, channel_id: UUID, limit: int = 50, offset: int = 0
) -> list[Message]:
    result = await db.execute(
        select(Message)
        .where(Message.channel_id == channel_id)
        .order_by(Message.created_at.asc())
        .offset(offset)
        .limit(limit)
    )
    return result.scalars().all()
