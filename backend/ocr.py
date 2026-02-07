import requests
from flask import Blueprint, request, jsonify
from dotenv import load_dotenv
import os
import json
import base64
import io
from PIL import Image
import utils

ocr_bp = Blueprint('ocr', __name__)
load_dotenv()

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

DETECT_PRODUCT_AND_PRICE_FROM_IMAGE_PROMPT = \
    "Detect the products bought and the prices from the following receipt text (OCR result), and " \
    "return the result in a JSON format with a list of items, each containing" \
    "'product' and 'price','' fields: \"{}\""

@ocr_bp.route("/upload-image", methods=["POST"])
def upload_image():
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]

    if file.filename == "":
        return jsonify({"error": "Empty filename"}), 400

    filepath = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filepath)

    # 1. 處理檔案並轉為 Base64 (統一轉為 PDF 格式以相容 Mistral OCR)
    try:
        filename_lower = file.filename.lower()
        
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
            return jsonify({"error": "Unsupported file format"}), 400

        encoded_string = base64.b64encode(file_content).decode('utf-8')
        document_url = f"data:{mime_type};base64,{encoded_string}"
        
        # 除錯：印出檔頭
        print(f"Sending document as: {mime_type}, base64 start: {document_url[:30]}...")

    except Exception as e:
        return jsonify({"error": f"File processing failed: {str(e)}"}), 500

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

    try:
        ocr_response = requests.post(dedalus_url, headers=headers, json=payload, timeout=120.0)
        
        if ocr_response.status_code != 200:
            return jsonify({"error": f"OCR API Error: {ocr_response.text}"}), ocr_response.status_code

        ocr_json = ocr_response.json()
        
        # 整合所有頁面的 Markdown
        full_text = ""
        if "pages" in ocr_json:
            for page in ocr_json["pages"]:
                full_text += page.get("markdown", "") + "\n"
        else:
            full_text = json.dumps(ocr_json)

        # 3. 使用 LLM 解析由 OCR 取得的文字
        llm_response = utils.llm_parse_product_price(DETECT_PRODUCT_AND_PRICE_FROM_IMAGE_PROMPT.format(full_text))
        
        # 處理 LLM 回傳的內容
        content = llm_response.get("choices", [{}])[0].get("message", {}).get("content", "")
        # 去除可能存在的 markdown code block 標記
        content = content.replace("```json", "").replace("```", "").strip()
        
        parsed = json.loads(content)

        return jsonify({"message": "Success", "path": filepath, "items": parsed.get("items", [])}), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True)