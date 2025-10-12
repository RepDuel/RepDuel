# backend/app/services/rate_limiter.py

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.rate_limit_event import RateLimitEvent


class DistributedRateLimiter:
    """Database-backed rate limiter that coordinates across workers."""

    def __init__(self, action: str, *, limit: int, window: timedelta) -> None:
        self.action = action
        self.limit = limit
        self.window = window

    async def check(self, db: AsyncSession, user_id: UUID) -> None:
        now = datetime.now(timezone.utc)
        cutoff = now - self.window

        count_stmt = (
            select(func.count())
            .select_from(RateLimitEvent)
            .where(
                RateLimitEvent.user_id == user_id,
                RateLimitEvent.action == self.action,
                RateLimitEvent.occurred_at >= cutoff,
            )
        )
        current_count = await db.scalar(count_stmt)
        if (current_count or 0) >= self.limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded",
            )

        db.add(
            RateLimitEvent(
                user_id=user_id,
                action=self.action,
                occurred_at=now,
            )
        )
        await db.flush()

        cleanup_stmt = (
            delete(RateLimitEvent)
            .where(RateLimitEvent.occurred_at < cutoff - timedelta(minutes=5))
            .where(RateLimitEvent.action == self.action)
        )
        await db.execute(cleanup_stmt)
