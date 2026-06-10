"""訂位寫入 —— 目前為 MOCK(待與門市/訂位系統廠商溝通後再接真 API)。

要接真實系統時,只需把 submit_reservation() 的內部換成廠商 API 呼叫 +
Line/SMS 通知,對外介面(參數、回傳結構)維持不變,上層完全不用動。
"""

from __future__ import annotations

import hashlib
import json
import math
import random
import string
from pathlib import Path

_STORES_FILE = Path(__file__).parent / "data" / "stores.json"
STORE_INFO: dict[str, dict] = json.loads(_STORES_FILE.read_text(encoding="utf-8"))

_REQUIRED_STORE_KEYS = {"address", "phone", "hours"}
for _store_name, _store_data in STORE_INFO.items():
    _missing = _REQUIRED_STORE_KEYS - set(_store_data)
    if _missing:
        raise ValueError(f"stores.json: {_store_name!r} 缺少必要欄位: {_missing}")


def _mock_booking_id() -> str:
    suffix = "".join(random.choices(string.ascii_uppercase + string.digits, k=6))
    return f"SF-{suffix}"


# ─── MOCK 空位/客滿判定 ──────────────────────────────────────────────────────
# 不接真實訂位系統,用「決定性偽隨機」假裝某些時段客滿:同一組(門市/日期/時段/人數)
# 永遠得到一致結果,所以「查到客滿就一定訂不到、重試也不會跳來跳去」,demo 穩定。
# 熱門時段(晚餐 18–20 點)與大桌(≥6 人)客滿機率較高,其餘多半有位。

_PEAK_HOURS = {18, 19, 20}


def _slot_score(store: str, date: str | None, time: str, party_size: int | None) -> int:
    key = f"{store}|{date or '今日'}|{time}|{party_size or 2}"
    return int(hashlib.md5(key.encode("utf-8")).hexdigest(), 16) % 100


def _parse_hm(time: str | None) -> tuple[int, int] | None:
    try:
        h, m = str(time).split(":")[:2]
        return int(h), int(m)
    except (ValueError, AttributeError):
        return None


def _is_slot_full(store: str, date: str | None, time: str, party_size: int | None) -> bool:
    """這個時段是否客滿(MOCK,決定性)。"""
    score = _slot_score(store, date, time, party_size)
    hm = _parse_hm(time)
    threshold = 15  # 基礎約 15% 客滿
    if hm and hm[0] in _PEAK_HOURS:
        threshold += 25  # 熱門時段更容易滿
    if (party_size or 0) >= 6:
        threshold += 20  # 大桌更難訂
    return score < threshold


def _suggest_slots(store: str, date: str | None, party_size: int | None, around: str) -> list[str]:
    """客滿時,挑幾個附近且「目前有位」的時段建議(限營業 11:00–22:00)。"""
    candidates: list[str] = []
    hm = _parse_hm(around)
    if hm:
        base = hm[0] * 60 + hm[1]
        for delta in (30, -30, 60, -60, 90, -90):
            total = base + delta
            if not (11 * 60 <= total <= 22 * 60):
                continue
            t = f"{total // 60:02d}:{total % 60:02d}"
            if not _is_slot_full(store, date, t, party_size):
                candidates.append(t)
    for t in ("17:30", "21:00", "14:00", "13:00"):
        if not _is_slot_full(store, date, t, party_size):
            candidates.append(t)
    # 去重、排除原時段、上限 3 個
    out: list[str] = []
    for t in candidates:
        if t != around and t not in out:
            out.append(t)
        if len(out) >= 3:
            break
    return out


# 記憶體訂位表(MOCK):成功的訂位暫存在這裡,讓 lookup_reservation 在同一個 server
# 執行期間查得到。重啟即清空 —— 這只是假裝有後台,接真系統時改成廠商 API 查詢。
_RESERVATIONS: dict[str, dict] = {}


