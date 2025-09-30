"""add routine share snapshots table

Revision ID: b3f2b9d5c6a4
Revises: 7cce11dcf858
Create Date: 2025-09-30 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'b3f2b9d5c6a4'
down_revision: Union[str, Sequence[str], None] = '7cce11dcf858'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'routine_share_snapshots',
        sa.Column('code', sa.String(length=16), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('image_url', sa.String(), nullable=True),
        sa.Column('scenarios', sa.JSON(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('source_routine_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('created_by_user_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.ForeignKeyConstraint(['created_by_user_id'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['source_routine_id'], ['routines.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('code')
    )
    op.create_index(op.f('ix_routine_share_snapshots_code'), 'routine_share_snapshots', ['code'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_routine_share_snapshots_code'), table_name='routine_share_snapshots')
    op.drop_table('routine_share_snapshots')
