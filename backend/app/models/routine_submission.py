from sqlalchemy import Column, ForeignKey, Integer, String, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.base_class import Base
from uuid import UUID as UUIDType

# Model to represent the data for each routine scenario when submitting a routine
class RoutineScenarioSubmission(Base):
    __tablename__ = "routine_scenario_submission"

    routine_id = Column(UUID(as_uuid=True), ForeignKey("routines.id"), primary_key=True)
    scenario_id = Column(String, ForeignKey("scenarios.id"), primary_key=True)
    sets = Column(Integer, nullable=False, default=3)
    reps = Column(Integer, nullable=False, default=10)
    weight = Column(Float, nullable=False)  # Weight lifted in kg
    total_volume = Column(Float, nullable=False)  # Total volume (weight * reps * sets)

    # Relationships
    routine = relationship("Routine", back_populates="scenarios")
    scenario = relationship("Scenario")

# Model to represent the complete routine submission
class RoutineSubmission(Base):
    __tablename__ = "routine_submission"

    routine_id = Column(UUID(as_uuid=True), ForeignKey("routines.id"), primary_key=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    scenarios = relationship("RoutineScenarioSubmission", back_populates="routine_submission", cascade="all, delete-orphan")

    # Relationships
    routine = relationship("Routine", back_populates="submissions")
    user = relationship("User", back_populates="routine_submissions")
