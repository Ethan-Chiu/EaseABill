# backend/financial_helper.py
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone, timedelta
from typing import Any, Optional, Literal

from sqlalchemy import func
from sqlmodel import Session, select

from . import database as db

from .database import (
    Budget,
    Expense,
    list_budgets,
    sum_expenses,
    budget_to_json,
    User,
    Period
)

from .utils import llm_roast_budget

GoalStatus = Literal["ON_TRACK", "WARNING", "OVERSPENT"]


# ----------------------------
# Time helpers (analysis layer)
# ----------------------------
def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def ensure_tz(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def window_for_period(period: Period, now: Optional[datetime] = None) -> tuple[datetime, datetime]:
    """
    Returns current [start, end) window for weekly/monthly/yearly in UTC.
    weekly: Monday 00:00 UTC to next Monday 00:00 UTC
    monthly: 1st of month 00:00 UTC to 1st of next month 00:00 UTC
    yearly: Jan 1 00:00 UTC to Jan 1 next year 00:00 UTC
    """
    now = ensure_tz(now or utc_now())

    if period == "weekly":
        weekday = now.weekday()  # Mon=0
        start = (now - timedelta(days=weekday)).replace(hour=0, minute=0, second=0, microsecond=0)
        end = start + timedelta(days=7)
        return start, end

    if period == "monthly":
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        if start.month == 12:
            end = start.replace(year=start.year + 1, month=1)
        else:
            end = start.replace(month=start.month + 1)
        return start, end

    if period == "yearly":
        start = now.replace(month=1, day=1, hour=0, minute=0, second=0, microsecond=0)
        end = start.replace(year=start.year + 1)
        return start, end

    raise ValueError(f"Unknown period: {period}")


def progress_ratio(start: datetime, end: datetime, now: Optional[datetime] = None) -> float:
    """
    Ratio of elapsed time within [start, end), clamped to [0, 1].
    """
    now = ensure_tz(now or utc_now())
    start = ensure_tz(start)
    end = ensure_tz(end)

    total = (end - start).total_seconds()
    if total <= 0:
        return 1.0

    elapsed = (min(now, end) - start).total_seconds()
    return max(0.0, min(1.0, elapsed / total))


# ----------------------------
# Goal evaluation primitives
# ----------------------------
@dataclass(frozen=True)
class BudgetGoalResult:
    goalType: str  # "BUDGET"
    status: GoalStatus
    shouldNotify: bool
    message: str
    data: dict[str, Any]


def evaluate_budget_goal(
    *,
    user_id: str,
    budget: Budget,
    now: Optional[datetime] = None,
    notify_percent_used: float = 80.0,
    notify_ahead_of_pace_percent: float = 10.0,
) -> BudgetGoalResult:
    """
    Determines if user is on track for ONE budget goal.

    Logic:
    - spent = SUM(expenses) within budget.start_date..end_date
    - percentUsed = spent / limit * 100
    - expectedPercentByNow = progressRatio * 100 (linear pacing)
    - status:
        OVERSPENT if spent > limit
        WARNING if percentUsed >= notify_percent_used OR (percentUsed - expectedPercentByNow) >= notify_ahead_of_pace_percent
        ON_TRACK otherwise
    """
    now = ensure_tz(now or utc_now())

    start = ensure_tz(budget.start_date)
    end = ensure_tz(budget.end_date)

    spent = sum_expenses(user_id=user_id, start=start, end=end)
    limit_amt = float(budget.limit)
    remaining = limit_amt - spent

    percent_used = (spent / limit_amt * 100.0) if limit_amt > 0 else 0.0

    prog = progress_ratio(start, end, now)
    expected_spent = limit_amt * prog
    expected_percent = prog * 100.0
    ahead_by = spent - expected_spent
    ahead_percent = percent_used - expected_percent

    if spent > limit_amt:
        status: GoalStatus = "OVERSPENT"
        should_notify = True
        msg = f"Budget exceeded. Remaining {remaining:.2f}."
    else:
        is_warning = (percent_used >= notify_percent_used) or (ahead_percent >= notify_ahead_of_pace_percent)
        if is_warning:
            status = "WARNING"
            should_notify = True
            msg = (
                f"Budget: {percent_used:.0f}% used "
                f"({ahead_percent:+.0f}% vs pace). Remaining {remaining:.2f}."
            )
        else:
            status = "ON_TRACK"
            should_notify = False
            msg = f"Budget: on track ({percent_used:.0f}% used). Remaining {remaining:.2f}."


    msg = llm_roast_budget(msg).get("choices", [{}])[0].get("message", {}).get("content", "").strip() or msg

    payload = {
        "goalType": "BUDGET",
        "budgetId": str(budget.id),
        "period": budget.period,
        "window": {"start": start.isoformat(), "end": end.isoformat()},
        "spent": spent,
        "limit": limit_amt,
        "remaining": remaining,
        "percentUsed": percent_used,
        "expectedSpentByNow": expected_spent,
        "expectedPercentByNow": expected_percent,
        "aheadBy": ahead_by,
        "aheadPercent": ahead_percent,
    }

    return BudgetGoalResult(goalType="BUDGET", status=status, shouldNotify=should_notify, message=msg, data=payload)


def evaluate_all_budget_goals(
    *,
    user_id: str,
    now: Optional[datetime] = None,
    active_only: bool = True,
) -> list[dict[str, Any]]:
    """
    Returns all budget statuses for dashboard / weekly summary.
    """
    now = ensure_tz(now or utc_now())
    budgets = list_budgets(user_id=user_id, active_only=active_only, now=now)

    results: list[dict[str, Any]] = []
    for b in budgets:
        r = evaluate_budget_goal(user_id=user_id, budget=b, now=now)
        results.append(
            {
                "goalType": r.goalType,
                "status": r.status,
                "shouldNotify": r.shouldNotify,
                "message": r.message,
                **r.data,
            }
        )
    return results


def evaluate_on_new_expense(
    *,
    user_id: str,
    expense: Expense,
    now: Optional[datetime] = None,
) -> list[dict[str, Any]]:
    """
    Real-time feedback: call after inserting a new expense.
    Strategy:
    - Evaluate all active budgets at 'now' (budgets are no longer per-category).
    - Return alerts for WARNING/OVERSPENT (or shouldNotify=True).
    """
    now = ensure_tz(now or utc_now())
    budgets = list_budgets(user_id=user_id, active_only=True, now=now)

    impacted = budgets
    alerts: list[dict[str, Any]] = []
    for b in impacted:
        r = evaluate_budget_goal(user_id=user_id, budget=b, now=now)
        if r.shouldNotify:
            alerts.append(
                {
                    "type": "BUDGET_ALERT",
                    "status": r.status,
                    "message": r.message,
                    **r.data,
                }
            )
    return alerts


# ----------------------------
# Weekly / Monthly analysis helpers
# ----------------------------
def current_spend_summary(
    *,
    user_id: str,
    period: Period = "monthly",
    now: Optional[datetime] = None,
) -> dict[str, Any]:
    """
    Total spend for current period window + time progress pacing numbers.
    """
    now = ensure_tz(now or utc_now())
    start, end = window_for_period(period, now=now)

    spent = sum_expenses(user_id=user_id, start=start, end=end)
    prog = progress_ratio(start, end, now)
    return {
        "period": period,
        "window": {"start": start.isoformat(), "end": end.isoformat()},
        "spent": spent,
        "progressRatio": prog,
        "progressPercent": prog * 100.0,
    }


def trend_series(
    *,
    user_id: str,
    period: Period = "weekly",
    buckets: int = 8,
    now: Optional[datetime] = None,
) -> list[dict[str, Any]]:
    """
    Returns last N period totals (old->new).
    Simple and reliable: compute each window in Python and call sum_expenses.
    """
    now = ensure_tz(now or utc_now())
    cur_start, cur_end = window_for_period(period, now=now)

    series: list[dict[str, Any]] = []
    for _ in range(buckets):
        total = sum_expenses(user_id=user_id, start=cur_start, end=cur_end)
        series.append(
            {
                "start": cur_start.isoformat(),
                "end": cur_end.isoformat(),
                "total": total,
            }
        )

        # move one period back
        if period == "weekly":
            cur_end = cur_start
            cur_start = cur_start - timedelta(days=7)
        elif period == "monthly":
            anchor = (cur_start - timedelta(days=1)).replace(hour=12)
            cur_start, cur_end = window_for_period("monthly", now=anchor)
        else:  # yearly
            anchor = cur_start.replace(year=cur_start.year - 1, month=6, day=1)
            cur_start, cur_end = window_for_period("yearly", now=anchor)

    series.reverse()
    return series


def budgets_with_spent(
    *,
    user_id: str,
    now: Optional[datetime] = None,
    active_only: bool = True,
) -> list[dict[str, Any]]:
    """
    Convenience function for frontend:
    returns Budget JSON objects that match your Flutter Budget.fromJson(),
    with 'spent' computed from expenses.
    """
    now = ensure_tz(now or utc_now())
    budgets = list_budgets(user_id=user_id, active_only=active_only, now=now)

    out: list[dict[str, Any]] = []
    for b in budgets:
        spent = sum_expenses(user_id=user_id, start=b.start_date, end=b.end_date)
        out.append(budget_to_json(b, spent=spent))
    return out


def spoken_summary(
    *,
    user_id: str,
    period: Period = "monthly",
    now: Optional[datetime] = None,
) -> str:
    """
    Short text for TTS on frontend (speech support).
    """
    now = ensure_tz(now or utc_now())
    s = current_spend_summary(user_id=user_id, period=period, now=now)
    statuses = evaluate_all_budget_goals(user_id=user_id, now=now, active_only=True)
    warn = [x for x in statuses if x["status"] in ("WARNING", "OVERSPENT")]

    if warn:
        top = warn[0]
        return (
            f"This {period}, you spent {s['spent']:.0f}. "
            f"Budget is {top['percentUsed']:.0f}% used and {top['status'].lower()}."
        )

    return f"This {period}, you spent {s['spent']:.0f}. All budgets are on track."

# ----------------------------
# Cohort (income bucket) + Region (location) peer comparison
# ----------------------------

# Minimal buckets; adjust later if you want
INCOME_BUCKETS = [
    (0, 2500),
    (2500, 4000),
    (4000, 6000),
    (6000, 9000),
    (9000, 13000),
    (13000, 10**18),
]


def income_bucket_label(monthly_income: Optional[float]) -> Optional[str]:
    if monthly_income is None:
        return None
    x = float(monthly_income)
    for lo, hi in INCOME_BUCKETS:
        if lo <= x < hi:
            return f"{lo}+" if hi >= 10**18 else f"{lo}-{hi}"
    return None


def income_bucket_range(label: str) -> tuple[float, float]:
    # "2500-4000" -> (2500, 4000), "13000+" -> (13000, inf)
    if label.endswith("+"):
        return float(label[:-1]), float("inf")
    lo_s, hi_s = label.split("-")
    return float(lo_s), float(hi_s)


def cohort_region_peer_stats(
    *,
    location: str,
    bucket_label: str,
    start: datetime,
    end: datetime,
    category: Optional[str] = None,
) -> tuple[float, int]:
    """
    Returns (peer_avg_spent, peer_user_count) for users:
      same location AND monthly_income in same bucket
    over [start, end).
    """
    start = ensure_tz(start)
    end = ensure_tz(end)
    lo, hi = income_bucket_range(bucket_label)

    with Session(db.engine) as session:
        per_user = (
            select(
                Expense.user_id,
                func.coalesce(func.sum(Expense.amount), 0.0).label("user_total"),
            )
            .join(User, User.id == Expense.user_id)
            .where(
                User.location == location,
                User.monthly_income.is_not(None),
                User.monthly_income >= lo,
                *((User.monthly_income < hi,) if hi != float("inf") else ()),
                Expense.date >= start,
                Expense.date < end,
            )
            .group_by(Expense.user_id)
        )

        if category is not None:
            per_user = per_user.where(Expense.category == category)

        subq = per_user.subquery()
        avg_stmt = select(
            func.coalesce(func.avg(subq.c.user_total), 0.0),
            func.count(subq.c.user_id),
        )

        avg_val, n_users = session.exec(avg_stmt).one()
        return float(avg_val or 0.0), int(n_users or 0)


def compare_user_to_cohort_in_region(
    *,
    user_id: str,
    period: Period = "monthly",
    category: Optional[str] = None,
    now: Optional[datetime] = None,
    min_peers: int = 1,
) -> dict[str, Any]:
    """
    Compare user spend vs peers in SAME location AND SAME income cohort.
    """
    now = ensure_tz(now or utc_now())
    u = db.get_user_by_id(user_id)
    if u is None:
        return {"type": "COHORT_REGION_FEEDBACK", "message": "User not found.", "data": {"userId": user_id}}

    if not u.location:
        return {
            "type": "COHORT_REGION_FEEDBACK",
            "message": "Missing location. Set user.location during onboarding.",
            "data": {"userId": user_id},
        }

    bucket = income_bucket_label(u.monthly_income)
    if bucket is None:
        return {
            "type": "COHORT_REGION_FEEDBACK",
            "message": "Missing monthlyIncome. Set user.monthly_income during onboarding.",
            "data": {"userId": user_id, "location": u.location},
        }

    start, end = window_for_period(period, now=now)
    user_spent = sum_expenses(user_id=user_id, start=start, end=end, category=category)

    peer_avg, peer_users = cohort_region_peer_stats(
        location=u.location,
        bucket_label=bucket,
        start=start,
        end=end,
        category=category,
    )

    delta = float(user_spent) - float(peer_avg)
    delta_pct = (delta / peer_avg * 100.0) if peer_avg > 0 else 0.0

    cat = f" in {category}" if category else ""
    cohort_text = f"{u.location}, income {bucket}"

    if peer_users < min_peers:
        msg = f"Not enough peer data to compare for {cohort_text}{cat} yet."
    elif peer_avg <= 0:
        msg = f"Peer average is not available for {cohort_text}{cat} yet."
    else:
        if delta_pct >= 15:
            msg = (
                f"Compared with peers in {cohort_text}{cat}, you spent ~{delta_pct:.0f}% more "
                f"({user_spent:.0f} vs avg {peer_avg:.0f}). Consider tightening spend this period."
            )
        elif delta_pct <= -15:
            msg = (
                f"Compared with peers in {cohort_text}{cat}, you spent ~{abs(delta_pct):.0f}% less "
                f"({user_spent:.0f} vs avg {peer_avg:.0f}). Nice—consider moving the difference to savings."
            )
        else:
            msg = (
                f"Compared with peers in {cohort_text}{cat}, your spending is close to average "
                f"({user_spent:.0f} vs avg {peer_avg:.0f})."
            )

    msg = llm_roast_budget(msg).get("choices", [{}])[0].get("message", {}).get("content", "").strip() or msg

    return {
        "type": "COHORT_REGION_FEEDBACK",
        "message": msg,
        "data": {
            "userId": user_id,
            "location": u.location,
            "incomeBucket": bucket,
            "period": period,
            "category": category,
            "userSpent": float(user_spent),
            "peerAvg": float(peer_avg),
            "peerUsers": int(peer_users),
            "delta": float(delta),
            "deltaPercent": float(delta_pct),
            "window": {"start": start.isoformat(), "end": end.isoformat()},
        },
    }