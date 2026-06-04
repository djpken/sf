"""快速檢查 Gemini key 是否有效且還有額度。

用法:
  ./.venv/bin/python check_key.py            # 讀 .env 的 GEMINI_API_KEY
  ./.venv/bin/python check_key.py <你的key>   # 直接帶 key 測

回報:
  ✅ 有效且有額度   ⚠️ 額度/流量上限(429)   ❌ 認證失敗   ❌ 其他錯誤
"""

import os
import sys

from dotenv import load_dotenv
from google import genai

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

key = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("GEMINI_API_KEY", "")
model = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash-lite")

if not key:
    print("❌ 沒有 key(請帶參數或設 server/.env 的 GEMINI_API_KEY)")
    sys.exit(1)

print(f"測試 key: {key[:8]}…  model: {model}")
try:
    client = genai.Client(api_key=key)
    resp = client.models.generate_content(model=model, contents="ping")
    print("✅ 有效且有額度。回應:", (resp.text or "").strip()[:40])
except Exception as exc:  # noqa: BLE001
    s = str(exc)
    if "429" in s or "RESOURCE_EXHAUSTED" in s or "quota" in s.lower():
        print("⚠️ 額度/流量上限(429)。等 1 分鐘再試;若持續 → 每日額度用完或專案沒開帳單。")
    elif any(k in s for k in ("401", "403", "API key not valid", "PERMISSION_DENIED", "API_KEY_INVALID")):
        print("❌ 認證失敗。key 無效或無權限,請到 AI Studio 確認(標準 key 是 AIza... 開頭)。")
    else:
        print("❌ 其他錯誤:", s[:160])
    sys.exit(2)
