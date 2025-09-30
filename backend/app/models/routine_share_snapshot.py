# backend/app/models/routine_share_snapshot.py

from datetime import datetime, timezone
from typing import Any

from sqlalchemy import Column, DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.types import JSON

from app.db.base_class import Base


class RoutineShareSnapshot(Base):
    """Persistent snapshot of a routine that can be imported via a share code."""

    __tablename__ = "routine_share_snapshots"

    code = Column(String(16), primary_key=True, index=True)
    name = Column(String, nullable=False)
    image_url = Column(String, nullable=True)
    scenarios = Column(JSON, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
    )
    source_routine_id = Column(
        UUID(as_uuid=True),
        ForeignKey("routines.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_by_user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    def as_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "name": self.name,
            "image_url": self.image_url,
            "scenarios": self.scenarios,
            "created_at": self.created_at,
            "source_routine_id": self.source_routine_id,
            "created_by_user_id": self.created_by_user_id,
        }
