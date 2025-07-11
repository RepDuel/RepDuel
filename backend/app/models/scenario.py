# backend/app/models/scenario.py

from app.db.base_class import Base
from sqlalchemy import Column, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship


class Scenario(Base):
    __tablename__ = "scenarios"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
        index=True,
    )
    name = Column(String, unique=True, index=True, nullable=False)
    description = Column(String, nullable=True)
    scores = relationship("Score", back_populates="scenario")
