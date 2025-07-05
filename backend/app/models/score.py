# backend/app/models/score.py

from sqlalchemy import Column, Integer, Float, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base
from sqlalchemy.dialects.postgresql import UUID
import uuid

class Score(Base):
    __tablename__ = "scores"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    scenario_id = Column(UUID(as_uuid=True), ForeignKey("scenarios.id"), nullable=False)
    weight_lifted = Column(Float, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="scores")
    scenario = relationship("Scenario", back_populates="scores")
