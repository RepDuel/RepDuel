# backend/app/models/scenario.py

from app.db.base_class import Base
from app.models.associations import (ScenarioEquipmentAssociation,
                                     ScenarioPrimaryMuscleAssociation,
                                     ScenarioSecondaryMuscleAssociation)
from app.models.equipment import Equipment
from app.models.muscle import Muscle
from sqlalchemy import Column, Float, String
from sqlalchemy.orm import relationship


class Scenario(Base):
    __tablename__ = "scenarios"

    id = Column(String, primary_key=True, unique=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    description = Column(String, nullable=True)
    multiplier = Column(Float, nullable=True)
    scores = relationship("Score", back_populates="scenario")

    primary_muscles = relationship(
        "Muscle",
        secondary=ScenarioPrimaryMuscleAssociation.__table__,
        back_populates="primary_scenarios",
    )

    secondary_muscles = relationship(
        "Muscle",
        secondary=ScenarioSecondaryMuscleAssociation.__table__,
        back_populates="secondary_scenarios",
    )

    equipment = relationship(
        "Equipment",
        secondary=ScenarioEquipmentAssociation.__table__,
        back_populates="scenarios",
    )
