import requests
import os
from .constants import EXPENSE_CATEGORIES

def llm_parse_product_price(prompt):
    url = "https://api.dedaluslabs.ai/v1/chat/completions"

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
                    "price": {"type": "number"},
                    "category": {"type": "string", "enum": EXPENSE_CATEGORIES}
                },
                "required": ["product", "price", "category"]
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

def llm_roast_budget(budget_info: str):
    url = "https://api.dedaluslabs.ai/v1/chat/completions"

    payload = {
        "model": "openai/gpt-4o",
        "messages": [
            {"role": "system", "content": "You are a sarcastic assistant."},
            {"role": "user", "content": budget_info}
        ],
        "instructions": "You are a sarcastic assistant. Roast the user's budget in a humorous way to encourage them to save more within 2 sentences.",
        "response_format": {
            "type": "text",
        }
    }

    headers = {
        "Authorization": f"Bearer {os.getenv('DEDALUS_API_KEY')}",
        "Content-Type": "application/json"
    }

    response = requests.post(url, json=payload, headers=headers)

    text = response.json().get("choices", [{}])[0].get("message", {}).get("content", "")
    print("LLM Roast Response:", text)

    return response.json()

if __name__ == "__main__":
    # Test the functions
    # test_prompt = "I bought a coffee for $4 and a sandwich for $6."
    # print(llm_parse_product_price(test_prompt))

    test_budget_info = "Budget exceeds: $200 on Food & Dining, $150 on Entertainment, and $300 on Shopping / Personal."
    print(llm_roast_budget(test_budget_info))