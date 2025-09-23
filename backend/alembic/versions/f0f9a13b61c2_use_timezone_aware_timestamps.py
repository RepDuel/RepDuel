"""Convert critical timestamp columns to timezone-aware UTC.

Revision ID: f0f9a13b61c2
Revises: aa12bb34cc56
Create Date: 2025-01-17 00:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa  # noqa: F401 - metadata for Alembic operations

# revision identifiers, used by Alembic.
revision: str = "f0f9a13b61c2"
down_revision: Union[str, Sequence[str], None] = "aa12bb34cc56"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        "UPDATE energy_history SET created_at = now() WHERE created_at IS NULL"
    )
    op.execute(
        """
        ALTER TABLE energy_history
        ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE
        USING created_at AT TIME ZONE 'UTC'
        """
    )
    op.execute(
        "ALTER TABLE energy_history ALTER COLUMN created_at SET NOT NULL"
    )

    op.execute(
        """
        ALTER TABLE personal_best_events
        ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE
        USING created_at AT TIME ZONE 'UTC'
        """
    )
    op.execute(
        "ALTER TABLE personal_best_events ALTER COLUMN created_at SET DEFAULT now()"
    )

    op.execute(
        """
        ALTER TABLE routine_submission
        ALTER COLUMN completion_timestamp TYPE TIMESTAMP WITH TIME ZONE
        USING completion_timestamp AT TIME ZONE 'UTC'
        """
    )

    op.execute(
        """
        ALTER TABLE scores
        ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE
        USING created_at AT TIME ZONE 'UTC'
        """
    )

    op.execute("UPDATE routines SET created_at = now() WHERE created_at IS NULL")
    op.execute(
        """
        ALTER TABLE routines
        ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE
        USING created_at AT TIME ZONE 'UTC'
        """
    )
    op.execute("ALTER TABLE routines ALTER COLUMN created_at SET DEFAULT now()")
    op.execute("ALTER TABLE routines ALTER COLUMN created_at SET NOT NULL")


def downgrade() -> None:
    op.execute("ALTER TABLE routines ALTER COLUMN created_at DROP NOT NULL")
    op.execute("ALTER TABLE routines ALTER COLUMN created_at DROP DEFAULT")
    op.execute(
        """
        ALTER TABLE routines
        ALTER COLUMN created_at TYPE TIMESTAMP WITHOUT TIME ZONE
        USING created_at AT TIME ZONE 'UTC'
        """
    )
    op.execute("ALTER TABLE routines ALTER COLUMN created_at SET DEFAULT now()")

    op.execute(
        """
        ALTER TABLE scores
        ALTER COLUMN created_at TYPE TIMESTAMP WITHOUT TIME ZONE
        USING created_at AT TIME ZONE 'UTC'
        """
    )

    op.execute(
        """
        ALTER TABLE routine_submission
        ALTER COLUMN completion_timestamp TYPE TIMESTAMP WITHOUT TIME ZONE
        USING completion_timestamp AT TIME ZONE 'UTC'
        """
    )

    op.execute(
        """
        ALTER TABLE personal_best_events
        ALTER COLUMN created_at TYPE TIMESTAMP WITHOUT TIME ZONE
        USING created_at AT TIME ZONE 'UTC'
        """
    )
    op.execute(
        "ALTER TABLE personal_best_events ALTER COLUMN created_at SET DEFAULT now()"
    )

    op.execute("ALTER TABLE energy_history ALTER COLUMN created_at DROP NOT NULL")
    op.execute(
        """
        ALTER TABLE energy_history
        ALTER COLUMN created_at TYPE TIMESTAMP WITHOUT TIME ZONE
        USING created_at AT TIME ZONE 'UTC'
        """
    )
