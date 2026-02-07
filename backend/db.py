from __future__ import annotations

import os
from datetime import datetime
from typing import Optional
from uuid import UUID, uuid4

from sqlmodel import SQLModel, Field, Session, create_engine, select


def _env(key: str, default: str) -> str:
    v = os.getenv(key)
    return v if v else default


def get_engine():
    host = _env("DB_HOST", "postgres")
    port = _env("DB_PORT", "5432")
    name = _env("DB_NAME", "easeabill")
    user = _env("DB_USER", "postgres")
    password = _env("DB_PASSWORD", "postgres")

    # psycopg3 driver
    url = f"postgresql+psycopg://{user}:{password}@{host}:{port}/{name}"
    # echo=True 可以看到 ORM 產生的 SQL（debug 用）
    return create_engine(url, echo=False)


engine = get_engine()


# ----------------------------
# Models (tables)
# ----------------------------

class Expense(SQLModel, table=True):
    __tablename__ = "expenses"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    title: str
    amount: float
    category: str
    date: datetime
    description: Optional[str] = None
    user_id: Optional[str] = Field(default=None, index=True)

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


def init_db() -> None:
    SQLModel.metadata.create_all(engine)


# ----------------------------
# CRUD helpers
# ----------------------------

def add_expense(
    *,
    title: str,
    amount: float,
    category: str,
    date: datetime,
    description: Optional[str] = None,
    user_id: Optional[str] = None,
) -> Expense:
    e = Expense(
        title=title,
        amount=amount,
        category=category,
        date=date,
        description=description,
        user_id=user_id,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    with Session(engine) as session:
        session.add(e)
        session.commit()
        session.refresh(e)  # 把 DB 產生/更新後的值同步回物件
        return e


def get_expense(expense_id: UUID) -> Optional[Expense]:
    with Session(engine) as session:
        return session.get(Expense, expense_id)


def list_expenses(*, user_id: Optional[str] = None, limit: int = 200) -> list[Expense]:
    stmt = select(Expense).order_by(Expense.date.desc()).limit(limit)
    if user_id is not None:
        stmt = stmt.where(Expense.user_id == user_id)

    with Session(engine) as session:
        return list(session.exec(stmt).all())


def update_expense(
    expense_id: UUID,
    *,
    title: Optional[str] = None,
    amount: Optional[float] = None,
    category: Optional[str] = None,
    date: Optional[datetime] = None,
    description: Optional[str] = None,
) -> Optional[Expense]:
    with Session(engine) as session:
        e = session.get(Expense, expense_id)
        if e is None:
            return None

        if title is not None:
            e.title = title
        if amount is not None:
            e.amount = amount
        if category is not None:
            e.category = category
        if date is not None:
            e.date = date
        if description is not None:
            e.description = description

        e.updated_at = datetime.utcnow()
        session.add(e)
        session.commit()
        session.refresh(e)
        return e


def delete_expense(expense_id: UUID) -> bool:
    with Session(engine) as session:
        e = session.get(Expense, expense_id)
        if e is None:
            return False
        session.delete(e)
        session.commit()
        return True
