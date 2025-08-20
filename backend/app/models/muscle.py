# backend/app/models/muscle.py

from sqlalchemy import Column, String
from sqlalchemy.orm import relationship

from app.db.base_class import Base
from app.models.associations import (ScenarioPrimaryMuscleAssociation,
                                     ScenarioSecondaryMuscleAssociation)


class Muscle(Base):
    __tablename__ = "muscles"

    id = Column(String, primary_key=True, index=True, unique=True)
    name = Column(String, index=True, nullable=False)

    primary_scenarios = relationship(
        "Scenario",
        secondary=ScenarioPrimaryMuscleAssociation.__table__,
        back_populates="primary_muscles",
    )

    secondary_scenarios = relationship(
        "Scenario",
        secondary=ScenarioSecondaryMuscleAssociation.__table__,
        back_populates="secondary_muscles",
    )
