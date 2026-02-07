# backend/app.py
from __future__ import annotations

from datetime import datetime
from flask import Flask, request, jsonify
from dateutil.parser import isoparse  # pip install python-dateutil

from stats_helper import pie_expense_by_category, weekly_spend_series

app = Flask(__name__)

def _parse_dt(s: str | None) -> datetime | None:
    if not s:
        return None
    return isoparse(s)

@app.get("/stats/pie")
def stats_pie():
    user_id = request.args.get("userId")
    if not user_id:
        return jsonify({"error": "userId is required"}), 400

    start = _parse_dt(request.args.get("start"))
    end = _parse_dt(request.args.get("end"))
    top_n = int(request.args.get("topN", "5"))
    include_other = request.args.get("includeOther", "true").lower() == "true"

    data = pie_expense_by_category(
        user_id=user_id,
        start=start,
        end=end,
        top_n=top_n,
        include_other=include_other,
    )
    return jsonify(data)

@app.get("/stats/weekly")
def stats_weekly():
    user_id = request.args.get("userId")
    if not user_id:
        return jsonify({"error": "userId is required"}), 400

    weeks = int(request.args.get("weeks", "8"))
    category = request.args.get("category")  # optional

    data = weekly_spend_series(
        user_id=user_id,
        weeks=weeks,
        category=category,
    )
    return jsonify(data)

if __name__ == "__main__":
    app.run(debug=True, port=8000)
