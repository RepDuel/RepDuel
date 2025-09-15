"""merge heads

Revision ID: d3d1bf6af1a8
Revises: 7cce11dcf858, aa12bb34cc56
Create Date: 2025-09-14 22:13:04.167336

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd3d1bf6af1a8'
down_revision: Union[str, Sequence[str], None] = ('7cce11dcf858', 'aa12bb34cc56')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
