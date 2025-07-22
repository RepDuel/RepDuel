"""Add id PK to routine_scenario_submission

Revision ID: bab751eef8a4
Revises: de3f25366c68
Create Date: 2025-07-21 11:19:48.883488
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "bab751eef8a4"
down_revision: Union[str, Sequence[str], None] = "de3f25366c68"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Drop existing primary key constraint
    op.drop_constraint(
        "routine_scenario_submission_pkey",
        "routine_scenario_submission",
        type_="primary",
    )

    # Add a new 'id' column
    op.add_column(
        "routine_scenario_submission", sa.Column("id", sa.UUID(), nullable=False)
    )

    # Create a new primary key on 'id'
    op.create_primary_key(
        "routine_scenario_submission_pkey", "routine_scenario_submission", ["id"]
    )


def downgrade() -> None:
    """Downgrade schema."""
    # Drop the new primary key
    op.drop_constraint(
        "routine_scenario_submission_pkey",
        "routine_scenario_submission",
        type_="primary",
    )

    # Drop the 'id' column
    op.drop_column("routine_scenario_submission", "id")

    # Restore the original composite primary key
    op.create_primary_key(
        "routine_scenario_submission_pkey",
        "routine_scenario_submission",
        ["routine_id", "scenario_id"],
    )
