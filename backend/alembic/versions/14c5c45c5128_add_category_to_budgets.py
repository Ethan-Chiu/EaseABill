"""add_category_to_budgets

Revision ID: 14c5c45c5128
Revises: f1148993a40d
Create Date: 2026-02-07 16:46:57.650212

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '14c5c45c5128'
down_revision: Union[str, Sequence[str], None] = 'f1148993a40d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add category column to budgets table with a default value
    op.add_column('budgets', sa.Column('category', sa.String(), nullable=False, server_default='General'))
    # Remove the server default after adding the column
    op.alter_column('budgets', 'category', server_default=None)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('budgets', 'category')
