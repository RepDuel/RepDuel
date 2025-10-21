"""add leaderboard indexes

Revision ID: 1f2d6f1f48cf
Revises: 27dcd007108a
Create Date: 2024-04-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "1f2d6f1f48cf"
down_revision: Union[str, Sequence[str], None] = "27dcd007108a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add indexes to support leaderboard pagination."""

    op.create_index(
        "ix_users_active_energy_updated",
        "users",
        ["energy", "updated_at"],
        unique=False,
        postgresql_where=sa.text("is_active = true"),
    )
    op.create_index(
        "ix_scores_scenario_score_created",
        "scores",
        [
            "scenario_id",
            sa.text("score_value DESC"),
            sa.text("created_at DESC"),
            sa.text("id DESC"),
        ],
        unique=False,
    )


def downgrade() -> None:
    """Remove leaderboard indexes."""

    op.drop_index("ix_scores_scenario_score_created", table_name="scores")
    op.drop_index("ix_users_active_energy_updated", table_name="users")
