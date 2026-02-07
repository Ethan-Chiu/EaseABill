"""add_tokens_table

Revision ID: f1148993a40d
Revises: 4de11b1f178f
Create Date: 2026-02-07 16:17:44.650497

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f1148993a40d'
down_revision: Union[str, Sequence[str], None] = '4de11b1f178f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'tokens',
        sa.Column('token', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('token'),
    )
    op.create_index('ix_tokens_user_id', 'tokens', ['user_id'])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_tokens_user_id', table_name='tokens')
    op.drop_table('tokens')
