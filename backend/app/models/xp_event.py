# backend/app/models/xp_event.py

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base_class import Base


class XPEvent(Base):
    __tablename__ = "xp_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    amount = Column(Integer, nullable=False)
    reason = Column(String(255), nullable=True)
    idempotency_key = Column(String(255), nullable=True)
    source_type = Column(String(64), nullable=True)
    source_id = Column(String(255), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    user = relationship("User", back_populates="xp_events")

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "idempotency_key",
            name="uq_xp_events_user_idempotency",
        ),
        UniqueConstraint(
            "user_id",
            "source_type",
            "source_id",
            name="uq_xp_events_user_source",
        ),
    )
