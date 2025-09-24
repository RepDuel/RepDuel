# backend/app/api/v1/social.py

from __future__ import annotations

import asyncio
from collections import deque
from datetime import datetime, timedelta, timezone
from typing import Deque, Dict
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.auth import get_current_user
from app.api.v1.deps import get_db
from app.models.user import User
from app.schemas.social import SocialListResponse, SocialUser
from app.services import social_service
from app.services.user_service import get_user_by_id


class InMemoryRateLimiter:
    """Very small in-memory rate limiter used for follow/unfollow endpoints."""

    def __init__(self, limit: int, window_seconds: int) -> None:
        self.limit = limit
        self.window = timedelta(seconds=window_seconds)
        self._events: Dict[UUID, Deque[datetime]] = {}
        self._lock = asyncio.Lock()

    async def check(self, key: UUID) -> None:
        now = datetime.now(timezone.utc)
        async with self._lock:
            queue = self._events.setdefault(key, deque())
            cutoff = now - self.window
            while queue and queue[0] <= cutoff:
                queue.popleft()
            if len(queue) >= self.limit:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Rate limit exceeded",
                )
            queue.append(now)

    def reset(self) -> None:
        self._events.clear()


follow_rate_limiter = InMemoryRateLimiter(limit=60, window_seconds=3600)

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
    await follow_rate_limiter.check(current_user.id)
    await social_service.follow(db, current_user.id, target.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/{user_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
async def unfollow_user(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Response:
    target = await _ensure_user(db, user_id)
    await follow_rate_limiter.check(current_user.id)
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
