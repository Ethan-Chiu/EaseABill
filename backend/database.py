from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any, Optional, Literal
from uuid import UUID, uuid4

from sqlmodel import SQLModel, Field, Session, create_engine, select
from sqlalchemy import func, JSON

Period = Literal["weekly", "monthly", "yearly"]

def _env(key: str, default: str) -> str:
    v = os.getenv(key)
    return v if v else default

def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _ensure_tz(dt: datetime) -> datetime:
    # 讓所有寫進 DB 的 datetime 都是 tz-aware（配合 TIMESTAMPTZ）
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt

def get_engine():
    host = _env("DB_HOST", "localhost") #testing in local
    port = _env("DB_PORT", "5432")
    name = _env("DB_NAME", "easeabill")
    user = _env("DB_USER", "postgres")
    password = _env("DB_PASSWORD", "postgres")

    # psycopg3 driver
    url = f"postgresql+psycopg://{user}:{password}@{host}:{port}/{name}"
    # echo=True 可以看到 ORM 產生的 SQL（debug 用）
    print(url)
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

    created_at: datetime = Field(default_factory=_utc_now)
    updated_at: datetime = Field(default_factory=_utc_now)

class User(SQLModel, table=True):
    __tablename__ = "users"

    id: str = Field(primary_key=True)
    username: str = Field(unique=True, index=True)
    password_hash: str
    location: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    monthly_income: Optional[float] = None
    budget_goal: Optional[float] = None
    is_onboarded: bool = Field(default=False)

    created_at: datetime = Field(default_factory=_utc_now)
    updated_at: datetime = Field(default_factory=_utc_now)

class Budget(SQLModel, table=True):
    __tablename__ = "budgets"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    category: str
    limit: float
    period: str  # "weekly" | "monthly" | "yearly"
    start_date: datetime  # timestamptz
    end_date: datetime    # timestamptz
    user_id: Optional[str] = Field(default=None, index=True)

    created_at: datetime = Field(default_factory=_utc_now)
    updated_at: datetime = Field(default_factory=_utc_now)

class Token(SQLModel, table=True):
    __tablename__ = "tokens"

    token: str = Field(primary_key=True)
    user_id: str = Field(index=True)
    expires_at: datetime
    created_at: datetime = Field(default_factory=_utc_now)

class BudgetStatus(SQLModel, table=True):
    __tablename__ = "budget_statuses"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: str = Field(index=True)
    goal_type: str  # "BUDGET"
    status: str  # "ON_TRACK", "WARNING", "OVERSPENT"
    should_notify: bool
    message: str
    data: dict[str, Any] = Field(default_factory=dict, sa_type=JSON)
    timestamp: datetime = Field(default_factory=_utc_now, index=True)

def init_db() -> None:
    SQLModel.metadata.create_all(engine)



# ----------------------------
# JSON serializers (match Flutter keys)
# ----------------------------
def expense_to_json(e: Expense) -> dict[str, Any]:
    return {
        "id": str(e.id),
        "title": e.title,
        "amount": float(e.amount),
        "category": e.category,
        "date": _ensure_tz(e.date).isoformat(),
        "description": e.description,
        "userId": e.user_id,
    }


def budget_to_json(b: Budget, *, spent: float = 0.0) -> dict[str, Any]:
    # spent 通常是「算出來」的，預設 0；分析層可傳入實際 spent
    return {
        "id": str(b.id),
        "category": b.category,
        "limit": float(b.limit),
        "spent": float(spent),
        "period": b.period,
        "startDate": _ensure_tz(b.start_date).isoformat(),
        "endDate": _ensure_tz(b.end_date).isoformat(),
        "userId": b.user_id,
    }


def user_to_json(u: User) -> dict[str, Any]:
    return {
        "id": u.id,
        "username": u.username,
        "location": u.location,
        "monthlyIncome": u.monthly_income,
        "budgetGoal": u.budget_goal,
        "isOnboarded": u.is_onboarded,
    }

# ----------------------------
# Token helpers
# ----------------------------

def add_token(token: str, user_id: str, expires_at: datetime) -> Token:
    """Create a new authentication token"""
    with Session(engine) as session:
        t = Token(token=token, user_id=user_id, expires_at=_ensure_tz(expires_at))
        session.add(t)
        session.commit()
        session.refresh(t)
        return t

def get_token(token: str) -> Optional[Token]:
    """Get token by token string"""
    with Session(engine) as session:
        statement = select(Token).where(Token.token == token)
        return session.exec(statement).first()

def delete_token(token: str) -> None:
    """Delete a token (logout)"""
    with Session(engine) as session:
        statement = select(Token).where(Token.token == token)
        t = session.exec(statement).first()
        if t:
            session.delete(t)
            session.commit()

def delete_expired_tokens() -> None:
    """Clean up expired tokens"""
    with Session(engine) as session:
        statement = select(Token).where(Token.expires_at < _utc_now())
        expired = session.exec(statement).all()
        for t in expired:
            session.delete(t)
        session.commit()

# ----------------------------
# Budget Status helpers
# ----------------------------