def submit_reservation(
    store: str,
    time: str,
    party_size: int,
    date: str | None = None,
    note: str | None = None,
) -> dict:
    """送出訂位。

    >>> MOCK <<< 不寫任何真實後台。可能「客滿訂不到」(status=failed),否則回模擬確認單。
    接真系統時把成功分支換成:廠商訂位 API 寫入 + 取得真實單號 + 發送通知;
    客滿/失敗分支換成廠商回傳的錯誤狀態即可,對外結構不變。
    """
    if _is_slot_full(store, date, time, party_size):
        return {
            "status": "failed",
            "reason": "full",
            "store": store,
            "date": date or "今日",
            "time": time,
            "party_size": party_size,
            "note": note or "",
            "alternatives": _suggest_slots(store, date, party_size, time),
            "mock": True,
            "message": "（測試）這個時段剛好客滿,訂位未成立。可改其他時段再送出。",
        }
    booking_id = _mock_booking_id()
    record = {
        "status": "confirmed",
        "booking_id": booking_id,
        "store": store,
        "date": date or "今日",
        "time": time,
        "party_size": party_size,
        "note": note or "",
        "mock": True,
        "message": "（測試）訂位已模擬寫入,尚未串接真實門市系統。實際送出需待廠商 API。",
    }
    _RESERVATIONS[booking_id] = record
    return record


def check_availability(
    store: str,
    time: str,
    date: str | None = None,
    party_size: int = 2,
) -> dict:
    """查詢某門市某時段是否還有空位(MOCK,不會真的訂位)。

    客滿時附上其他可訂時段建議。與 submit_reservation 共用同一套客滿判定,
    所以「查到有位 → 送出就會成功」「查到客滿 → 送出就會失敗」結果一致。
    """
    full = _is_slot_full(store, date, time, party_size)
    return {
        "store": store,
        "date": date or "今日",
        "time": time,
        "party_size": party_size,
        "available": not full,
        "alternatives": _suggest_slots(store, date, party_size, time) if full else [],
        "mock": True,
    }


def lookup_reservation(booking_id: str) -> dict:
    """用訂位單號查詢既有訂位明細(MOCK,查記憶體訂位表)。"""
    bid = (booking_id or "").strip().upper()
    record = _RESERVATIONS.get(bid)
    if record:
        return {"found": True, **record}
    return {
        "found": False,
        "booking_id": bid,
        "mock": True,
        "message": "（測試）查無此訂位單號。請確認單號是否正確;若是重啟前或更早的單,模擬資料已清空。",
    }


def show_store_card(store: str) -> dict:
    """顯示門市資訊卡(terminal 工具,不回模型,直接送前端)。"""
    info = STORE_INFO.get(store, {})
    return {"store": store, **info}


# ─── 定位 → 最近門市 ──────────────────────────────────────────────────────────

def _haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """兩點間球面距離(公里)。"""
    r = 6371.0  # 地球半徑 km
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def nearest_stores(lat: float, lng: float, k: int = 3) -> list[tuple[str, float]]:
    """依使用者座標,回傳最近 k 家門市 [(門市名, 距離km), ...]。"""
    ranked = [
        (name, _haversine(lat, lng, info["lat"], info["lng"]))
        for name, info in STORE_INFO.items()
        if "lat" in info and "lng" in info
    ]
    ranked.sort(key=lambda pair: pair[1])
    return ranked[:k]


def build_location_hint(lat: float, lng: float, k: int = 3) -> str:
    """組出要注入 system prompt 的「最近門市」提示區塊。"""
    nearest = nearest_stores(lat, lng, k)
    if not nearest:
        return ""
    lines = []
    for name, dist in nearest:
        addr = STORE_INFO.get(name, {}).get("address", "")
        lines.append(f"- {name}(約 {dist:.1f} 公里) {addr}")
    return (
        "\n\n## 客人目前位置附近的門市(由近到遠)\n"
        + "\n".join(lines)
        + "\n已取得客人所在位置。當客人要訂位或詢問門市時,**預設直接推薦上面最近的門市**,"
        "不要再反問客人在哪。若客人明確指定其他城市/區域,則尊重客人的選擇。"
    )


