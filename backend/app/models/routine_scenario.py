# backend/app/models/routine_scenario.py

from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base_class import Base


class RoutineScenario(Base):
    __tablename__ = "routine_scenario_association"

    routine_id = Column(UUID(as_uuid=True), ForeignKey("routines.id"), primary_key=True)
    scenario_id = Column(String, ForeignKey("scenarios.id"), primary_key=True)
    sets = Column(Integer, nullable=False, default=3)
    reps = Column(Integer, nullable=False, default=10)

    # Relationships
    routine = relationship("Routine", back_populates="scenarios")
    scenario = relationship("Scenario")
