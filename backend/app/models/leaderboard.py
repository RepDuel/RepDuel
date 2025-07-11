# backend/app/models/leaderboard.py

from app.db.base_class import Base
from sqlalchemy import Column, Float, ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID


class LeaderboardEntry(Base):
    __tablename__ = "leaderboard_entries"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
        index=True,
    )
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    scenario_id = Column(UUID(as_uuid=True), ForeignKey("scenarios.id"), nullable=False)
    weight_lifted = Column(Float, nullable=False)
