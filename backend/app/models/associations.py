# backend/app/models/associations.py

from sqlalchemy import Column, String, ForeignKey
from app.db.base_class import Base

class ScenarioPrimaryMuscleAssociation(Base):
    __tablename__ = 'scenario_primary_muscle_association'
    scenario_id = Column(String, ForeignKey('scenarios.id'), primary_key=True)
    muscle_id = Column(String, ForeignKey('muscles.id'), primary_key=True)

class ScenarioSecondaryMuscleAssociation(Base):
    __tablename__ = 'scenario_secondary_muscle_association'
    scenario_id = Column(String, ForeignKey('scenarios.id'), primary_key=True)
    muscle_id = Column(String, ForeignKey('muscles.id'), primary_key=True)

class ScenarioEquipmentAssociation(Base):
    __tablename__ = 'scenario_equipment_association'
    scenario_id = Column(String, ForeignKey('scenarios.id'), primary_key=True)
    equipment_id = Column(String, ForeignKey('equipment.id'), primary_key=True)