# backend/app/models/routine.py

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, String, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.base_class import Base


class Routine(Base):
    __tablename__ = "routines"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
        index=True,
    )
    name = Column(String, nullable=False)
    image_url = Column(String, nullable=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
    )

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        default=lambda: datetime.now(timezone.utc),
    )

    scenarios = relationship(
        "RoutineScenario", back_populates="routine", cascade="all, delete-orphan"
    )
    submissions = relationship(
        "RoutineSubmission", back_populates="routine", cascade="all, delete-orphan"
    )
