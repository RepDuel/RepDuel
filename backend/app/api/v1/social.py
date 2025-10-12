# backend/app/api/v1/social.py

from __future__ import annotations

from datetime import timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import get_current_user
from app.api.v1.deps import get_db
from app.models.user import User
from app.schemas.social import SocialListResponse, SocialUser
from app.services import social_service
from app.services.rate_limiter import DistributedRateLimiter
from app.services.user_service import get_user_by_id


follow_rate_limiter = DistributedRateLimiter(
    action="social_follow",
    limit=60,
    window=timedelta(hours=1),
)

router = APIRouter(prefix="/users", tags=["social"])


async def _ensure_user(db: AsyncSession, user_id: UUID) -> User:
    user = await get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


def _build_list_response(
    entries: list[dict[str, object]], offset: int, total: int
) -> SocialListResponse:
    items = [SocialUser.model_validate(entry) for entry in entries]
    count = len(items)
    next_offset = offset + count if (count and offset + count < total) else None
    return SocialListResponse(
        items=items,
        count=count,
        total=total,
        offset=offset,
        next_offset=next_offset,
    )


@router.get("/{user_id}/relationship", response_model=SocialUser)
async def get_relationship(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SocialUser:
    target = await _ensure_user(db, user_id)
    summary = await social_service.get_user_relationship(db, target, current_user.id)
    return SocialUser.model_validate(summary)


@router.post("/{user_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
async def follow_user(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    if current_user.id == user_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot follow yourself",
        )
    target = await _ensure_user(db, user_id)
    await follow_rate_limiter.check(db, current_user.id)
    await social_service.follow(db, current_user.id, target.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/{user_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
async def unfollow_user(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    target = await _ensure_user(db, user_id)
    await follow_rate_limiter.check(db, current_user.id)
    await social_service.unfollow(db, current_user.id, target.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{user_id}/followers", response_model=SocialListResponse)
async def list_followers(
    user_id: UUID,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SocialListResponse:
    await _ensure_user(db, user_id)
    entries, total = await social_service.get_followers(
        db, user_id, current_user.id, offset, limit
    )
    return _build_list_response(entries, offset, total)


@router.get("/{user_id}/following", response_model=SocialListResponse)
async def list_following(
    user_id: UUID,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SocialListResponse:
    await _ensure_user(db, user_id)
    entries, total = await social_service.get_following(
        db, user_id, current_user.id, offset, limit
    )
    return _build_list_response(entries, offset, total)


@router.get("/{user_id}/friends", response_model=SocialListResponse)
async def list_mutuals(
    user_id: UUID,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SocialListResponse:
    await _ensure_user(db, user_id)
    entries, total = await social_service.get_mutuals(
        db, user_id, current_user.id, offset, limit
    )
    return _build_list_response(entries, offset, total)


@router.get("/lookup", response_model=SocialListResponse)
async def search_users(
    q: str = Query(..., min_length=1, max_length=64),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SocialListResponse:
    query = q.strip()
    if not query:
        return _build_list_response([], offset, 0)
    entries, total = await social_service.search_users(
        db, current_user.id, query, offset, limit
    )
    return _build_list_response(entries, offset, total)
