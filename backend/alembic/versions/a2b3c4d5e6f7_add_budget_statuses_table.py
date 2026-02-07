"""add_budget_statuses_table

Revision ID: a2b3c4d5e6f7
Revises: 14c5c45c5128
Create Date: 2026-02-07 17:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a2b3c4d5e6f7'
down_revision: Union[str, Sequence[str], None] = '14c5c45c5128'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'budget_statuses',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('goal_type', sa.String(), nullable=False),
        sa.Column('status', sa.String(), nullable=False),
        sa.Column('should_notify', sa.Boolean(), nullable=False),
        sa.Column('message', sa.String(), nullable=False),
        sa.Column('data', sa.JSON(), nullable=False),
        sa.Column('timestamp', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_budget_statuses_user_id', 'budget_statuses', ['user_id'])
    op.create_index('ix_budget_statuses_timestamp', 'budget_statuses', ['timestamp'])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_budget_statuses_timestamp', table_name='budget_statuses')
    op.drop_index('ix_budget_statuses_user_id', table_name='budget_statuses')
    op.drop_table('budget_statuses')
