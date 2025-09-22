# backend/app/api/v1/personal_best_events.py

from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_db
from app.core.auth import get_current_user
from app.models.personal_best_event import PersonalBestEvent
from app.models.user import User
from app.schemas.personal_best_event import PersonalBestEventRead

router = APIRouter(prefix="/personal_best_events", tags=["Personal Best Events"])


@router.get("/user/{user_id}", response_model=list[PersonalBestEventRead])
async def list_personal_best_events(
    user_id: UUID,
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _current_user: User = Depends(get_current_user),
):
    stmt = (
        select(PersonalBestEvent)
        .where(PersonalBestEvent.user_id == user_id)
        .order_by(PersonalBestEvent.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(stmt)
    events = result.scalars().all()
    return list(events)
