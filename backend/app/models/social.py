# backend/app/models/social.py

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Index, String, text
from sqlalchemy.dialects.postgresql import UUID

from app.db.base_class import Base


class SocialEdge(Base):
    __tablename__ = "social_edges"

    follower_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    followee_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    status = Column(
        String,
        nullable=False,
        default="active",
        server_default="active",
    )
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=text("now()"),
        nullable=False,
    )

    __table_args__ = (
        Index(
            "idx_social_following_active",
            "follower_id",
            postgresql_where=text("status = 'active'"),
        ),
        Index(
            "idx_social_followers_active",
            "followee_id",
            postgresql_where=text("status = 'active'"),
        ),
    )
