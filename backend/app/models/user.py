# backend/app/models/user.py

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, Float, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base_class import Base


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    avatar_url = Column(String, nullable=True)
    display_name = Column(String(255), nullable=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    energy = Column(Float, nullable=True)
    gender = Column(String, nullable=True)
    hashed_password = Column(String(128), nullable=False)
    is_active = Column(Boolean, default=True)

    # --- Rank ---
    rank = Column(
        String(50),
        nullable=True,
        default="Unranked",
        server_default="Unranked",
    )

    # --- Subscription ---
    subscription_level = Column(
        String(32),
        nullable=False,
        default="free",
        server_default="free",
    )

    username = Column(String(32), unique=True, nullable=False)
    weight = Column(Float, nullable=True)
    weight_multiplier = Column(Float, default=1.0)

    # --- Timestamps ---
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # --- Payment Columns ---
    original_transaction_id = Column(
        String,
        unique=True,
        index=True,
        nullable=True,
    )
    stripe_customer_id = Column(String, unique=True, index=True, nullable=True)
    stripe_subscription_id = Column(String, unique=True, nullable=True)

    # --- Relationships ---
    energy_history = relationship(
        "EnergyHistory",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    routine_submissions = relationship(
        "RoutineSubmission",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    guilds = relationship(
        "Guild",
        back_populates="owner",
        cascade="all, delete-orphan",
    )
    scores = relationship(
        "Score",
        back_populates="user",
        cascade="all, delete-orphan",
    )
