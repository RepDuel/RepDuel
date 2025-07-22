# backend/app/models/scenario.py

from sqlalchemy import Column, String
from sqlalchemy.orm import relationship
from app.db.base_class import Base
from app.models.muscle import Muscle
from app.models.associations import ScenarioMuscleAssociation

class Scenario(Base):
    __tablename__ = "scenarios"

    id = Column(String, primary_key=True, unique=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    description = Column(String, nullable=True)

    # Many-to-many relationship with Muscle for primary muscles
    primary_muscles = relationship(
        "Muscle",
        secondary=ScenarioMuscleAssociation.__table__,
        back_populates="primary_scenarios",
        primaryjoin="and_(ScenarioMuscleAssociation.c.scenario_id == Scenario.id, ScenarioMuscleAssociation.c.muscle_type == 'primary')",
    )

    # Many-to-many relationship with Muscle for secondary muscles
    secondary_muscles = relationship(
        "Muscle",
        secondary=ScenarioMuscleAssociation.__table__,
        back_populates="secondary_scenarios",
        primaryjoin="and_(ScenarioMuscleAssociation.c.scenario_id == Scenario.id, ScenarioMuscleAssociation.c.muscle_type == 'secondary')",
    )