def propose_followups(questions: list | None = None, statements: list | None = None) -> dict:
    """產生這則回覆的建議追問,分兩類:

    - ask : 客人可能想「問」的資訊查詢句(例:有素食嗎?)
    - say : 客人可能想「說/做」的意圖句(例:我想訂位、幫我配三人份)

    這是個 *terminal* 工具:結果不需餵回模型、也不該為它多起一輪 generate
    (見 provider 的 terminal 處理)。防禦性清理:去空白、濾非字串、各類上限 3 個。
    """
    def _clean(xs: list | None) -> list:
        return [q.strip() for q in (xs or []) if isinstance(q, str) and q.strip()][:3]

    return {"ask": _clean(questions), "say": _clean(statements)}


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

# 建議追問工具。terminal=True → provider 收到後 yield 即結束,不接回對話、不多起一輪
# (省 LLM 呼叫,不加重 429 配額壓力)。
FOLLOWUPS_TOOL_SPEC = {
    "name": "propose_followups",
    "description": (
        "在『每一則回答的結尾』呼叫,提供客人可能會想接著互動的句子,讓他一鍵點選。分兩類:\n"
        "- questions(你可能想問):資訊查詢句,例如『有素食嗎?』『招牌是什麼?』\n"
        "- statements(你可能想說):行動/意圖句,例如『我想訂位』『幫我配三人份』『改一份不要辣』\n"
        "兩類加起來 2-4 句即可(不必兩類都給);每句使用與你的回覆相同的語言、站在客人立場第一人稱、"
        "貼合你剛剛的回答、≤ 16 字。唯一例外:這一回合你呼叫了 submit_reservation 時不要呼叫本工具。"
    ),
    "terminal": True,
    "parameters": {
        "type": "object",
        "properties": {
            "questions": {
                "type": "array",
                "items": {"type": "string"},
                "description": "客人可能想『問』的資訊查詢句(使用與回覆相同的語言、第一人稱、≤ 16 字)",
            },
            "statements": {
                "type": "array",
                "items": {"type": "string"},
                "description": "客人可能想『說/做』的行動意圖句(使用與回覆相同的語言、第一人稱、≤ 16 字)",
            },
        },
    },
}

CHECK_AVAILABILITY_TOOL_SPEC = {
    "name": "check_availability",
    "description": (
        "查詢某門市、某時段是否還有空位可訂(只是查詢,不會真的訂位)。\n"
        "觸發時機:客人問『X 時段還有位嗎/訂得到嗎』,或在你要呼叫 submit_reservation"
        "送出訂位之前想先確認該時段有沒有位時。\n"
        "會回傳該時段是否可訂;若客滿會附上其他可訂時段。客滿時請據此建議客人改時段,不要硬送出。"
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "store": {"type": "string", "description": "門市名稱,例如 敦南店"},
            "time": {"type": "string", "description": "想查的時段,24 小時制 HH:MM,15 分鐘刻度"},
            "date": {"type": "string", "description": "日期,例如 今晚 / 2026-06-10(可省略)"},
            "party_size": {"type": "integer", "description": "用餐人數(可省略,預設 2)"},
        },
        "required": ["store", "time"],
    },
}

LOOKUP_RESERVATION_TOOL_SPEC = {
    "name": "lookup_reservation",
    "description": (
        "用訂位單號查詢既有訂位的明細(門市、日期、時段、人數、狀態)。\n"
        "觸發時機:客人提供訂位單號(格式 SF-XXXXXX)、想確認或回顧自己訂的位時呼叫。\n"
        "查無此單時,提醒客人確認單號是否正確。"
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "booking_id": {"type": "string", "description": "訂位單號,格式 SF-XXXXXX"},
        },
        "required": ["booking_id"],
    },
}

STORE_CARD_TOOL_SPEC = {
    "name": "show_store_card",
    "description": (
        "顯示門市資訊卡(地址、電話、營業時間、特色標籤)。"
        "觸發時機:\n"
        "1. 訂位流程中客人確認了某家門市後(在詢問時段/人數之前),呼叫一次。\n"
        "2. 客人直接詢問某家門市的地址、電話、時間等資訊時。\n"
        "同一輪對話中同一家門市只呼叫一次;若已呼叫過 submit_reservation 則不再呼叫本工具。"
    ),
    "terminal": True,
    "parameters": {
        "type": "object",
        "properties": {
            "store": {"type": "string", "description": "門市名稱,例如 敦南店"},
        },
        "required": ["store"],
    },
}

