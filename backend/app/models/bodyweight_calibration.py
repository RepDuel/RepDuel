# backend/app/models/bodyweight_calibration.py

from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.db.base_class import Base


class BodyweightCalibration(Base):
    __tablename__ = "bodyweight_calibrations"

    # scenario_id is both the PK and FK to scenarios.id
    scenario_id = Column(
        String,
        ForeignKey("scenarios.id", ondelete="CASCADE"),
        primary_key=True,
        index=True,
    )

    beginner_50 = Column(Integer, nullable=False)
    elite_50 = Column(Integer, nullable=False)
    beginner_140 = Column(Integer, nullable=False)
    elite_140 = Column(Integer, nullable=False)
    intermediate_95 = Column(Integer, nullable=False)

    # one-to-one backref
    scenario = relationship(
        "Scenario",
        back_populates="calibration",
        uselist=False,
    )
