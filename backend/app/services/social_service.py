# backend/app/services/social_service.py

from __future__ import annotations

from datetime import datetime, timezone
from typing import Sequence
from uuid import UUID

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.social import SocialEdge
from app.models.user import User

ACTIVE_STATUS = "active"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


async def follow(db: AsyncSession, me_id: UUID, target_id: UUID) -> None:
    """Create (or reactivate) a follow edge from ``me_id`` to ``target_id``."""
    result = await db.execute(
        select(SocialEdge).where(
            SocialEdge.follower_id == me_id,
            SocialEdge.followee_id == target_id,
        )
    )
    edge = result.scalars().first()
    if edge:
        if edge.status != ACTIVE_STATUS:
            edge.status = ACTIVE_STATUS
            edge.created_at = _utcnow()
    else:
        db.add(
            SocialEdge(
                follower_id=me_id,
                followee_id=target_id,
                status=ACTIVE_STATUS,
                created_at=_utcnow(),
            )
        )
    await db.commit()


async def unfollow(db: AsyncSession, me_id: UUID, target_id: UUID) -> None:
    """Remove the follow edge from ``me_id`` to ``target_id`` if present."""
    result = await db.execute(
        select(SocialEdge).where(
            SocialEdge.follower_id == me_id,
            SocialEdge.followee_id == target_id,
        )
    )
    edge = result.scalars().first()
    if edge:
        await db.delete(edge)
    await db.commit()


async def get_followers(
    db: AsyncSession, user_id: UUID, offset: int, limit: int
) -> tuple[Sequence[User], int]:
    """Return the active followers for ``user_id``."""
    stmt = (
        select(User)
        .join(SocialEdge, SocialEdge.follower_id == User.id)
        .where(
            SocialEdge.followee_id == user_id,
            SocialEdge.status == ACTIVE_STATUS,
        )
        .order_by(SocialEdge.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(stmt)
    users = result.scalars().all()

    count_stmt = (
        select(func.count())
        .select_from(SocialEdge)
        .where(
            SocialEdge.followee_id == user_id,
            SocialEdge.status == ACTIVE_STATUS,
        )
    )
    total = await db.scalar(count_stmt)
    return users, int(total or 0)


async def get_following(
    db: AsyncSession, user_id: UUID, offset: int, limit: int
) -> tuple[Sequence[User], int]:
    """Return the active followees for ``user_id``."""
    stmt = (
        select(User)
        .join(SocialEdge, SocialEdge.followee_id == User.id)
        .where(
            SocialEdge.follower_id == user_id,
            SocialEdge.status == ACTIVE_STATUS,
        )
        .order_by(SocialEdge.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(stmt)
    users = result.scalars().all()

    count_stmt = (
        select(func.count())
        .select_from(SocialEdge)
        .where(
            SocialEdge.follower_id == user_id,
            SocialEdge.status == ACTIVE_STATUS,
        )
    )
    total = await db.scalar(count_stmt)
    return users, int(total or 0)


async def get_mutuals(
    db: AsyncSession, user_id: UUID, offset: int, limit: int
) -> tuple[Sequence[User], int]:
    """Return the users that share mutual follows with ``user_id``."""
    forward_edges = aliased(SocialEdge)
    reverse_edges = aliased(SocialEdge)

    stmt = (
        select(User)
        .join(forward_edges, forward_edges.followee_id == User.id)
        .join(
            reverse_edges,
            and_(
                forward_edges.followee_id == reverse_edges.follower_id,
                forward_edges.follower_id == reverse_edges.followee_id,
            ),
        )
        .where(
            forward_edges.follower_id == user_id,
            forward_edges.status == ACTIVE_STATUS,
            reverse_edges.status == ACTIVE_STATUS,
        )
        .order_by(forward_edges.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(stmt)
    users = result.scalars().all()

    count_forward = aliased(SocialEdge)
    count_reverse = aliased(SocialEdge)
    count_stmt = (
        select(func.count())
        .select_from(count_forward)
        .join(
            count_reverse,
            and_(
                count_forward.followee_id == count_reverse.follower_id,
                count_forward.follower_id == count_reverse.followee_id,
            ),
        )
        .where(
            count_forward.follower_id == user_id,
            count_forward.status == ACTIVE_STATUS,
            count_reverse.status == ACTIVE_STATUS,
        )
    )
    total = await db.scalar(count_stmt)
    return users, int(total or 0)


async def is_following(db: AsyncSession, follower_id: UUID, followee_id: UUID) -> bool:
    """Return True if ``follower_id`` currently follows ``followee_id``."""
    stmt = (
        select(func.count())
        .select_from(SocialEdge)
        .where(
            SocialEdge.follower_id == follower_id,
            SocialEdge.followee_id == followee_id,
            SocialEdge.status == ACTIVE_STATUS,
        )
    )
    total = await db.scalar(stmt)
    return bool(total and total > 0)
