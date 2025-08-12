# backend/app/models/user.py

import uuid
from datetime import datetime, timezone

from app.db.base_class import Base
from sqlalchemy import Boolean, Column, DateTime, Float, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(32), unique=True, nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(128), nullable=False)
    avatar_url = Column(String, nullable=True)
    weight = Column(Float, nullable=True)
    gender = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    energy = Column(Float, nullable=True)
    display_name = Column(String(255), nullable=True)
    subscription_level = Column(
        String(32),
        nullable=False,
        default="free",
        server_default="free",
    )
    stripe_customer_id = Column(String, unique=True, index=True, nullable=True)
    stripe_subscription_id = Column(String, unique=True, nullable=True)
    apple_original_transaction_id = Column(String, unique=True, index=True, nullable=True)
    
    guilds = relationship("Guild", back_populates="owner", cascade="all, delete-orphan")

    messages = relationship(
        "Message", back_populates="author", cascade="all, delete-orphan"
    )

    scores = relationship(
        "Score", back_populates="user", cascade="all, delete-orphan"
    )

    energy_history = relationship(
        "EnergyHistory", back_populates="user", cascade="all, delete-orphan"
    )
    
    routine_submissions = relationship(
        "RoutineSubmission", back_populates="user", cascade="all, delete-orphan"
    )

    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    weight_multiplier = Column(Float, default=1.0)