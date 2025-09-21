"""add xp tables

Revision ID: 729800267f89
Revises: 8c7dded74a36
Create Date: 2025-09-21 00:38:55.145546

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


xp_events_table = "xp_events"
user_xp_table = "user_xp"


# revision identifiers, used by Alembic.
revision: str = '729800267f89'
down_revision: Union[str, Sequence[str], None] = '8c7dded74a36'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create XP event and summary tables."""

    op.create_table(
        xp_events_table,
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(length=255), nullable=True),
        sa.Column("idempotency_key", sa.String(length=255), nullable=True),
        sa.Column("source_type", sa.String(length=64), nullable=True),
        sa.Column("source_id", sa.String(length=255), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("timezone('utc', now())"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "idempotency_key",
            name="uq_xp_events_user_idempotency",
        ),
        sa.UniqueConstraint(
            "user_id",
            "source_type",
            "source_id",
            name="uq_xp_events_user_source",
        ),
    )
    op.create_index(
        "ix_xp_events_user_id",
        xp_events_table,
        ["user_id"],
    )

    op.create_table(
        user_xp_table,
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("total_xp", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("level", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("timezone('utc', now())"),
            nullable=False,
        ),
        sa.Column("last_event_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
    )

    op.execute(
        sa.text(
            """
            INSERT INTO user_xp (user_id, total_xp, level, updated_at)
            SELECT id, 0, 1, timezone('utc', now())
            FROM users
            ON CONFLICT (user_id) DO NOTHING
            """
        )
    )


def downgrade() -> None:
    """Drop XP tables."""

    op.drop_table(user_xp_table)
    op.drop_index("ix_xp_events_user_id", table_name=xp_events_table)
    op.drop_table(xp_events_table)
