# backend/app/models/scenario.py

from sqlalchemy import Boolean, Column, Float, String
from sqlalchemy.orm import relationship

from app.db.base_class import Base
from app.models.associations import (ScenarioEquipmentAssociation,
                                     ScenarioPrimaryMuscleAssociation,
                                     ScenarioSecondaryMuscleAssociation)
from app.models.equipment import Equipment
from app.models.muscle import Muscle


class Scenario(Base):
    __tablename__ = "scenarios"

    id = Column(String, primary_key=True, unique=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    description = Column(String, nullable=True)
    is_bodyweight = Column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    # Multiplier for benchmark calculation (e.g. 0.25x for bench press, 0.33x for squats)
    multiplier = Column(Float, nullable=False, default=1.0, server_default="1.0")
    # Multiplier for volume calculation (e.g. 0.7x for pushups or 1.0x for bench press)
    volume_multiplier = Column(Float, nullable=False, default=1.0, server_default="1.0")
    
    equipment = relationship(
        "Equipment",
        secondary=ScenarioEquipmentAssociation.__table__,
        back_populates="scenarios",
    )

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

    scores = relationship("Score", back_populates="scenario")