# name -> callable 註冊表
TOOLS = {
    "submit_reservation": submit_reservation,
    "check_availability": check_availability,
    "lookup_reservation": lookup_reservation,
    "show_store_card": show_store_card,
    "propose_followups": propose_followups,
}

# 注入 system prompt 的工具使用守則
TOOL_GUIDANCE = """

## 門市資訊卡工具

你有一個 show_store_card 工具可以在對話中顯示門市卡片（地址、電話、時間）。
- 訂位流程中,客人確認要去某家門市後(尚未確認時段/人數前),呼叫一次。
- 客人直接問某家門市的位置、電話或時間時,也呼叫。
- 同一輪對話中同一家門市只呼叫一次;呼叫過 submit_reservation 後不再呼叫本工具。

## 查空位工具(check_availability)

你有一個 check_availability 工具可以查某門市某時段「還有沒有位」(只查詢、不會訂位)。
- 客人問「X 時段還有位嗎/訂得到嗎」,或你要送出訂位前想先確認時,呼叫它。
- 工具回傳 available=true/false。客滿(available=false)時會附 alternatives 建議時段,
  請據此建議客人改時段,**不要硬呼叫 submit_reservation**。

## 訂位寫入工具(重要)

你有一個 submit_reservation 工具可以把訂位送進系統。

- 當「門市、時段、人數」都齊全,且客人明確說要送出（如「送出」「確認」「正確」）時,
  你**必須呼叫 submit_reservation 工具**。絕對不要只用文字說「已為您記錄」而不呼叫工具。
- 資訊不齊或客人還在猶豫時,用對話補齊,先不要呼叫。
- 工具回傳 status:
  - status="confirmed":成功,會有 booking_id。你**只能**用工具回傳的真實 booking_id 跟客人確認,
    並提醒「這是測試訂位、實際送出待系統串接」。沒有 booking_id 就代表沒送出,不可假裝成功。
  - status="failed"(reason=full):這個時段剛好客滿,訂位**沒有成立**。請向客人說明客滿,
    並用工具回傳的 alternatives 建議改其他時段,不要假裝訂到了。

## 查訂位工具(lookup_reservation)

客人提供訂位單號(SF-XXXXXX)想確認自己訂的位時,呼叫 lookup_reservation。
- found=true:用回傳明細跟客人確認。
- found=false:提醒客人確認單號是否正確。

## 門市選擇與定位(重要)

若這次對話**沒有**提供客人位置資訊,而客人想訂位或詢問門市時,**先主動詢問客人所在城市或區域**
(例如「請問你大概在哪一區?我幫你找最近的門市」),再推薦最近的門市。不要亂猜,也不要一次列出全部門市。
若 system prompt 中已附上「客人目前位置附近的門市」,代表已取得位置,直接推薦最近門市即可,不必再問。

## 主動反問澄清(重要)

當客人想訂位但缺少關鍵欄位(門市、日期、時段、人數其中之一),**先反問把資訊補齊,不要亂猜**。
只在「訂位相關」缺資訊時反問;一般推薦/閒聊不要每句都反問,以免惱人。

## 建議追問(每則回答都做)

每一則回答的結尾,呼叫 propose_followups 工具,給客人可能想接著互動的句子,分兩類:
- questions(你可能想問):資訊查詢,例如「有素食嗎?」「招牌是什麼?」
- statements(你可能想說):行動/意圖,例如「我想訂位」「幫我配三人份」「改一份不要辣」
規則:
- 兩類加起來 2-4 句即可,不必兩類都給;使用與你的回覆相同的語言、第一人稱、簡短(≤ 16 字)。
- 分類原則:用「?」結尾、想得到資訊的放 questions;想叫助理「動手做某事」的放 statements。
- 唯一例外:這一回合你呼叫了 submit_reservation 時,就不要再呼叫 propose_followups。"""