def add_budget_status(
    *,
    user_id: str,
    goal_type: str,
    status: str,
    should_notify: bool,
    message: str,
    data: dict[str, Any],
) -> BudgetStatus:
    """Create a new budget status notification"""
    bs = BudgetStatus(
        user_id=user_id,
        goal_type=goal_type,
        status=status,
        should_notify=should_notify,
        message=message,
        data=data,
        timestamp=_utc_now(),
    )
    with Session(engine) as session:
        session.add(bs)
        session.commit()
        session.refresh(bs)
        return bs


def list_budget_statuses(
    *,
    user_id: str,
    date: Optional[datetime] = None,
) -> list[BudgetStatus]:
    """Get all budget statuses for a user on a specific date (default today)"""
    if date is None:
        date = _utc_now()
    
    # Get start and end of day in UTC
    start_of_day = _ensure_tz(date).replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = start_of_day.replace(hour=23, minute=59, second=59, microsecond=999999)
    
    stmt = (
        select(BudgetStatus)
        .where(
            BudgetStatus.user_id == user_id,
            BudgetStatus.timestamp >= start_of_day,
            BudgetStatus.timestamp <= end_of_day,
        )
        .order_by(BudgetStatus.timestamp.desc())
    )
    
    with Session(engine) as session:
        return list(session.exec(stmt).all())


def budget_status_to_json(bs: BudgetStatus) -> dict[str, Any]:
    """Convert BudgetStatus to JSON"""
    return {
        "id": str(bs.id),
        "goalType": bs.goal_type,
        "status": bs.status,
        "shouldNotify": bs.should_notify,
        "message": bs.message,
        "data": bs.data,
        "timestamp": _ensure_tz(bs.timestamp).isoformat(),
    }

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


# ----------------------------
# Budget CRUD
# ----------------------------
def add_budget(
    *,
    category: str,
    limit: float,
    period: Period,
    start_date: datetime,
    end_date: datetime,
    user_id: Optional[str] = None,
) -> Budget:
    b = Budget(
        category=category,
        limit=float(limit),
        period=period,
        start_date=_ensure_tz(start_date),
        end_date=_ensure_tz(end_date),
        user_id=user_id,
        created_at=_utc_now(),
        updated_at=_utc_now(),
    )
    with Session(engine) as session:
        session.add(b)
        session.commit()
        session.refresh(b)
        return b


def get_budget(budget_id: UUID) -> Optional[Budget]:
    with Session(engine) as session:
        return session.get(Budget, budget_id)


def list_budgets(*, user_id: str, active_only: bool = False, now: Optional[datetime] = None) -> list[Budget]:
    stmt = select(Budget).where(Budget.user_id == user_id).order_by(Budget.start_date.desc())
    if active_only:
        now = _ensure_tz(now or _utc_now())
        stmt = stmt.where(Budget.start_date <= now, Budget.end_date > now)

    with Session(engine) as session:
        return list(session.exec(stmt).all())


def update_budget(
    budget_id: UUID,
    *,
    user_id: str,
    category: Optional[str] = None,
    limit: Optional[float] = None,
    period: Optional[Period] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
) -> Optional[Budget]:
    with Session(engine) as session:
        b = session.get(Budget, budget_id)
        if b is None or b.user_id != user_id:
            return None

        if category is not None:
            b.category = category
        if limit is not None:
            b.limit = float(limit)
        if period is not None:
            b.period = period
        if start_date is not None:
            b.start_date = _ensure_tz(start_date)
        if end_date is not None:
            b.end_date = _ensure_tz(end_date)

        b.updated_at = _utc_now()
        session.add(b)
        session.commit()
        session.refresh(b)
        return b


def delete_budget(budget_id: UUID, *, user_id: str) -> bool:
    with Session(engine) as session:
        b = session.get(Budget, budget_id)
        if b is None or b.user_id != user_id:
            return False
        session.delete(b)
        session.commit()
        return True


# ----------------------------
# Query helpers (DB-layer aggregations)
# ----------------------------
def sum_expenses(
    *,
    user_id: str,
    start: datetime,
    end: datetime,
    category: Optional[str] = None,
) -> float:
    start = _ensure_tz(start)
    end = _ensure_tz(end)

    stmt = select(func.coalesce(func.sum(Expense.amount), 0.0)).where(
        Expense.user_id == user_id,
        Expense.date >= start,
        Expense.date < end,
    )
    if category is not None:
        stmt = stmt.where(Expense.category == category)

    with Session(engine) as session:
        v = session.exec(stmt).one()
        return float(v or 0.0)


# ----------------------------
# User CRUD
# ----------------------------

def add_user(
    *,
    username: str,
    password_hash: str,
) -> User:
    user_id = str(uuid4())
    u = User(
        id=user_id,
        username=username,
        password_hash=password_hash,
        created_at=_utc_now(),
        updated_at=_utc_now(),
    )
    with Session(engine) as session:
        session.add(u)
        session.commit()
        session.refresh(u)
        return u


def get_user_by_id(user_id: str) -> Optional[User]:
    with Session(engine) as session:
        return session.get(User, user_id)


