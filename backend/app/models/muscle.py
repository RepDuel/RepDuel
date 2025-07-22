# backend/app/models/muscle.py

from sqlalchemy import Column, String
from sqlalchemy.orm import relationship
from app.db.base_class import Base
from app.models.associations import ScenarioMuscleAssociation

class Muscle(Base):
    __tablename__ = "muscles"

    id = Column(String, primary_key=True, index=True, unique=True)
    name = Column(String, index=True, nullable=False)

    # Define the relationship to Scenario through the association table for primary muscles
    primary_scenarios = relationship(
        "Scenario",
        secondary=ScenarioMuscleAssociation.__table__,
        back_populates="primary_muscles",
        primaryjoin="and_(ScenarioMuscleAssociation.c.muscle_id == Muscle.id, ScenarioMuscleAssociation.c.muscle_type == 'primary')",
    )

    # Define the relationship to Scenario through the association table for secondary muscles
    secondary_scenarios = relationship(
        "Scenario",
        secondary=ScenarioMuscleAssociation.__table__,
        back_populates="secondary_muscles",
        primaryjoin="and_(ScenarioMuscleAssociation.c.muscle_id == Muscle.id, ScenarioMuscleAssociation.c.muscle_type == 'secondary')",
    )
