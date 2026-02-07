import requests
import os

def llm_parse_product_price(prompt):
    url = "https://api.dedaluslabs.ai/v1/chat/completions"

    print(type(prompt))
    payload = {
        "model": "openai/gpt-4o-mini",
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": prompt}
        ],
        "system": "You are a helpful assistant.",
        "instructions": "You are a concise assistant.",
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "purchase_info",
                "schema": {
                "type": "object",
                "properties": {
                    "product": {"type": "string"},
                    "price": {"type": "number"}
                },
                "required": ["product", "price"]
            }
            }
        }
    }

    headers = {
        "Authorization": f"Bearer {os.getenv('DEDALUS_API_KEY')}",
        "Content-Type": "application/json"
    }

    response = requests.post(url, json=payload, headers=headers)

    return response.json()