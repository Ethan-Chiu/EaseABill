from flask import Flask, request, jsonify
from datetime import datetime, timedelta
import hashlib
import secrets
import db

from speech import speech_bp

app = Flask(__name__)

# Simple in-memory token store (use Redis/DB in production)
_tokens = {}

# register blueprints
app.register_blueprint(speech_bp, url_prefix="/api/speech")

def _hash_password(password: str) -> str:
    """Hash password with salt"""
    salt = secrets.token_hex(8)
    pwd_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
    return f"{salt}${pwd_hash.hex()}"


def _verify_password(password: str, password_hash: str) -> bool:
    """Verify password against hash"""
    try:
        salt, pwd_hash = password_hash.split('$')
        return hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000).hex() == pwd_hash
    except:
        return False


def _generate_token() -> str:
    """Generate a simple token"""
    return secrets.token_urlsafe(32)


def _verify_token(token: str) -> tuple[bool, str | None]:
    """Verify token and return (is_valid, user_id)"""
    if token in _tokens:
        user_id, expires = _tokens[token]
        if datetime.utcnow() < expires:
            return True, user_id
        else:
            del _tokens[token]
    return False, None


def _get_auth_user():
    """Get authenticated user from request header"""
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return None
    
    token = auth_header[7:]
    is_valid, user_id = _verify_token(token)
    if not is_valid:
        return None
    
    user = db.get_user_by_id(user_id)
    return user


# ==================== Auth Endpoints ====================

@app.route("/api/auth/register", methods=["POST"])
def register():
    """Register a new user"""
    data = request.get_json()
    
    username = data.get('username', '').strip()
    password = data.get('password', '')
    
    if not username or not password:
        return jsonify({"message": "Username and password required"}), 400
    
    if len(username) < 3:
        return jsonify({"message": "Username must be at least 3 characters"}), 400
    
    if len(password) < 6:
        return jsonify({"message": "Password must be at least 6 characters"}), 400
    
    # Check if user exists
    if db.get_user_by_username(username):
        return jsonify({"message": "Username already exists"}), 409
    
    # Create user
    password_hash = _hash_password(password)
    user = db.add_user(username=username, password_hash=password_hash)
    
    # Generate token
    token = _generate_token()
    _tokens[token] = (user.id, datetime.utcnow() + timedelta(days=30))
    
    return jsonify({
        "token": token,
        "user": db.user_to_json(user)
    }), 201


@app.route("/api/auth/login", methods=["POST"])
def login():
    """Login user with username and password"""
    data = request.get_json()
    
    username = data.get('username', '').strip()
    password = data.get('password', '')
    
    if not username or not password:
        return jsonify({"message": "Username and password required"}), 400
    
    # Find user
    user = db.get_user_by_username(username)
    if not user or not _verify_password(password, user.password_hash):
        return jsonify({"message": "Invalid credentials"}), 401
    
    # Generate token
    token = _generate_token()
    _tokens[token] = (user.id, datetime.utcnow() + timedelta(days=30))
    
    return jsonify({
        "token": token,
        "user": db.user_to_json(user)
    }), 200


@app.route("/api/user/profile", methods=["PUT"])
def update_profile():
    """Update user profile (requires auth)"""
    user = _get_auth_user()
    if not user:
        return jsonify({"message": "Unauthorized"}), 401
    
    data = request.get_json()
    
    updated_user = db.update_user_profile(
        user.id,
        location=data.get('location'),
        latitude=data.get('latitude'),
        longitude=data.get('longitude'),
        monthly_income=data.get('monthlyIncome'),
        budget_goal=data.get('budgetGoal'),
        is_onboarded=data.get('isOnboarded'),
    )
    
    if not updated_user:
        return jsonify({"message": "Failed to update profile"}), 500
    
    return jsonify(db.user_to_json(updated_user)), 200


# ==================== Health Check ====================

@app.route("/")
def hello_world():
    return "<p>EaseABill API is running!</p>"


@app.route("/api/health", methods=["GET"])
def health_check():
    return jsonify({"status": "ok"}), 200


# ==================== Expense Endpoints (TODO) ====================

@app.route("/api/expenses", methods=["GET"])
def get_expenses():
    user = _get_auth_user()
    if not user:
        return jsonify({"message": "Unauthorized"}), 401
    
    expenses = db.list_expenses(user_id=user.id)
    return jsonify([db.expense_to_json(e) for e in expenses]), 200


# Initialize database
if __name__ == "__main__":
    db.init_db()
    # Only seed if SEED_DB environment variable is set to "true"
    import os
    if os.getenv("SEED_DB", "").lower() == "true":
        db.seed_database()
    app.run(debug=True, host='0.0.0.0', port=8000)