# backend/app/models/associations.py

from sqlalchemy import Column, String, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base_class import Base

class ScenarioMuscleAssociation(Base):
    __tablename__ = 'scenario_muscle_association'

    scenario_id = Column(String, ForeignKey('scenarios.id'), primary_key=True)
    muscle_id = Column(String, ForeignKey('muscles.id'), primary_key=True)
    muscle_type = Column(String, nullable=False)  # 'primary' or 'secondary'

    scenario = relationship("Scenario", back_populates="muscles")
    muscle = relationship("Muscle", back_populates="scenarios")
