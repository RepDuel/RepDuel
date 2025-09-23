"""Aggregate stats for user workouts per day."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, PrimaryKeyConstraint
from sqlalchemy.dialects.postgresql import UUID

from app.db.base_class import Base


class DailyWorkoutAggregate(Base):
    __tablename__ = "daily_workout_aggregates"

    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    day = Column(DateTime(timezone=True), nullable=False)
    longest_session_minutes = Column(Integer, nullable=False, default=0)
    qualified_30 = Column(Boolean, nullable=False, default=False)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    __table_args__ = (
        PrimaryKeyConstraint("user_id", "day", name="pk_daily_workout_aggregates"),
    )
