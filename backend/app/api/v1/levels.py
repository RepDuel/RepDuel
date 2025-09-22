# backend/app/api/v1/levels.py

from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import get_current_user
from app.api.v1.deps import get_db
from app.models.user import User
from app.schemas.level import AwardXPRequest, AwardXPResponse, LevelProgress
from app.services.level_service import (
    LevelStats,
    award_xp,
    get_level_progress,
    xp_gained_this_week,
)
from app.services.user_service import get_user_by_id

router = APIRouter(prefix="/levels", tags=["levels"])


async def _to_schema(
    db: AsyncSession, user_id: UUID, stats: LevelStats
) -> LevelProgress:
    weekly_xp = await xp_gained_this_week(db, user_id)
    return LevelProgress(
        level=stats.level,
        xp=stats.total_xp,
        xp_to_next=stats.xp_to_next,
        progress_pct=stats.progress_pct,
        xp_gained_this_week=weekly_xp,
    )


@router.get("/me", response_model=LevelProgress)
async def read_my_level(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LevelProgress:
    stats = await get_level_progress(db, current_user.id)
    return await _to_schema(db, current_user.id, stats)


@router.get("/user/{user_id}", response_model=LevelProgress)
async def read_user_level(user_id: UUID, db: AsyncSession = Depends(get_db)) -> LevelProgress:
    user = await get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    stats = await get_level_progress(db, user.id)
    return await _to_schema(db, user.id, stats)


@router.post(
    "/me/award",
    response_model=AwardXPResponse,
    status_code=status.HTTP_200_OK,
)
async def award_my_level_xp(
    payload: AwardXPRequest,
    idempotency_key_header: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AwardXPResponse:
    reason = payload.reason.strip() if payload.reason else None
    header_key = idempotency_key_header.strip() if idempotency_key_header else None
    idempotency_key = header_key or payload.idempotency_key
    try:
        result = await award_xp(
            db,
            current_user.id,
            payload.amount,
            reason=reason,
            idempotency_key=idempotency_key,
            source_type=payload.source_type,
            source_id=payload.source_id,
        )
    except ValueError as exc:  # pragma: no cover - defensive guard
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))

    progress = await _to_schema(db, current_user.id, result.stats)
    return AwardXPResponse(
        awarded=result.awarded,
        reason=result.reason,
        progress=progress,
    )
