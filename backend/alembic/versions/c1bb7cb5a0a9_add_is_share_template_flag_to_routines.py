"""add is_share_template flag to routines

Revision ID: c1bb7cb5a0a9
Revises: b3f2b9d5c6a4
Create Date: 2025-10-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision: str = "c1bb7cb5a0a9"
down_revision: Union[str, Sequence[str], None] = "b3f2b9d5c6a4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("routines")}

    if "is_share_template" not in columns:
        op.add_column(
            "routines",
            sa.Column(
                "is_share_template",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            ),
        )
    else:
        op.execute(
            sa.text(
                "ALTER TABLE routines ALTER COLUMN is_share_template SET DEFAULT false"
            )
        )

    op.execute(
        sa.text(
            "UPDATE routines SET is_share_template = false WHERE is_share_template IS NULL"
        )
    )

    op.alter_column(
        "routines",
        "is_share_template",
        existing_type=sa.Boolean(),
        nullable=False,
        server_default=sa.false(),
    )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    columns = {column["name"] for column in inspector.get_columns("routines")}

    if "is_share_template" in columns:
        op.drop_column("routines", "is_share_template")
