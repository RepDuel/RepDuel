"""add hidden_routines table

Revision ID: aa12bb34cc56
Revises: f98b5ef5e896
Create Date: 2025-09-15 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'aa12bb34cc56'
down_revision = 'f98b5ef5e896'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'hidden_routines',
        sa.Column('user_id', sa.dialects.postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), primary_key=True),
        sa.Column('routine_id', sa.dialects.postgresql.UUID(as_uuid=True), sa.ForeignKey('routines.id', ondelete='CASCADE'), primary_key=True),
    )
    op.create_unique_constraint('uq_hidden_user_routine', 'hidden_routines', ['user_id', 'routine_id'])


def downgrade() -> None:
    op.drop_constraint('uq_hidden_user_routine', 'hidden_routines', type_='unique')
    op.drop_table('hidden_routines')

