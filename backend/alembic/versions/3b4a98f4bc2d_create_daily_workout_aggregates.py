"""Create daily workout aggregates table"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "3b4a98f4bc2d"
down_revision: Union[str, Sequence[str], None] = "d0b6d0f4a3b7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "daily_workout_aggregates",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("day", sa.DateTime(timezone=True), nullable=False),
        sa.Column("longest_session_minutes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("qualified_30", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("timezone('utc', now())"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("timezone('utc', now())"),
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id", "day", name="pk_daily_workout_aggregates"),
    )


def downgrade() -> None:
    op.drop_table("daily_workout_aggregates")
