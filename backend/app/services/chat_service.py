from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.models.message import Message
from app.models.user import User
from app.schemas.message import MessageRead
from app.schemas.user import UserRead
from app.services.rank_service import (get_rank_color, get_rank_from_energy,
                                       get_rank_icon_path)


async def enrich_message(db: AsyncSession, message: Message) -> dict:
    # Fetch author
    result = await db.execute(select(User).where(User.id == message.author_id))
    user: User | None = result.scalar_one_or_none()
    if not user:
        raise ValueError(f"User not found: {message.author_id}")

    # Derive rank from user.energy
    energy = user.energy or 0
    rank = get_rank_from_energy(energy)
    color = get_rank_color(rank)
    icon_path = get_rank_icon_path(rank)

    return {
        "message": MessageRead.from_orm(message),
        "user": UserRead.from_orm(user),
        "rankColor": color,
        "rankIconPath": icon_path,
    }
