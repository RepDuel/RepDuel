# backend/app/models/user.py

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, String, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base_class import Base


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(32), unique=True, nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(128), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    avatar_url = Column(String, nullable=True)

    weight = Column(Float, nullable=True)  # Weight field
    gender = Column(String, nullable=True)  # Gender field

    guilds = relationship("Guild", back_populates="owner", cascade="all, delete-orphan")

    messages = relationship("Message", back_populates="author", cascade="all, delete-orphan")

    scores = relationship("Score", back_populates="user")
