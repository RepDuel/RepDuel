# backend/app/models/equipment.py

from sqlalchemy import Column, String
from sqlalchemy.orm import relationship
from app.db.base_class import Base
from app.models.associations import ScenarioEquipmentAssociation

class Equipment(Base):
    __tablename__ = "equipment"

    id = Column(String, primary_key=True, index=True, unique=True)
    name = Column(String, index=True, nullable=False)

    # Define the relationship to Scenario through the association table
    scenarios = relationship(
        "Scenario",
        secondary=ScenarioEquipmentAssociation.__table__,
        back_populates="equipment",
    )
