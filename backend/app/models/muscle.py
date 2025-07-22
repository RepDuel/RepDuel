from app.db.base_class import Base
from sqlalchemy import Column, String
from sqlalchemy.orm import relationship
from app.models.associations import scenario_muscle_association  # Import association table

class Muscle(Base):
    __tablename__ = "muscles"

    id = Column(String, primary_key=True, index=True, unique=True)
    name = Column(String, index=True, nullable=False)

    scenarios = relationship(
        "Scenario",
        secondary=scenario_muscle_association,
        back_populates="muscles"
    )
