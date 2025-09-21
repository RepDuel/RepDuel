# backend/app/services/level_service.py

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.user_xp import UserXP
from app.models.xp_event import XPEvent


@dataclass
class LevelStats:
    """Computed information about a user's XP progress."""

    level: int
    total_xp: int
    xp_to_next: int
    progress_pct: float


@dataclass
class AwardOutcome:
    """Result of attempting to award XP to a user."""

    stats: LevelStats
    awarded: bool
    reason: str


def _resolve_base(base: Optional[int]) -> int:
    value = base if base is not None else settings.XP_CURVE_BASE
    return max(1, int(value))


def _resolve_cap(max_level: Optional[int]) -> int:
    cap = max_level if max_level is not None else settings.XP_MAX_LEVEL
    return max(1, int(cap))


def xp_for_level(level: int, *, base: Optional[int] = None) -> int:
    """Return the total XP required to *reach* the provided level."""

    if level <= 1:
        return 0
    curve_base = _resolve_base(base)
    return int(curve_base * (level - 1) ** 2)


def level_for_xp(
    total_xp: int, *, base: Optional[int] = None, max_level: Optional[int] = None
) -> int:
    """Compute the level for a given total XP along a quadratic curve."""

    sanitized_xp = max(0, int(total_xp))
    curve_base = _resolve_base(base)
    level_cap = _resolve_cap(max_level)

    if sanitized_xp <= 0:
        return 1

    approx = int(math.floor(math.sqrt(sanitized_xp / curve_base))) + 1
    level = max(1, approx)

    if level > level_cap:
        return level_cap

    while level > 1 and sanitized_xp < xp_for_level(level, base=curve_base):
        level -= 1
    while level < level_cap and sanitized_xp >= xp_for_level(
        level + 1, base=curve_base
    ):
        level += 1

    return min(level, level_cap)


def compute_level_stats(
    total_xp: int, *, base: Optional[int] = None, max_level: Optional[int] = None
) -> LevelStats:
    """Return level progression metadata for a total XP amount."""

    sanitized_xp = max(0, int(total_xp))
    curve_base = _resolve_base(base)
    level_cap = _resolve_cap(max_level)

    level = level_for_xp(sanitized_xp, base=curve_base, max_level=level_cap)
    current_threshold = xp_for_level(level, base=curve_base)

    if level >= level_cap:
        xp_to_next = 0
        progress_pct = 1.0
    else:
        next_threshold = xp_for_level(level + 1, base=curve_base)
        span = max(1, next_threshold - current_threshold)
        xp_to_next = max(0, next_threshold - sanitized_xp)
        progress_pct = (sanitized_xp - current_threshold) / span
        progress_pct = max(0.0, min(1.0, progress_pct))

    return LevelStats(
        level=level,
        total_xp=sanitized_xp,
        xp_to_next=xp_to_next,
        progress_pct=1.0 if level >= level_cap else progress_pct,
    )


async def get_user_xp(db: AsyncSession, user_id: UUID) -> UserXP | None:
    result = await db.execute(select(UserXP).where(UserXP.user_id == user_id))
    return result.scalars().first()


async def ensure_user_xp(
    db: AsyncSession, user_id: UUID, *, auto_commit: bool = True
) -> UserXP:
    summary = await get_user_xp(db, user_id)
    if summary:
        return summary

    now = datetime.now(timezone.utc)
    summary = UserXP(
        user_id=user_id,
        total_xp=0,
        level=1,
        updated_at=now,
        last_event_at=None,
    )
    db.add(summary)

    if auto_commit:
        await db.commit()
        await db.refresh(summary)
    else:
        await db.flush()
    return summary


async def get_level_progress(db: AsyncSession, user_id: UUID) -> LevelStats:
    summary = await ensure_user_xp(db, user_id)
    stats = compute_level_stats(summary.total_xp)
    if summary.level != stats.level:
        summary.level = stats.level
        summary.updated_at = datetime.now(timezone.utc)
        await db.commit()
    return stats


async def xp_gained_since(db: AsyncSession, user_id: UUID, since: datetime) -> int:
    """Return the total XP gained since the provided timestamp."""

    result = await db.execute(
        select(func.coalesce(func.sum(XPEvent.amount), 0)).where(
            XPEvent.user_id == user_id, XPEvent.created_at >= since
        )
    )
    total = result.scalar()
    return int(total or 0)


async def xp_gained_this_week(db: AsyncSession, user_id: UUID) -> int:
    """Return the XP gained within the last seven days."""

    now = datetime.now(timezone.utc)
    week_start = now - timedelta(days=7)
    return await xp_gained_since(db, user_id, week_start)


def _normalize(value: str | None) -> str | None:
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed or None


async def award_xp(
    db: AsyncSession,
    user_id: UUID,
    amount: int,
    *,
    reason: str | None = None,
    idempotency_key: str | None = None,
    source_type: str | None = None,
    source_id: str | None = None,
) -> AwardOutcome:
    if amount <= 0:
        raise ValueError("amount must be a positive integer")

    summary = await ensure_user_xp(db, user_id, auto_commit=False)

    normalized_key = _normalize(idempotency_key)
    normalized_source_type = _normalize(source_type)
    normalized_source_id = _normalize(source_id)

    current_stats = compute_level_stats(int(summary.total_xp or 0))

    if normalized_key:
        result = await db.execute(
            select(XPEvent).where(
                XPEvent.user_id == user_id,
                XPEvent.idempotency_key == normalized_key,
            )
        )
        existing = result.scalars().first()
        if existing:
            return AwardOutcome(
                stats=current_stats, awarded=False, reason="idempotent_replay"
            )

    if normalized_source_type and normalized_source_id:
        result = await db.execute(
            select(XPEvent).where(
                XPEvent.user_id == user_id,
                XPEvent.source_type == normalized_source_type,
                XPEvent.source_id == normalized_source_id,
            )
        )
        natural_existing = result.scalars().first()
        if natural_existing:
            return AwardOutcome(
                stats=current_stats, awarded=False, reason="idempotent_replay"
            )

    now = datetime.now(timezone.utc)
    original_total = int(summary.total_xp or 0)
    original_level = summary.level
    original_updated_at = summary.updated_at
    original_last_event_at = summary.last_event_at

    normalized_reason = _normalize(reason)
    event = XPEvent(
        user_id=user_id,
        amount=amount,
        reason=normalized_reason,
        idempotency_key=normalized_key,
        source_type=normalized_source_type,
        source_id=normalized_source_id,
        created_at=now,
    )
    db.add(event)

    summary.total_xp = original_total + amount
    stats = compute_level_stats(summary.total_xp)
    summary.level = stats.level
    summary.updated_at = now
    summary.last_event_at = now

    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        summary.total_xp = original_total
        summary.level = original_level
        summary.updated_at = original_updated_at
        summary.last_event_at = original_last_event_at
        rollback_stats = compute_level_stats(original_total)
        return AwardOutcome(
            stats=rollback_stats,
            awarded=False,
            reason="idempotent_replay",
        )

    return AwardOutcome(stats=stats, awarded=True, reason="created")
