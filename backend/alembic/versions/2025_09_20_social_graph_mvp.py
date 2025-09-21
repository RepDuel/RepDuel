"""Create social_edges table for social graph MVP

Revision ID: 2025_09_20_social_graph_mvp
Revises: 8c7dded74a36
Create Date: 2025-09-20 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2025_09_20_social_graph_mvp"
down_revision: Union[str, Sequence[str], None] = "8c7dded74a36"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema by creating social_edges."""
    op.create_table(
        "social_edges",
        sa.Column("follower_id", sa.dialects.postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("followee_id", sa.dialects.postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "status",
            sa.String(),
            nullable=False,
            server_default="active",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.ForeignKeyConstraint(["follower_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["followee_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("follower_id", "followee_id"),
    )
    op.create_index(
        "idx_social_following_active",
        "social_edges",
        ["follower_id"],
        unique=False,
        postgresql_where=sa.text("status = 'active'"),
    )
    op.create_index(
        "idx_social_followers_active",
        "social_edges",
        ["followee_id"],
        unique=False,
        postgresql_where=sa.text("status = 'active'"),
    )


def downgrade() -> None:
    """Downgrade schema by dropping social_edges."""
    op.drop_index("idx_social_followers_active", table_name="social_edges")
    op.drop_index("idx_social_following_active", table_name="social_edges")
    op.drop_table("social_edges")
