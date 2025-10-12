"""add rate limit events table

Revision ID: 20250212_add_rate_limit_events
Revises: de3f25366c68
Create Date: 2025-02-12 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20250212_add_rate_limit_events"
down_revision: str = "de3f25366c68"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "rate_limit_events",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.dialects.postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("action", sa.String(length=64), nullable=False),
        sa.Column(
            "occurred_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_rate_limit_events_user_action_time",
        "rate_limit_events",
        ["user_id", "action", "occurred_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_rate_limit_events_user_action_time", table_name="rate_limit_events")
    op.drop_table("rate_limit_events")
