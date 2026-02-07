import requests
from flask import Blueprint, request, jsonify
from dotenv import load_dotenv
import os
import json
import base64
import io
from datetime import datetime
from PIL import Image
from . import utils
from . import constants
from . import database as db
from . import financial_helper as fin

ocr_bp = Blueprint('ocr', __name__)
load_dotenv()

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

DETECT_PRODUCT_AND_PRICE_PROMPT = \
    "The categories are: " + ", ".join(constants.EXPENSE_CATEGORIES) + ". " \
    "Detect the products bought, the prices (in dollars), and the categories from the following text," \
    "and return the result in a JSON format with a list of items, each containing" \
    "'product', 'price', and 'category' fields: \"{}\""


def process_receipt_file(filepath: str) -> list[dict]:
    """
    共用邏輯：讀取 filepath -> 轉 PDF/Base64 -> Dedalus OCR -> LLM Parse
    回傳 items list (e.g. [{"product": "X", "price": 10}, ...])
    """
    # 1. 處理檔案並轉為 Base64 (統一轉為 PDF 格式以相容 Mistral OCR)
    filename_lower = filepath.lower()
    
    # 如果是圖片，轉檔為 PDF
    if filename_lower.endswith((".png", ".jpg", ".jpeg", ".webp")):
        # 開啟圖片
        image = Image.open(filepath)
        # 轉換為 RGB (預防 RGBA 轉 PDF 錯誤)
        if image.mode == 'RGBA':
            image = image.convert('RGB')
            
        # 儲存為 PDF bytes
        pdf_bytes = io.BytesIO()
        image.save(pdf_bytes, format='PDF')
        pdf_bytes.seek(0)
        file_content = pdf_bytes.read()
        mime_type = "application/pdf"
        
    elif filename_lower.endswith(".pdf"):
        with open(filepath, "rb") as f:
            file_content = f.read()
        mime_type = "application/pdf"
    else:
        raise ValueError("Unsupported file format")

    encoded_string = base64.b64encode(file_content).decode('utf-8')
    document_url = f"data:{mime_type};base64,{encoded_string}"
    
    print(f"[OCR] Processed file {filepath}, mime={mime_type}, base64 len={len(encoded_string)}")

    # 2. 呼叫 Dedalus OCR API
    dedalus_url = "https://api.dedaluslabs.ai/v1/ocr"
    headers = {
        "Authorization": f"Bearer {os.getenv('DEDALUS_API_KEY')}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "mistral-ocr-latest",
        "document": {
            "type": "document_url",
            "document_url": document_url
        }
    }

    ocr_response = requests.post(dedalus_url, headers=headers, json=payload, timeout=120.0)
    
    if ocr_response.status_code != 200:
        raise Exception(f"OCR API Error: {ocr_response.text}")

    ocr_json = ocr_response.json()
    
    # 整合所有頁面的 Markdown
    full_text = ""
    if "pages" in ocr_json:
        for page in ocr_json["pages"]:
            full_text += page.get("markdown", "") + "\n"
    else:
        full_text = json.dumps(ocr_json)

    # 3. 使用 LLM 解析由 OCR 取得的文字
    llm_response = utils.llm_parse_product_price(DETECT_PRODUCT_AND_PRICE_PROMPT.format(full_text))
    
    # 處理 LLM 回傳的內容
    content = llm_response.get("choices", [{}])[0].get("message", {}).get("content", "")
    # 去除可能存在的 markdown code block 標記
    content = content.replace("```json", "").replace("```", "").strip()
    
    parsed = json.loads(content)
    return parsed.get("items", [])


@ocr_bp.route("/upload_image", methods=["POST"])
def upload_image():
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]

    if file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    filepath = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filepath)

    try:
        items = process_receipt_file(filepath)
        return jsonify({"message": "Success", "path": filepath, "items": items}), 201
    except ValueError as ve:
        return jsonify({"error": str(ve)}), 400
    except Exception as e:
        return jsonify({"error": f"Process failed: {str(e)}"}), 500


@ocr_bp.route("/ocr_to_entry", methods=["POST"])
def ocr_to_entry():
    """
    End-to-End: Upload image -> OCR -> Save to DB
    Expects: 
      - multipart/form-data with 'file'
      - optional form fields: 'userId', 'date' (ISO string)
    """
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400
    
    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    filepath = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filepath)

    try:
        # 1. Run OCR pipeline
        items = process_receipt_file(filepath)

        print("add to db")
        # 2. Add to DB
        from .main import _get_auth_user
        user = _get_auth_user()
        if not user:
            return jsonify({"error": "Unauthorized"}), 401
        user_id = user.id

        date_str = request.form.get("date")
        if date_str:
            try:
                # remove Z if present for simpler parsing if python version < 3.7
                dt = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
            except ValueError:
                dt = datetime.utcnow()
        else:
            dt = datetime.utcnow()

        created_list = []
        for item in items:
            title = item.get("product", "Unknown")
            price_raw = item.get("price", 0.0)
            
            # Clean price just in case
            if isinstance(price_raw, str):
                try:
                    price_val = float(price_raw.replace("$", "").replace(",", ""))
                except:
                    price_val = 0.0
            else:
                price_val = float(price_raw)
            
            category = item.get("category", "Uncategorized")
            # Optional: validate category against constants.EXPENSE_CATEGORIES

            exp = db.add_expense(
                title=title,
                amount=price_val,
                category=category,
                date=dt,
                user_id=user_id,
                description="Imported from OCR (End-to-End)"
            )
            created_list.append(db.expense_to_json(exp))
        
        if user_id:
            db.get_user_by_id(user_id)
            budget_status = fin.evaluate_all_budget_goals(user_id=user_id)[0]

        return jsonify({
            "message": "Successfully scanned and saved expenses",
            "count": len(created_list),
            "expenses": created_list,
            "budgetStatus": budget_status
        }), 201

    except ValueError as ve:
        return jsonify({"error": str(ve)}), 400
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": f"End-to-end processing failed: {str(e)}"}), 500






if __name__ == "__main__":
    app.run(debug=True)