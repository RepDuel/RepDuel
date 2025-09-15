# backend/app/models/hidden_routine.py

from sqlalchemy import Column, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID

from app.db.base_class import Base


class HiddenRoutine(Base):
    __tablename__ = "hidden_routines"

    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    routine_id = Column(UUID(as_uuid=True), ForeignKey("routines.id", ondelete="CASCADE"), primary_key=True)

    __table_args__ = (
        UniqueConstraint("user_id", "routine_id", name="uq_hidden_user_routine"),
    )

