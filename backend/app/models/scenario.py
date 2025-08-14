# backend/app/models/scenario.py

from app.db.base_class import Base
from app.models.associations import (ScenarioEquipmentAssociation,
                                     ScenarioPrimaryMuscleAssociation,
                                     ScenarioSecondaryMuscleAssociation)
from app.models.equipment import Equipment
from app.models.muscle import Muscle
from sqlalchemy import Boolean, Column, Float, String
from sqlalchemy.orm import relationship


class Scenario(Base):
    __tablename__ = "scenarios"

    id = Column(String, primary_key=True, unique=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    description = Column(String, nullable=True)

    # This will now be used as the RANK multiplier.
    multiplier = Column(Float, nullable=False, default=1.0, server_default='1.0')

    # This new column is dedicated to calculating physical volume.
    volume_multiplier = Column(Float, nullable=False, default=1.0, server_default='1.0')

    is_bodyweight = Column(Boolean, nullable=False, default=False, server_default='false')

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