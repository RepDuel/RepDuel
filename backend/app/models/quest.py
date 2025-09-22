# backend/app/models/quest.py

"""Quest-related SQLAlchemy models."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from enum import Enum

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base_class import Base


class QuestCadence(str, Enum):
    DAILY = "daily"
    WEEKLY = "weekly"
    LIMITED = "limited"


class QuestMetric(str, Enum):
    WORKOUTS_COMPLETED = "workouts_completed"
    ACTIVE_MINUTES = "active_minutes"


class QuestStatus(str, Enum):
    ACTIVE = "active"
    COMPLETED = "completed"
    CLAIMED = "claimed"
    EXPIRED = "expired"


class QuestTemplate(Base):
    __tablename__ = "quest_templates"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(String(64), nullable=False, unique=True, index=True)
    title = Column(String(120), nullable=False)
    description = Column(String(255), nullable=True)
    cadence = Column(String(16), nullable=False, default=QuestCadence.DAILY.value)
    metric = Column(String(32), nullable=False)
    target_value = Column(Integer, nullable=False, default=1)
    reward_xp = Column(Integer, nullable=False)
    auto_claim = Column(Boolean, nullable=False, default=True)
    is_active = Column(Boolean, nullable=False, default=True)
    available_from = Column(
        DateTime(timezone=True),
        nullable=True,
        default=lambda: datetime.now(timezone.utc),
    )
    expires_at = Column(DateTime(timezone=True), nullable=True)
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

    instances = relationship(
        "UserQuest",
        back_populates="template",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        CheckConstraint(
            "cadence IN ('daily', 'weekly', 'limited')",
            name="ck_quest_templates_cadence",
        ),
        CheckConstraint(
            "metric IN ('workouts_completed', 'active_minutes')",
            name="ck_quest_templates_metric",
        ),
        CheckConstraint(
            "target_value > 0",
            name="ck_quest_templates_target_positive",
        ),
        CheckConstraint(
            "reward_xp > 0",
            name="ck_quest_templates_reward_positive",
        ),
    )


class UserQuest(Base):
    __tablename__ = "user_quests"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    template_id = Column(
        UUID(as_uuid=True),
        ForeignKey("quest_templates.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status = Column(String(16), nullable=False, default=QuestStatus.ACTIVE.value)
    progress_value = Column(Integer, nullable=False, default=0)
    required_value = Column(Integer, nullable=False)
    cycle_start = Column(DateTime(timezone=True), nullable=False)
    cycle_end = Column(DateTime(timezone=True), nullable=True)
    available_from = Column(DateTime(timezone=True), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    reward_claimed_at = Column(DateTime(timezone=True), nullable=True)
    last_progress_at = Column(DateTime(timezone=True), nullable=True)
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

    template = relationship("QuestTemplate", back_populates="instances")
    user = relationship("User", back_populates="quests")

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "template_id",
            "cycle_start",
            name="uq_user_quests_cycle",
        ),
        CheckConstraint(
            "status IN ('active', 'completed', 'claimed', 'expired')",
            name="ck_user_quests_status",
        ),
        CheckConstraint(
            "progress_value >= 0",
            name="ck_user_quests_progress_nonnegative",
        ),
        CheckConstraint(
            "required_value >= 0",
            name="ck_user_quests_required_nonnegative",
        ),
    )
