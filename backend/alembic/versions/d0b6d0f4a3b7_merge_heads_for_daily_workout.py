"""Merge heads for daily workout aggregate"""

from typing import Sequence, Union

from alembic import op  # noqa: F401

# revision identifiers, used by Alembic.
revision: str = "d0b6d0f4a3b7"
down_revision: Union[str, Sequence[str], None] = (
    "1fcd1a41f3b1",
    "b1d55d7f43ce",
    "c7bea71d00c1",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Schema upgrade."""
    pass


def downgrade() -> None:
    """Schema downgrade."""
    pass