def get_user_by_username(username: str) -> Optional[User]:
    stmt = select(User).where(User.username == username)
    with Session(engine) as session:
        return session.exec(stmt).first()


def update_user_profile(
    user_id: str,
    *,
    location: Optional[str] = None,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    monthly_income: Optional[float] = None,
    budget_goal: Optional[float] = None,
    is_onboarded: Optional[bool] = None,
) -> Optional[User]:
    with Session(engine) as session:
        u = session.get(User, user_id)
        if u is None:
            return None

        if location is not None:
            u.location = location
        if latitude is not None:
            u.latitude = latitude
        if longitude is not None:
            u.longitude = longitude
        if monthly_income is not None:
            u.monthly_income = float(monthly_income)
        if budget_goal is not None:
            u.budget_goal = float(budget_goal)
        if is_onboarded is not None:
            u.is_onboarded = is_onboarded

        u.updated_at = _utc_now()
        session.add(u)
        session.commit()
        session.refresh(u)
        return u


def budget_spent(*, user_id: str, budget: Budget) -> float:
    return sum_expenses(
        user_id=user_id,
        start=budget.start_date,
        end=budget.end_date,
        category=budget.category,
    )


# ----------------------------
# Seed Data
# ----------------------------

def seed_database() -> None:
    """
    Clear the database and populate with sample data.
    """
    with Session(engine) as session:
        # Clear existing data
        print("Clearing existing data...")
        session.query(Expense).delete()
        session.query(Budget).delete()
        session.query(Token).delete()
        session.query(User).delete()
        session.commit()

        # Create sample users
        import hashlib
        import secrets
        
        def hash_password(password: str) -> str:
            salt = secrets.token_hex(8)
            pwd_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
            return f"{salt}${pwd_hash.hex()}"

        user1 = User(
            id="user1",
            username="ethan",
            password_hash=hash_password("password"),
            location="San Francisco, USA",
            latitude=37.7749,
            longitude=-122.4194,
            monthly_income=5000.0,
            budget_goal=1500.0,
            is_onboarded=True,
        )
        
        user2 = User(
            id="user2",
            username="ethan2",
            password_hash=hash_password("password"),
            location="New York, USA",
            latitude=40.7128,
            longitude=-74.0060,
            monthly_income=6000.0,
            budget_goal=2000.0,
            is_onboarded=True,
        )

        session.add(user1)
        session.add(user2)
        session.commit()

        # Get current time for tokens and expenses
        now = _utc_now()
        from datetime import timedelta

        # Create tokens for users (expires in 30 days)
        token1 = Token(
            token="demo_token_user1_12345",
            user_id="user1",
            expires_at=now + timedelta(days=30),
        )
        
        token2 = Token(
            token="demo_token_user2_67890",
            user_id="user2",
            expires_at=now + timedelta(days=30),
        )

        session.add(token1)
        session.add(token2)
        session.commit()

        # Create sample expenses for user1
        
        expenses = [
            Expense(
                title="Groceries",
                amount=120.50,
                category="Grocery",
                date=now - timedelta(days=2),
                description="Weekly groceries",
                user_id="user1",
            ),
            Expense(
                title="Gas",
                amount=50.00,
                category="Transportation",
                date=now - timedelta(days=3),
                description="Car fuel",
                user_id="user1",
            ),
            Expense(
                title="Netflix Subscription",
                amount=15.99,
                category="Entertainment",
                date=now - timedelta(days=5),
                description="Monthly subscription",
                user_id="user1",
            ),
            Expense(
                title="Restaurant Dinner",
                amount=85.75,
                category="Food & Dining",
                date=now - timedelta(days=1),
                description="Dinner with friends",
                user_id="user1",
            ),
            Expense(
                title="Gym Membership",
                amount=50.00,
                category="Health & Fitness",
                date=now - timedelta(days=7),
                description="Monthly gym",
                user_id="user1",
            ),
            Expense(
                title="Online Shopping",
                amount=75.00,
                category="Shopping",
                date=now - timedelta(days=4),
                description="Clothes and accessories",
                user_id="user1",
            ),
        ]

        for expense in expenses:
            session.add(expense)
        
        session.commit()

        # Create sample budgets for user1
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        month_end = (month_start + timedelta(days=31)).replace(day=1) - timedelta(seconds=1)

        # Split user1's budget goal into category budgets
        total_budget = user1.budget_goal  # 1500.0
        budget_proportions = {
            "Food & Dining": 0.30,      # 30% = $450
            "Grocery": 0.20,             # 20% = $300
            "Transportation": 0.20,      # 20% = $300
            "Shopping / Personal": 0.15, # 15% = $225
            "Lifestyle": 0.15,           # 15% = $225
        }
        
        budgets = []
        for category, proportion in budget_proportions.items():
            budgets.append(Budget(
                category=category,
                limit=total_budget * proportion,
                period="monthly",
                start_date=month_start,
                end_date=month_end,
                user_id="user1",
            ))

        for budget in budgets:
            session.add(budget)
        
        session.commit()

        print("✅ Database seeded successfully!")
        print(f"   Created 2 users, 6 expenses, {len(budgets)} budgets")

