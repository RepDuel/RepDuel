# backend/app/models/routine.py

from sqlalchemy import Column, String, ForeignKey, Table, DateTime, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.base_class import Base

routine_scenario_association = Table(
    "routine_scenario_association",
    Base.metadata,
    Column("routine_id", UUID(as_uuid=True), ForeignKey("routines.id")),
    Column("scenario_id", UUID(as_uuid=True), ForeignKey("scenarios.id")),
)

class Routine(Base):
    __tablename__ = "routines"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"), index=True)
    name = Column(String, nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, server_default=text("now()"))

    scenarios = relationship(
        "Scenario",
        secondary=routine_scenario_association,
        back_populates="routines"
    )
