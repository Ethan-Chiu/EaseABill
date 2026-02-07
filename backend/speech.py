from flask import Flask, request, jsonify, blueprints
from dedalus_labs import Dedalus
from dotenv import load_dotenv
import requests
import os
import json
import datetime

from . import utils
from . import constants
from . import database as db

# make a blueprints
speech_bp = blueprints.Blueprint("speech", __name__)

load_dotenv()

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

DETECT_PRODUCT_AND_PRICE_PROMPT = \
    "The categories are: " + ", ".join(constants.EXPENSE_CATEGORIES) + ". " \
    "Detect the products bought, the prices (in dollars), and the categories from the following text," \
    "and return the result in a JSON format with a list of items, each containing" \
    "'product', 'price', and 'category' fields: \"{}\""

# A post request to the /speech endpoint will trigger the speech recognition process
@speech_bp.route("/upload_audio", methods=["POST"])
def upload_audio():
    print("Received request to /upload_audio")
    # documentation
    """
    Upload an audio file for speech recognition. The audio will be transcribed using Dedalus Labs' API,
    and the transcript will be parsed to extract product names, prices, and categories. The extracted
    information will be stored as expenses in the database.
    Expected form data:
        - user_id: the ID of the user uploading the audio
        - file: the audio file to be uploaded (e.g., .mp3, .wav)
    Response:
    {
        "message": "Success",
        "path": "path/to/uploaded/file",
        "items": [
            {
                "product": "coffee",
                "price": 4.0,
                "category": "Food & Dining"
            },
            ...
        ]
    }
    """
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]

    if not file.filename:
        return jsonify({"error": "Empty filename"}), 400

    filepath = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filepath)

    url = "https://api.dedaluslabs.ai/v1/audio/transcriptions"

    files = { "file": (file.filename, open(filepath, "rb")) }
    payload = {
        "model": "openai/whisper-1",
        "language": "en",
        "response_format": "text",
        # "temperature": "123"
    }
    headers = {"Authorization": f"Bearer {os.getenv('DEDALUS_API_KEY')}"}

    response = requests.post(url, data=payload, files=files, headers=headers)

    llm_response = utils.llm_parse_product_price(DETECT_PRODUCT_AND_PRICE_PROMPT.format(response.text))
    parsed = json.loads(llm_response.get("choices", [{}])[0].get("message", {}).get("content", ""))

    for expense in parsed.get("items", []):
        e = db.add_expense(
            user_id=request.form.get("user_id"),
            title=expense["product"],
            amount=expense["price"],
            category=expense["category"],
            date=datetime.datetime.now()
        )

    return jsonify({"message": "Success", "path": filepath, "items": parsed["items"]}), 201
