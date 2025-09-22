"""make routine_submission.routine_id nullable

Revision ID: b1d55d7f43ce
Revises: 1c2ef3b5a4c7
Create Date: 2025-10-12 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "b1d55d7f43ce"
down_revision: Union[str, Sequence[str], None] = "1c2ef3b5a4c7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "routine_submission",
        "routine_id",
        existing_type=postgresql.UUID(as_uuid=True),
        nullable=True,
    )


def downgrade() -> None:
    op.execute("DELETE FROM routine_submission WHERE routine_id IS NULL")
    op.alter_column(
        "routine_submission",
        "routine_id",
        existing_type=postgresql.UUID(as_uuid=True),
        nullable=False,
    )
