from __future__ import annotations

from datetime import datetime, timezone, timedelta
from typing import Optional, Any

from sqlalchemy import func
from sqlmodel import Session, select

import backend.database as db
from backend.database import Expense


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _ensure_tz(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _month_window(now: Optional[datetime] = None) -> tuple[datetime, datetime]:
    now = _ensure_tz(now or _utc_now())
    start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if start.month == 12:
        end = start.replace(year=start.year + 1, month=1)
    else:
        end = start.replace(month=start.month + 1)
    return start, end


def _week_window(now: Optional[datetime] = None) -> tuple[datetime, datetime]:
    """
    ISO week: Monday 00:00 -> next Monday 00:00 (UTC)
    """
    now = _ensure_tz(now or _utc_now())
    weekday = now.weekday()  # Mon=0
    start = (now - timedelta(days=weekday)).replace(hour=0, minute=0, second=0, microsecond=0)
    end = start + timedelta(days=7)
    return start, end


# ------------------------------------------------------------
# 1) Pie chart: totals by category (for a window)
# ------------------------------------------------------------
def pie_expense_by_category(
    *,
    user_id: str,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    now: Optional[datetime] = None,
    top_n: int = 5,
    include_other: bool = True,
) -> dict[str, Any]:
    """
    Returns totals per category for pie chart.

    If start/end not provided -> default to current month window.
    Output example:
    {
      "window": {"start": "...", "end": "..."},
      "total": 1234.0,
      "slices": [
        {"label": "Food & Dining", "value": 300.0},
        {"label": "Transportation", "value": 120.0},
        ...
        {"label": "Other", "value": 50.0}  # optional roll-up
      ]
    }
    """
    if start is None or end is None:
        #if time not specified, use current month window
        start_w, end_w = _month_window(now=now)
        start = start or start_w
        end = end or end_w

    start = _ensure_tz(start)
    end = _ensure_tz(end)

    with Session(db.engine) as session:
        rows = session.exec(
            select(
                Expense.category,
                func.coalesce(func.sum(Expense.amount), 0.0).label("total"),
            )
            .where(
                Expense.user_id == user_id,
                Expense.date >= start,
                Expense.date < end,
            )
            .group_by(Expense.category)
            .order_by(func.sum(Expense.amount).desc())
        ).all()

    pairs = [(r[0], float(r[1] or 0.0)) for r in rows]
    total = sum(v for _, v in pairs)

    if not pairs:
        return {
            "window": {"start": start.isoformat(), "end": end.isoformat()},
            "total": 0.0,
            "slices": [],
        }

    if top_n > 0 and len(pairs) > top_n:
        top = pairs[:top_n]
        rest = pairs[top_n:]
        other_sum = sum(v for _, v in rest)
        slices = [{"label": k, "value": v} for k, v in top]

        if include_other and other_sum > 0:
            slices.append({"label": "Other", "value": other_sum})
    else:
        slices = [{"label": k, "value": v} for k, v in pairs]

    return {
        "window": {"start": start.isoformat(), "end": end.isoformat()},
        "total": float(total),
        "slices": slices,
    }


# ------------------------------------------------------------
# 2) Weekly series: last N weeks totals (category or overall)
# ------------------------------------------------------------
def weekly_spend_series(
    *,
    user_id: str,
    weeks: int = 8,
    category: Optional[str] = None,
    now: Optional[datetime] = None,
) -> dict[str, Any]:
    """
    Returns last N weeks totals (old -> new).
    If category is None -> total spend; else -> that category only.

    Output example:
    {
      "category": null,
      "points": [
        {"x": "2026-01-01T00:00:00+00:00", "y": 120.0},
        ...
      ]
    }
    """
    now = _ensure_tz(now or _utc_now())
    cur_start, cur_end = _week_window(now=now)

    points = []
    with Session(db.engine) as session:
        for _ in range(weeks):
            stmt = select(func.coalesce(func.sum(Expense.amount), 0.0)).where(
                Expense.user_id == user_id,
                Expense.date >= cur_start,
                Expense.date < cur_end,
            )
            if category is not None:
                stmt = stmt.where(Expense.category == category)

            total = session.exec(stmt).one()
            points.append({"x": cur_start.isoformat(), "y": float(total or 0.0)})

            # move one week back
            cur_end = cur_start
            cur_start = cur_start - timedelta(days=7)

    points.reverse()
    return {"category": category, "points": points}
