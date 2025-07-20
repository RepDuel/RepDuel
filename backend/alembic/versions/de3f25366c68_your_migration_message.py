"""Your migration message

Revision ID: de3f25366c68
Revises: 02b778152ada
Create Date: 2025-07-20 11:53:49.162059

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'de3f25366c68'
down_revision: Union[str, Sequence[str], None] = '02b778152ada'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.execute("""
        ALTER TABLE routine_submission
        ALTER COLUMN duration TYPE DOUBLE PRECISION
        USING EXTRACT(EPOCH FROM duration)
    """)

def downgrade():
    op.execute("""
        ALTER TABLE routine_submission
        ALTER COLUMN duration TYPE INTERVAL
        USING duration * INTERVAL '1 second'
    """)