# backend/app/models/score.py

from datetime import datetime

from app.db.base_class import Base
from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship


class Score(Base):
    __tablename__ = "scores"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    scenario_id = Column(String, ForeignKey("scenarios.id"), nullable=False)
    weight_lifted = Column(Float, nullable=False)
    reps = Column(Integer, nullable=True)
    sets = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    user = relationship("User", back_populates="scores")
    scenario = relationship("Scenario", back_populates="scores")
