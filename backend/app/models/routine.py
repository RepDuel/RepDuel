# backend/app/models/routine.py

from sqlalchemy import Column, String, ForeignKey, Table, DateTime, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.base_class import Base

class Routine(Base):
    __tablename__ = "routines"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"), index=True)
    name = Column(String, nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)  # Now nullable
    created_at = Column(DateTime, server_default=text("now()"))

    scenarios = relationship("RoutineScenario", back_populates="routine", cascade="all, delete-orphan")
