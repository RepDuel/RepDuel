"""merge heads

Revision ID: 9d012face23f
Revises: d3d1bf6af1a8
Create Date: 2025-09-14 22:21:10.340212

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9d012face23f'
down_revision: Union[str, Sequence[str], None] = 'd3d1bf6af1a8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
