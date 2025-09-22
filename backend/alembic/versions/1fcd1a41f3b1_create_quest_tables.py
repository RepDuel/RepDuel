"""create quest tables

Revision ID: 1fcd1a41f3b1
Revises: 729800267f89
Create Date: 2025-10-01 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "1fcd1a41f3b1"
down_revision: Union[str, Sequence[str], None] = "729800267f89"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

quest_templates = "quest_templates"
user_quests = "user_quests"


def upgrade() -> None:
    op.create_table(
        quest_templates,
        sa.Column("id", sa.UUID(), primary_key=True, nullable=False),
        sa.Column("code", sa.String(length=64), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("description", sa.String(length=255), nullable=True),
        sa.Column("cadence", sa.String(length=16), nullable=False),
        sa.Column("metric", sa.String(length=32), nullable=False),
        sa.Column("target_value", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("reward_xp", sa.Integer(), nullable=False),
        sa.Column("auto_claim", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("available_from", sa.DateTime(timezone=True), nullable=True, server_default=sa.text("timezone('utc', now())")),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("timezone('utc', now())")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("timezone('utc', now())")),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code", name="uq_quest_templates_code"),
        sa.CheckConstraint("cadence IN ('daily','weekly','limited')", name="ck_quest_templates_cadence"),
        sa.CheckConstraint("metric IN ('workouts_completed','active_minutes')", name="ck_quest_templates_metric"),
        sa.CheckConstraint("target_value > 0", name="ck_quest_templates_target_positive"),
        sa.CheckConstraint("reward_xp > 0", name="ck_quest_templates_reward_positive"),
    )
    op.create_index("ix_quest_templates_code", quest_templates, ["code"], unique=True)

    op.create_table(
        user_quests,
        sa.Column("id", sa.UUID(), primary_key=True, nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("template_id", sa.UUID(), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="active"),
        sa.Column("progress_value", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("required_value", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("cycle_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("cycle_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("available_from", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reward_claimed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_progress_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("timezone('utc', now())")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("timezone('utc', now())")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["template_id"], ["quest_templates.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", "template_id", "cycle_start", name="uq_user_quests_cycle"),
        sa.CheckConstraint("status IN ('active','completed','claimed','expired')", name="ck_user_quests_status"),
        sa.CheckConstraint("progress_value >= 0", name="ck_user_quests_progress_nonnegative"),
        sa.CheckConstraint("required_value >= 0", name="ck_user_quests_required_nonnegative"),
    )
    op.create_index("ix_user_quests_user", user_quests, ["user_id"])
    op.create_index("ix_user_quests_template", user_quests, ["template_id"])
    op.create_index("ix_user_quests_status", user_quests, ["status"])


def downgrade() -> None:
    op.drop_index("ix_user_quests_status", table_name=user_quests)
    op.drop_index("ix_user_quests_template", table_name=user_quests)
    op.drop_index("ix_user_quests_user", table_name=user_quests)
    op.drop_table(user_quests)
    op.drop_index("ix_quest_templates_code", table_name=quest_templates)
    op.drop_table(quest_templates)

