# backend/app/api/v1/quests.py

"""Quest-related API endpoints."""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import get_current_user
from app.api.v1.deps import get_db
from app.models.user import User
from app.schemas.quest import QuestInstance, QuestListResponse
from app.services.quest_service import claim_user_quest, get_user_quests

router = APIRouter(prefix="/quests", tags=["quests"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


@router.get("/me", response_model=QuestListResponse)
async def read_my_quests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> QuestListResponse:
    timestamp = _now()
    quests = await get_user_quests(db, current_user.id, now=timestamp)
    payload = [QuestInstance.from_model(q) for q in quests]
    return QuestListResponse(generated_at=timestamp, quests=payload)


@router.post(
    "/me/{quest_id}/claim",
    response_model=QuestInstance,
    status_code=status.HTTP_200_OK,
)
async def claim_my_quest(
    quest_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> QuestInstance:
    try:
        quest = await claim_user_quest(db, current_user.id, quest_id, now=_now())
    except NoResultFound:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="quest not found")
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    return QuestInstance.from_model(quest)

