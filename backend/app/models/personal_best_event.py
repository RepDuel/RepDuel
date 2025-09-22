# backend/app/models/personal_best_event.py

from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base_class import Base


class PersonalBestEvent(Base):
    __tablename__ = "personal_best_events"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    scenario_id = Column(
        String,
        ForeignKey("scenarios.id", ondelete="CASCADE"),
        nullable=False,
    )
    score_value = Column(Float, nullable=False)
    weight_lifted = Column(Float, nullable=False)
    reps = Column(Integer, nullable=True)
    is_bodyweight = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship("User", back_populates="personal_best_events")
    scenario = relationship("Scenario", back_populates="personal_best_events")
