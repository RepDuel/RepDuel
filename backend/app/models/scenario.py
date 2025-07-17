# backend/app/models/scenario.py

from app.db.base_class import Base
from sqlalchemy import Column, String
from sqlalchemy.orm import relationship

def generate_scenario_id(name: str):
    """Generate a scenario ID based on the name, lowercase with spaces replaced by underscores."""
    return name.lower().replace(" ", "_")

class Scenario(Base):
    __tablename__ = "scenarios"

    id = Column(
        String,
        primary_key=True,
        default=lambda context: generate_scenario_id(context.get_current_parameters()['name']),
        unique=True,
        index=True,
    )
    name = Column(String, unique=True, index=True, nullable=False)
    description = Column(String, nullable=True)
    scores = relationship("Score", back_populates="scenario")

