# backend/app/models/routine_submission.py

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base_class import Base


class RoutineScenarioSubmission(Base):
    __tablename__ = "routine_scenario_submission"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)

    routine_id = Column(
        UUID(as_uuid=True),
        ForeignKey("routine_submission.id", ondelete="CASCADE"),
        nullable=False,
    )

    scenario_id = Column(String, ForeignKey("scenarios.id"), nullable=False)
    sets = Column(Integer, nullable=False, default=3)
    reps = Column(Integer, nullable=False, default=10)
    weight = Column(Float, nullable=False)
    total_volume = Column(Float, nullable=False)

    routine_submission = relationship(
        "RoutineSubmission",
        back_populates="scenario_submissions",
    )
    scenario = relationship("Scenario")


class RoutineSubmission(Base):
    __tablename__ = "routine_submission"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    routine_id = Column(UUID(as_uuid=True), ForeignKey("routines.id"), nullable=True)

    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    duration = Column(Float, nullable=False)
    completion_timestamp = Column(DateTime, nullable=False, default=datetime.utcnow)
    status = Column(String, nullable=False)
    title = Column(String, nullable=False)

    scenario_submissions = relationship(
        "RoutineScenarioSubmission",
        back_populates="routine_submission",
        cascade="all, delete-orphan",
        single_parent=True,
        passive_deletes=True,
    )

    routine = relationship("Routine", back_populates="submissions")
    user = relationship("User", back_populates="routine_submissions")
