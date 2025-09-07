"""Add ON DELETE CASCADE to routine_submission.user_id

Revision ID: f98b5ef5e896
Revises: 6a6a97464f11
Create Date: 2025-09-07 14:36:16.206317
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'f98b5ef5e896'
down_revision: Union[str, Sequence[str], None] = '6a6a97464f11'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint(
        'routine_submission_user_id_fkey',
        'routine_submission',
        type_='foreignkey'
    )
    op.create_foreign_key(
        'routine_submission_user_id_fkey',
        'routine_submission',
        'users',
        ['user_id'],
        ['id'],
        ondelete='CASCADE'
    )


def downgrade() -> None:
    op.drop_constraint(
        'routine_submission_user_id_fkey',
        'routine_submission',
        type_='foreignkey'
    )
    op.create_foreign_key(
        'routine_submission_user_id_fkey',
        'routine_submission',
        'users',
        ['user_id'],
        ['id']
    )
