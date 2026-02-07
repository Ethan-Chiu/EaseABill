from __future__ import annotations

import os
from datetime import datetime
from typing import Any, Optional

import psycopg
from psycopg.rows import dict_row


def _env(key: str, default: str) -> str:
    v = os.getenv(key)
    return v if v else default


def get_conn() -> psycopg.Connection:
    """
    Minimal connection helper.
    Defaults match your docker-compose:
      user=postgres, password=postgres, db=easeabill, host=localhost, port=5432
    Override via env vars: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
    """
    host = _env("DB_HOST", "localhost")
    port = _env("DB_PORT", "5432")
    name = _env("DB_NAME", "easeabill")
    user = _env("DB_USER", "postgres")
    password = _env("DB_PASSWORD", "postgres")

    dsn = f"host={host} port={port} dbname={name} user={user} password={password}"
    return psycopg.connect(dsn, row_factory=dict_row)


def init_db() -> None:
    """
    Create only the expenses table (minimum needed for CRUD).
    """
    sql = """
    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    CREATE TABLE IF NOT EXISTS expenses (
        id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title       TEXT NOT NULL,
        amount      NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
        category    TEXT NOT NULL,
        date        TIMESTAMPTZ NOT NULL,
        description TEXT,
        user_id     TEXT,
        created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
        updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE INDEX IF NOT EXISTS idx_expenses_user_date ON expenses(user_id, date DESC);
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()


# ----------------------------
# Expense CRUD
# ----------------------------

def add_expense(
    *,
    title: str,
    amount: float,
    category: str,
    date: datetime,
    description: Optional[str] = None,
    user_id: Optional[str] = None,
) -> dict[str, Any]:
    sql = """
    INSERT INTO expenses (title, amount, category, date, description, user_id)
    VALUES (%(title)s, %(amount)s, %(category)s, %(date)s, %(description)s, %(user_id)s)
    RETURNING
      id::text AS id,
      title,
      amount::float8 AS amount,
      category,
      date,
      description,
      user_id AS "userId";
    """
    params = {
        "title": title,
        "amount": amount,
        "category": category,
        "date": date,
        "description": description,
        "user_id": user_id,
    }
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            row = cur.fetchone()
        conn.commit()
    if row is None:
        raise RuntimeError("Failed to insert expense")
    return row


def list_expenses(*, user_id: Optional[str] = None, limit: int = 200) -> list[dict[str, Any]]:
    if user_id is None:
        sql = """
        SELECT
          id::text AS id,
          title,
          amount::float8 AS amount,
          category,
          date,
          description,
          user_id AS "userId"
        FROM expenses
        ORDER BY date DESC
        LIMIT %(limit)s;
        """
        params = {"limit": limit}
    else:
        sql = """
        SELECT
          id::text AS id,
          title,
          amount::float8 AS amount,
          category,
          date,
          description,
          user_id AS "userId"
        FROM expenses
        WHERE user_id = %(user_id)s
        ORDER BY date DESC
        LIMIT %(limit)s;
        """
        params = {"user_id": user_id, "limit": limit}

    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
            return list(rows or [])


def update_expense(
    expense_id: str,
    *,
    title: Optional[str] = None,
    amount: Optional[float] = None,
    category: Optional[str] = None,
    date: Optional[datetime] = None,
    description: Optional[str] = None,
) -> Optional[dict[str, Any]]:
    sets = []
    params: dict[str, Any] = {"id": expense_id}

    if title is not None:
        sets.append("title = %(title)s")
        params["title"] = title
    if amount is not None:
        sets.append("amount = %(amount)s")
        params["amount"] = amount
    if category is not None:
        sets.append("category = %(category)s")
        params["category"] = category
    if date is not None:
        sets.append("date = %(date)s")
        params["date"] = date
    if description is not None:
        sets.append("description = %(description)s")
        params["description"] = description

    if not sets:
        return get_expense(expense_id)

    sql = f"""
    UPDATE expenses
    SET {", ".join(sets)}, updated_at = now()
    WHERE id::text = %(id)s
    RETURNING
      id::text AS id,
      title,
      amount::float8 AS amount,
      category,
      date,
      description,
      user_id AS "userId";
    """

    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            row = cur.fetchone()
        conn.commit()
    return row


def delete_expense(expense_id: str) -> bool:
    sql = "DELETE FROM expenses WHERE id::text = %(id)s;"
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, {"id": expense_id})
            ok = cur.rowcount > 0
        conn.commit()
    return ok


def get_expense(expense_id: str) -> Optional[dict[str, Any]]:
    sql = """
    SELECT
      id::text AS id,
      title,
      amount::float8 AS amount,
      category,
      date,
      description,
      user_id AS "userId"
    FROM expenses
    WHERE id::text = %(id)s
    LIMIT 1;
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, {"id": expense_id})
            return cur.fetchone()
