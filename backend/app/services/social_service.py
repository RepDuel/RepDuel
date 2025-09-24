# backend/app/services/social_service.py

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Sequence
from uuid import UUID

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.social import SocialEdge
from app.models.user import User

ACTIVE_STATUS = "active"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


async def _with_relationship_flags(
    db: AsyncSession, users: Sequence[User], viewer_id: UUID | None
) -> list[dict[str, Any]]:
    if not users:
        return []

    target_ids = [user.id for user in users]
    following_ids: set[UUID] = set()
    followed_by_ids: set[UUID] = set()

    if viewer_id and target_ids:
        following_stmt = (
            select(SocialEdge.followee_id)
            .where(
                SocialEdge.follower_id == viewer_id,
                SocialEdge.followee_id.in_(target_ids),
                SocialEdge.status == ACTIVE_STATUS,
            )
        )
        following_result = await db.execute(following_stmt)
        following_ids = set(following_result.scalars().all())

        followed_stmt = (
            select(SocialEdge.follower_id)
            .where(
                SocialEdge.followee_id == viewer_id,
                SocialEdge.follower_id.in_(target_ids),
                SocialEdge.status == ACTIVE_STATUS,
            )
        )
        followed_result = await db.execute(followed_stmt)
        followed_by_ids = set(followed_result.scalars().all())

    return [
        {
            "id": user.id,
            "username": user.username,
            "display_name": user.display_name,
            "avatar_url": user.avatar_url,
            "is_following": user.id in following_ids,
            "is_followed_by": user.id in followed_by_ids,
            "is_self": bool(viewer_id and user.id == viewer_id),
        }
        for user in users
    ]


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
    db: AsyncSession,
    user_id: UUID,
    viewer_id: UUID | None,
    offset: int,
    limit: int,
) -> tuple[list[dict[str, Any]], int]:
    """Return the active followers for ``user_id``."""
    stmt = (
        select(User)
        .join(SocialEdge, SocialEdge.follower_id == User.id)
        .where(
            SocialEdge.followee_id == user_id,
            SocialEdge.status == ACTIVE_STATUS,
            User.is_active.is_(True),
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
    annotated = await _with_relationship_flags(db, users, viewer_id)
    return annotated, int(total or 0)


async def get_following(
    db: AsyncSession,
    user_id: UUID,
    viewer_id: UUID | None,
    offset: int,
    limit: int,
) -> tuple[list[dict[str, Any]], int]:
    """Return the active followees for ``user_id``."""
    stmt = (
        select(User)
        .join(SocialEdge, SocialEdge.followee_id == User.id)
        .where(
            SocialEdge.follower_id == user_id,
            SocialEdge.status == ACTIVE_STATUS,
            User.is_active.is_(True),
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
    annotated = await _with_relationship_flags(db, users, viewer_id)
    return annotated, int(total or 0)


async def get_mutuals(
    db: AsyncSession,
    user_id: UUID,
    viewer_id: UUID | None,
    offset: int,
    limit: int,
) -> tuple[list[dict[str, Any]], int]:
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
            User.is_active.is_(True),
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
    annotated = await _with_relationship_flags(db, users, viewer_id)
    return annotated, int(total or 0)


async def search_users(
    db: AsyncSession,
    viewer_id: UUID,
    query: str,
    offset: int,
    limit: int,
) -> tuple[list[dict[str, Any]], int]:
    """Search active users by username or display name."""

    trimmed = query.strip()
    if not trimmed:
        return [], 0

    pattern = f"%{trimmed.lower()}%"
    username_match = func.lower(User.username).like(pattern)
    display_match = func.lower(func.coalesce(User.display_name, "")).like(pattern)

    base_filters = [User.is_active.is_(True), or_(username_match, display_match)]

    stmt = (
        select(User)
        .where(*base_filters)
        .order_by(func.lower(User.username))
        .offset(offset)
        .limit(limit)
    )
    count_stmt = select(func.count()).select_from(User).where(*base_filters)

    if viewer_id:
        stmt = stmt.where(User.id != viewer_id)
        count_stmt = count_stmt.where(User.id != viewer_id)

    result = await db.execute(stmt)
    users = result.scalars().all()
    total = await db.scalar(count_stmt)
    annotated = await _with_relationship_flags(db, users, viewer_id)
    return annotated, int(total or 0)


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
