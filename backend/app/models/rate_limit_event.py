# backend/app/models/rate_limit_event.py

from datetime import datetime, timezone
from sqlalchemy import Column, DateTime, Index, Integer, String
from sqlalchemy.dialects.postgresql import UUID as PGUUID

from app.db.base_class import Base


class RateLimitEvent(Base):
    __tablename__ = "rate_limit_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(PGUUID(as_uuid=True), nullable=False, index=True)
    action = Column(String(64), nullable=False)
    occurred_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    __table_args__ = (
        Index(
            "ix_rate_limit_events_user_action_time",
            "user_id",
            "action",
            "occurred_at",
        ),
    )
