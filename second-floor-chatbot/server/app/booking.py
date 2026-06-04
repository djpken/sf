"""訂位寫入 —— 目前為 MOCK(待與門市/訂位系統廠商溝通後再接真 API)。

要接真實系統時,只需把 submit_reservation() 的內部換成廠商 API 呼叫 +
Line/SMS 通知,對外介面(參數、回傳結構)維持不變,上層完全不用動。
"""

from __future__ import annotations

import random
import string


def _mock_booking_id() -> str:
    suffix = "".join(random.choices(string.ascii_uppercase + string.digits, k=6))
    return f"SF-{suffix}"


def submit_reservation(
    store: str,
    time: str,
    party_size: int,
    date: str | None = None,
    note: str | None = None,
) -> dict:
    """送出訂位。

    >>> MOCK <<< 目前不寫任何後台,只回傳模擬確認。
    接真系統時把以下 return 換成:廠商訂位 API 寫入 + 取得真實單號 + 發送通知。
    """
    return {
        "status": "confirmed",
        "booking_id": _mock_booking_id(),
        "store": store,
        "date": date or "今日",
        "time": time,
        "party_size": party_size,
        "note": note or "",
        "mock": True,
        "message": "（測試）訂位已模擬寫入,尚未串接真實門市系統。實際送出需待廠商 API。",
    }


# Provider 無關的工具宣告(中性 JSON schema)。各 provider 自行轉成
# Gemini 的 types.Tool 或 OpenAI 的 tools 格式。
RESERVATION_TOOL_SPEC = {
    "name": "submit_reservation",
    "description": (
        "送出訂位到門市系統。只有在已確認『門市、時段、人數』且客人明確表示要送出"
        "（例如說『送出』『確認訂位』）後才呼叫;資訊不齊或客人還在猶豫時不要呼叫。"
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "store": {"type": "string", "description": "門市名稱,例如 敦南店"},
            "time": {"type": "string", "description": "時段,24 小時制 HH:MM,15 分鐘刻度"},
            "party_size": {"type": "integer", "description": "用餐人數"},
            "date": {"type": "string", "description": "日期,例如 今晚 / 2026-06-10(可省略)"},
            "note": {"type": "string", "description": "備註,如慶生、忌口(可省略)"},
        },
        "required": ["store", "time", "party_size"],
    },
}

# name -> callable 註冊表
TOOLS = {"submit_reservation": submit_reservation}

# 注入 system prompt 的工具使用守則
TOOL_GUIDANCE = """

## 訂位寫入工具(重要)

你有一個 submit_reservation 工具可以把訂位送進系統。

- 當「門市、時段、人數」都齊全,且客人明確說要送出（如「送出」「確認」「正確」）時,
  你**必須呼叫 submit_reservation 工具**。絕對不要只用文字說「已為您記錄」而不呼叫工具。
- 資訊不齊或客人還在猶豫時,用對話補齊,先不要呼叫。
- 工具會回傳一個 booking_id。你**只能**在拿到工具回傳後,用那個真實的 booking_id 跟客人確認;
  沒有 booking_id 就代表你還沒送出,不可以假裝送出成功。
- 目前是測試模擬(尚未接真實門市系統),確認時要提醒客人「這是測試訂位、實際送出待系統串接」。"""
