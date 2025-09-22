"""add personal best events table

Revision ID: 1c2ef3b5a4c7
Revises: 2025_09_20_social_graph_mvp
Create Date: 2025-10-08 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "1c2ef3b5a4c7"
down_revision: Union[str, Sequence[str], None] = "2025_09_20_social_graph_mvp"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "personal_best_events",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("scenario_id", sa.String(), nullable=False),
        sa.Column("score_value", sa.Float(), nullable=False),
        sa.Column("weight_lifted", sa.Float(), nullable=False),
        sa.Column("reps", sa.Integer(), nullable=True),
        sa.Column(
            "is_bodyweight",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["scenario_id"], ["scenarios.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_personal_best_events_user_created_at",
        "personal_best_events",
        ["user_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_personal_best_events_user_created_at",
        table_name="personal_best_events",
    )
    op.drop_table("personal_best_events")
