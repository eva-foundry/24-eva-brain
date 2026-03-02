"""
Direct API test of marco-sandbox-openai-v2 using Python and openai package
"""
import os
import sys
import json
from datetime import datetime
import subprocess

# Get API key from Azure CLI
print("Getting API key from Azure CLI...")
result = subprocess.run(
    [
        "az", "cognitiveservices", "account", "keys", "list",
        "--name", "marco-sandbox-openai-v2",
        "--resource-group", "EsDAICoE-Sandbox"
    ],
    capture_output=True,
    text=True
)

if result.returncode != 0:
    print(f"[FAIL] Could not get API key: {result.stderr}")
    sys.exit(1)

keys = json.loads(result.stdout)
api_key = keys["key1"]
print("[PASS] API key retrieved")

# Test using openai package
try:
    from openai import AzureOpenAI
except ImportError:
    print("[WARN] openai package not installed, trying to import...")
    subprocess.run([sys.executable, "-m", "pip", "install", "openai"], check=True)
    from openai import AzureOpenAI

print("\n[INFO] Testing GPT-5.1 chat completion...")
print("[INFO] Endpoint: https://marco-sandbox-openai-v2.openai.azure.com/")
print("[INFO] Deployment: gpt-5.1-chat")

client = AzureOpenAI(
    api_key=api_key,
    api_version="2024-02-15-preview",
    azure_endpoint="https://marco-sandbox-openai-v2.openai.azure.com/"
)

test_prompt = "What is 2+2? Answer in one sentence."
print(f"\n[INFO] Sending request: '{test_prompt}'")

try:
    response = client.chat.completions.create(
        model="gpt-5.1-chat",
        messages=[
            {"role": "system", "content": "You are a helpful AI assistant."},
            {"role": "user", "content": test_prompt}
        ],
        max_tokens=100,
        temperature=0.7
    )
    
    print("\n[PASS] API responded successfully!")
    print("\nResponse:")
    print("----------------------------------------")
    print(response.choices[0].message.content)
    print("----------------------------------------")
    print(f"\n[INFO] Model: {response.model}")
    print(f"[INFO] Usage: {response.usage.prompt_tokens} prompt + {response.usage.completion_tokens} completion = {response.usage.total_tokens} total tokens")
    print(f"[INFO] Finish reason: {response.choices[0].finish_reason}")
    
    # Save results
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    output_dir = os.path.join(os.path.dirname(__file__), "..", "runs", "openai-tests")
    os.makedirs(output_dir, exist_ok=True)
    
    result_data = {
        "timestamp": timestamp,
        "service": "marco-sandbox-openai-v2",
        "deployment": "gpt-5.1-chat",
        "endpoint": "https://marco-sandbox-openai-v2.openai.azure.com/",
        "prompt": test_prompt,
        "response": response.choices[0].message.content,
        "model": response.model,
        "usage": {
            "prompt_tokens": response.usage.prompt_tokens,
            "completion_tokens": response.usage.completion_tokens,
            "total_tokens": response.usage.total_tokens
        },
        "success": True
    }
    
    report_path = os.path.join(output_dir, f"openai-test-{timestamp}.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(result_data, f, indent=2)
    
    print(f"\n[SUCCESS] Test passed - GPT-5.1 is responding correctly")
    print(f"[INFO] Results saved to: {report_path}")
    sys.exit(0)
    
except Exception as e:
    print(f"\n[FAIL] API call failed: {e}")
    print(f"[ERROR] {type(e).__name__}: {str(e)}")
    sys.exit(1)
