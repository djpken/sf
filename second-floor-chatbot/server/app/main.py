"""Second Floor Chatbot API — FastAPI + Gemini streaming + 持久化。

POST   /api/chat                 收對話 → RAG(套用記憶忌口)→ Gemini SSE streaming,持久化
GET    /api/health               健康檢查 + 目前 model
GET    /api/conversations        列出此 session 的對話
GET    /api/conversations/{id}   取某段對話的訊息(重開續聊)
DELETE /api/conversations/{id}   刪除對話
GET    /api/profile              取記住的忌口
DELETE /api/profile              清除忌口記憶
"""

from __future__ import annotations

import asyncio
import ipaddress
import json
import os
import secrets
import time
import urllib.parse
from collections import defaultdict

from dotenv import load_dotenv

# 先載入 server/.env(gitignored)再 import 用到 key 的模組
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

from fastapi import Depends, FastAPI, Header, HTTPException, Request  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from fastapi.responses import StreamingResponse  # noqa: E402
from loguru import logger  # noqa: E402
from pydantic import BaseModel  # noqa: E402

from . import azure_provider, db, gemini, llm, openai_provider  # noqa: E402
from .booking import (  # noqa: E402
    CHECK_AVAILABILITY_TOOL_SPEC,
    FOLLOWUPS_TOOL_SPEC,
    LOOKUP_RESERVATION_TOOL_SPEC,
    RESERVATION_TOOL_SPEC,
    STORE_CARD_TOOL_SPEC,
    STORE_INFO,
    TOOL_GUIDANCE,
    TOOLS,
    build_location_hint,
)
from .menu import DEFAULT_BEHAVIOR_RULES, MENU_INDEX, build_system_prompt, infer_opts, retrieve  # noqa: E402

_STORES_PATH = os.path.join(os.path.dirname(__file__), "data", "stores.json")
with open(_STORES_PATH, encoding="utf-8") as _f:
    _STORES: dict = json.load(_f)


def _friendly_error(exc: Exception, locale: str = "zh-TW") -> str:
    if llm.is_rate_limit(exc):
        if locale == "en":
            return (
                "The AI service has hit its rate limit (429). "
                "If you've been sending many messages quickly, wait about a minute and try again. "
                "If it keeps happening, the service quota may be exhausted — check the provider's billing settings."
            )
        return (
            "目前 AI 服務達到流量/額度上限(429)。若是短時間問太多次,請稍候約 1 分鐘再試;"
            "若持續發生,代表額度可能用完,請檢查目前 provider 的配額/帳單設定。"
        )
    if locale == "en":
        return f"Something went wrong: {str(exc)[:200]}"
    return f"發生問題:{str(exc)[:200]}"

db.init()

_PREF_LABELS = {
    "no_pork": "不吃豬肉",
    "no_beef": "不吃牛肉",
    "no_seafood": "不吃海鮮",
    "vegetarian": "吃素（蛋奶素）",
    "no_nuts": "堅果過敏",
}


class Message(BaseModel):
    role: str  # 'user' | 'model'
    content: str


class Location(BaseModel):
    lat: float
    lng: float
    accuracy: float | None = None  # 公尺,前端定位精度(可省略)


class ChatRequest(BaseModel):
    messages: list[Message]
    session_id: str | None = None
    conversation_id: str | None = None
    locale: str = "zh-TW"
    location: Location | None = None  # 前端取得的地理位置,用於推薦最近門市


def _validate_base_url(url: str) -> None:
    """拒絕可能導致 SSRF 的 base_url:非 https 或指向內網/loopback IP。"""
    if not url:
        return
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https":
        raise ValueError("base_url 必須使用 https:// 協定")
    hostname = parsed.hostname or ""
    try:
        addr = ipaddress.ip_address(hostname)
        if addr.is_private or addr.is_loopback or addr.is_link_local:
            raise ValueError("base_url 不能指向私有或 loopback IP 位址")
    except ValueError as exc:
        if "base_url" in str(exc):
            raise
        # hostname 是 domain name,不是 IP,允許通過


class ProviderIn(BaseModel):
    name: str = ""
    type: str = "gemini"          # 'gemini' | 'openai' | 'azure'
    api_key: str = ""             # 空字串 = 更新時保留原值
    model: str = ""               # azure 時 = deployment 名稱
    base_url: str = ""            # azure 時 = resource endpoint
    use_custom_url: bool = False
    api_version: str = ""         # 僅 azure 用


class AuthIn(BaseModel):
    token: str = ""


class StoreNotesIn(BaseModel):
    seating_capacity: int | None = None
    table_spacing: str = ""
    has_private_room: bool = False
    has_outdoor: bool = False
    noise_level: str = ""
    notes: str = ""
    phone: str | None = None       # None = 不變更;寫入 stores.json,非 DB notes
    phone_note: str | None = None  # 電話備注說明,同上


class StoreCreateIn(BaseModel):
    name: str
    address: str = ""
    phone: str = ""
    hours: str = ""


class MenuNoteIn(BaseModel):
    spice_adjustable: bool = False
    notes: str = ""


app = FastAPI(title="Second Floor Chatbot API")

# Per-IP rate limiting (dict+TTL, 無外部依賴)
# RATE_LIMIT=N 設定每 60 秒最多 N 次(預設 60)
# TRUST_PROXY=1 時信任 X-Forwarded-For 最後一個 IP(由反向代理附加,無法偽造);
# 未設定時直接使用 TCP 連線的 client IP,避免 X-Forwarded-For 偽造繞過限速。
_RATE_WINDOW = 60.0
_RATE_LIMIT = int(os.environ.get("RATE_LIMIT") or 60)
_TRUST_PROXY = bool(os.environ.get("TRUST_PROXY", ""))
_rate_store: dict[str, list[float]] = defaultdict(list)


def _check_rate_limit(request: Request) -> None:
    if _TRUST_PROXY:
        xff = request.headers.get("X-Forwarded-For", "")
        ips = [x.strip() for x in xff.split(",") if x.strip()]
        ip = ips[-1] if ips else (request.client.host if request.client else "unknown")
    else:
        ip = request.client.host if request.client else "unknown"
    now = time.time()
    window_start = now - _RATE_WINDOW
    timestamps = _rate_store[ip]
    # 清掉超出視窗的舊記錄，並在 list 清空時移除 key 以避免記憶體洩漏
    pruned = [t for t in timestamps if t > window_start]
    if pruned:
        _rate_store[ip] = pruned
    elif ip in _rate_store:
        del _rate_store[ip]
    if len(_rate_store.get(ip, [])) >= _RATE_LIMIT:
        raise HTTPException(
            status_code=429,
            detail=f"請求太頻繁，請稍候 {int(_RATE_WINDOW)} 秒後再試。",
        )
    _rate_store[ip].append(now)


# 開發期前端來自 vite dev server;之後上線改成正式網域。
_origins = os.environ.get(
    "ALLOWED_ORIGINS",
    "http://localhost:5173,http://127.0.0.1:5173",
).split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in _origins if o.strip()],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health() -> dict:
    info = llm.active_info()
    return {"ok": bool(info.get("provider")), **info}


def _remembered_pref_hint(prefs: dict) -> str:
    active = [label for key, label in _PREF_LABELS.items() if prefs.get(key)]
    if not active:
        return ""
    return (
        "\n\n## 這位客人記錄的長期忌口\n"
        + "、".join(active)
        + "\n推薦與訂位時請預設套用這些限制,除非客人當下明確說要改。"
    )


@app.post("/api/chat", dependencies=[Depends(_check_rate_limit)])
async def chat(req: ChatRequest) -> StreamingResponse:
    last_user = next((m.content for m in reversed(req.messages) if m.role == "user"), "")
    session_id = req.session_id
    conversation_id = req.conversation_id

    # 忌口記憶:把這次偵測到的長期忌口併入 profile,再把記住的全部套用到 RAG。
    detected = infer_opts(last_user)
    profile = (
        await asyncio.to_thread(db.merge_profile, session_id, detected)
        if session_id
        else {k: v for k, v in detected.items() if k in db.PROFILE_PREF_KEYS}
    )
    retrieve_opts = {**detected, **profile}  # 記住的忌口 + 當下訊息(含辣度)
    items = retrieve(last_user, max_items=24, **retrieve_opts)
    # 只在查詢有關鍵字命中時才顯示相關菜色 chips（min_score=1 過濾純無關詢問）
    menu_ctx_items = retrieve(last_user, max_items=8, min_score=1, **retrieve_opts)
    menu_notes_map, store_notes_map, behavior_rules, qa_pairs = await asyncio.gather(
        asyncio.to_thread(db.list_menu_notes),
        asyncio.to_thread(db.list_store_notes),
        asyncio.to_thread(db.get_setting, _BEHAVIOR_RULES_KEY),
        asyncio.to_thread(db.list_qa_pairs),
    )
    system_prompt = (
        build_system_prompt(
            items,
            locale=req.locale,
            menu_notes=menu_notes_map,
            store_notes=store_notes_map,
            behavior_rules=behavior_rules,
            qa_pairs=qa_pairs,
        )
        + _remembered_pref_hint(profile)
        + TOOL_GUIDANCE
    )
    if req.location:
        system_prompt += build_location_hint(req.location.lat, req.location.lng)
    chat_messages = [{"role": m.role, "content": m.content} for m in req.messages]

    # 對話持久化:建立/沿用對話,先存使用者訊息。
    conv_event: dict | None = None
    if session_id:
        if not conversation_id:
            conv = await asyncio.to_thread(
                db.create_conversation, session_id, last_user or "新對話"
            )
            conversation_id = conv["id"]
            conv_event = {"conversation": {**conv, "new": True}}
        elif conversation_id:
            # 驗證 conversation 屬於此 session,防止跨 session IDOR 注入
            owned = await asyncio.to_thread(db.conversation_owned_by, session_id, conversation_id)
            if not owned:
                raise HTTPException(status_code=403, detail="conversation_id 不屬於此 session")
        if last_user:
            await asyncio.to_thread(db.append_message, conversation_id, "user", last_user)

    async def event_stream():
        reply_parts: list[str] = []
        booking_seen = False
        booking_turn = False  # 任何訂位/門市工具被呼叫時設 True，用來抑制 menu_context
        suggestions: dict = {"ask": [], "say": []}
        try:
            if conv_event:
                yield f"data: {json.dumps(conv_event, ensure_ascii=False)}\n\n"
            async for kind, payload in llm.stream_chat(
                system_prompt,
                chat_messages,
                tool_specs=[
                    RESERVATION_TOOL_SPEC,
                    CHECK_AVAILABILITY_TOOL_SPEC,
                    LOOKUP_RESERVATION_TOOL_SPEC,
                    STORE_CARD_TOOL_SPEC,
                    FOLLOWUPS_TOOL_SPEC,
                ],
                tool_registry=TOOLS,
            ):
                if kind == "text":
                    reply_parts.append(payload)
                    yield f"data: {json.dumps({'delta': payload}, ensure_ascii=False)}\n\n"
                elif kind == "tool" and payload.get("name") == "submit_reservation":
                    booking_seen = True
                    booking_turn = True
                    result = payload["result"]
                    yield f"data: {json.dumps({'booking': result}, ensure_ascii=False)}\n\n"
                    if session_id and conversation_id:
                        await asyncio.to_thread(db.append_message, conversation_id, "booking", json.dumps(result, ensure_ascii=False))
                elif kind == "tool" and payload.get("name") == "check_availability":
                    booking_turn = True
                    result = payload["result"]
                    yield f"data: {json.dumps({'availability': result}, ensure_ascii=False)}\n\n"
                    if session_id and conversation_id:
                        await asyncio.to_thread(db.append_message, conversation_id, "availability", json.dumps(result, ensure_ascii=False))
                elif kind == "tool" and payload.get("name") == "lookup_reservation":
                    booking_turn = True
                    result = payload["result"]
                    yield f"data: {json.dumps({'reservation_lookup': result}, ensure_ascii=False)}\n\n"
                    if session_id and conversation_id:
                        await asyncio.to_thread(db.append_message, conversation_id, "lookup", json.dumps(result, ensure_ascii=False))
                elif kind == "tool" and payload.get("name") == "show_store_card":
                    booking_turn = True
                    result = payload["result"]
                    yield f"data: {json.dumps({'store_card': result}, ensure_ascii=False)}\n\n"
                    if session_id and conversation_id:
                        await asyncio.to_thread(db.append_message, conversation_id, "store_card", json.dumps(result, ensure_ascii=False))
                elif kind == "tool" and payload.get("name") == "propose_followups":
                    suggestions = payload["result"]  # {"ask": [...], "say": [...]}
            # 串完存助理回覆 + 更新對話時間
            if session_id and conversation_id and reply_parts:
                await asyncio.to_thread(
                    db.append_message, conversation_id, "model", "".join(reply_parts)
                )
                await asyncio.to_thread(db.touch_conversation, conversation_id)
            # 相關菜色 chips：只在非訂位/門市工具回合且有命中關鍵字時才顯示
            if menu_ctx_items and not booking_turn:
                menu_ctx = [{"name": it["name"]} for it in menu_ctx_items]
                yield f"data: {json.dumps({'menu_context': menu_ctx}, ensure_ascii=False)}\n\n"
            # 建議追問放在 done 之前送;訂位回合以 booking 為準,丟棄 suggestions。
            if (suggestions.get("ask") or suggestions.get("say")) and not booking_seen:
                yield f"data: {json.dumps({'suggestions': suggestions}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'done': True})}\n\n"
        except Exception as exc:  # noqa: BLE001 — 把錯誤回給前端而非 500 斷線
            logger.exception(f"chat stream error: {exc}")
            yield f"data: {json.dumps({'error': _friendly_error(exc, req.locale)}, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# ─── 對話歷史 ────────────────────────────────────────────────────────────────

@app.get("/api/conversations")
async def list_conversations(session_id: str) -> dict:
    convs = await asyncio.to_thread(db.list_conversations, session_id)
    return {"conversations": convs}


@app.get("/api/conversations/{conversation_id}")
async def get_conversation(conversation_id: str, session_id: str) -> dict:
    messages = await asyncio.to_thread(db.get_messages, session_id, conversation_id)
    return {"messages": messages}


@app.delete("/api/conversations/{conversation_id}")
async def delete_conversation(conversation_id: str, session_id: str) -> dict:
    await asyncio.to_thread(db.delete_conversation, session_id, conversation_id)
    return {"ok": True}


# ─── 忌口記憶 ────────────────────────────────────────────────────────────────

@app.get("/api/profile")
async def get_profile(session_id: str) -> dict:
    prefs = await asyncio.to_thread(db.get_profile, session_id)
    labels = [label for key, label in _PREF_LABELS.items() if prefs.get(key)]
    return {"prefs": prefs, "labels": labels}


@app.delete("/api/profile")
async def clear_profile(session_id: str) -> dict:
    await asyncio.to_thread(db.clear_profile, session_id)
    return {"ok": True}


# ─── 管理介面:provider 設定 ─────────────────────────────────────────────────
# /admin 頁面用 ADMIN_TOKEN 登入,所有寫入/讀取均需帶 X-Admin-Token header。

_PROVIDER_DEFAULTS = {
    "gemini": {"base_url": "", "model": gemini.DEFAULT_MODEL},
    "openai": {"base_url": openai_provider.DEFAULT_BASE_URL, "model": openai_provider.DEFAULT_MODEL},
    "azure": {"base_url": "", "model": "", "api_version": azure_provider.DEFAULT_API_VERSION},
}


def _verify_admin_token(token: str | None) -> None:
    expected = os.environ.get("ADMIN_TOKEN")
    if not expected:
        raise HTTPException(status_code=503, detail="ADMIN_TOKEN 未設定,請在 server/.env 設定後重啟。")
    if not secrets.compare_digest(token or "", expected):
        raise HTTPException(status_code=401, detail="管理密碼錯誤")


def require_admin(x_admin_token: str | None = Header(default=None)) -> None:
    _verify_admin_token(x_admin_token)


def _public_provider(p: dict) -> dict:
    """對外不回傳 api_key 原值,只回是否已設定與末四碼。"""
    key = p.get("api_key") or ""
    return {
        "id": p["id"],
        "name": p["name"],
        "type": p["type"],
        "model": p["model"],
        "base_url": p["base_url"],
        "use_custom_url": p["use_custom_url"],
        "api_version": p.get("api_version", ""),
        "has_key": bool(key),
        "key_hint": key[-4:] if key else "",
    }


@app.post("/api/admin/auth", dependencies=[Depends(_check_rate_limit)])
async def admin_auth(body: AuthIn) -> dict:
    _verify_admin_token(body.token)
    return {"ok": True}


@app.get("/api/admin/providers", dependencies=[Depends(require_admin)])
async def admin_list_providers() -> dict:
    providers = await asyncio.to_thread(db.list_providers)
    active_id = await asyncio.to_thread(db.get_setting, "active_provider_id")
    return {
        "providers": [_public_provider(p) for p in providers],
        "active_id": active_id or "",
        "defaults": _PROVIDER_DEFAULTS,
    }


@app.post("/api/admin/providers", dependencies=[Depends(require_admin)])
async def admin_create_provider(body: ProviderIn) -> dict:
    if body.use_custom_url and body.base_url:
        try:
            _validate_base_url(body.base_url)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
    p = await asyncio.to_thread(db.create_provider, body.model_dump())
    # 首筆自動設為 active
    active_id = await asyncio.to_thread(db.get_setting, "active_provider_id")
    if not active_id:
        await asyncio.to_thread(db.set_setting, "active_provider_id", p["id"])
    return {"provider": _public_provider(p)}


@app.put("/api/admin/providers/{provider_id}", dependencies=[Depends(require_admin)])
async def admin_update_provider(provider_id: str, body: ProviderIn) -> dict:
    if body.use_custom_url and body.base_url:
        try:
            _validate_base_url(body.base_url)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
    p = await asyncio.to_thread(db.update_provider, provider_id, body.model_dump())
    if not p:
        raise HTTPException(status_code=404, detail="找不到此 provider")
    return {"provider": _public_provider(p)}


@app.delete("/api/admin/providers/{provider_id}", dependencies=[Depends(require_admin)])
async def admin_delete_provider(provider_id: str) -> dict:
    await asyncio.to_thread(db.delete_provider, provider_id)
    return {"ok": True}


@app.post("/api/admin/providers/{provider_id}/activate", dependencies=[Depends(require_admin)])
async def admin_activate_provider(provider_id: str) -> dict:
    p = await asyncio.to_thread(db.get_provider, provider_id)
    if not p:
        raise HTTPException(status_code=404, detail="找不到此 provider")
    await asyncio.to_thread(db.set_setting, "active_provider_id", provider_id)
    return {"ok": True, "active_id": provider_id}


@app.post("/api/admin/providers/{provider_id}/test", dependencies=[Depends(require_admin)])
async def admin_test_provider(provider_id: str) -> dict:
    """用該 provider 設定送一句極短 prompt 探活。"""
    p = await asyncio.to_thread(db.get_provider, provider_id)
    if not p:
        raise HTTPException(status_code=404, detail="找不到此 provider")
    impl = llm._impl_for(p["type"])
    if p["type"] == "azure":
        base_url = p["base_url"]
    else:
        base_url = p["base_url"] if p["use_custom_url"] else (impl.DEFAULT_BASE_URL or "")
    cfg = {
        "type": p["type"],
        "api_key": p["api_key"],
        "model": p["model"] or impl.DEFAULT_MODEL,
        "base_url": base_url or "",
        "api_version": p.get("api_version") or "",
    }
    try:
        got_text = False
        async for kind, _payload in impl.stream_chat(cfg, "回覆 ok 即可。", [{"role": "user", "content": "ping"}]):
            if kind == "text":
                got_text = True
                break
        return {"ok": True, "model": cfg["model"], "responded": got_text}
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "error": str(exc)[:300]}


# ─── 門市資訊 ────────────────────────────────────────────────────

@app.get("/api/stores")
async def get_stores():
    """回傳所有門市名稱、電話、地址、營業時間（公開端點）。"""
    return {
        "stores": [
            {"name": name, **{k: v for k, v in info.items() if k != "image"}}
            for name, info in _STORES.items()
        ]
    }


# ─── 聯絡方式設定（公開讀取、需 admin 寫入）─────────────────────

_CONTACT_PHONE_KEY = "contact_phone"
_CONTACT_NOTE_KEY = "contact_note"
_BEHAVIOR_RULES_KEY = "behavior_rules"


@app.get("/api/settings/contact")
async def get_contact():
    """回傳管理員設定的總客服電話（公開端點）。"""
    phone = await asyncio.to_thread(db.get_setting, _CONTACT_PHONE_KEY)
    note = await asyncio.to_thread(db.get_setting, _CONTACT_NOTE_KEY)
    return {"phone": phone or "", "note": note or ""}


class ContactSettingRequest(BaseModel):
    phone: str
    note: str = ""


@app.put("/api/admin/settings/contact")
async def set_contact(req: ContactSettingRequest, _=Depends(require_admin)):
    await asyncio.to_thread(db.set_setting, _CONTACT_PHONE_KEY, req.phone.strip())
    await asyncio.to_thread(db.set_setting, _CONTACT_NOTE_KEY, req.note.strip())
    return {"ok": True}


# ─── 行為守則(system prompt 可編輯區) ────────────────────────────────────────

class BehaviorRulesRequest(BaseModel):
    rules: str = ""


@app.get("/api/admin/settings/behavior-rules", dependencies=[Depends(require_admin)])
async def get_behavior_rules():
    saved = await asyncio.to_thread(db.get_setting, _BEHAVIOR_RULES_KEY)
    return {"rules": saved or "", "default": DEFAULT_BEHAVIOR_RULES}


@app.put("/api/admin/settings/behavior-rules", dependencies=[Depends(require_admin)])
async def set_behavior_rules(req: BehaviorRulesRequest):
    await asyncio.to_thread(db.set_setting, _BEHAVIOR_RULES_KEY, req.rules.strip())
    return {"ok": True}


# ─── 指定問答 Q&A(類 skills 的 trigger→answer) ─────────────────────────────

class QaPairRequest(BaseModel):
    question: str
    answer: str
    enabled: bool = True
    sort_order: int = 0


@app.get("/api/admin/qa", dependencies=[Depends(require_admin)])
async def list_qa():
    pairs = await asyncio.to_thread(db.list_qa_pairs)
    return {"pairs": pairs}


@app.post("/api/admin/qa", dependencies=[Depends(require_admin)])
async def create_qa(req: QaPairRequest):
    if not req.question.strip() or not req.answer.strip():
        raise HTTPException(status_code=400, detail="問題與回答都不可空白")
    pair = await asyncio.to_thread(db.create_qa_pair, req.model_dump())
    return {"ok": True, "pair": pair}


@app.put("/api/admin/qa/{qa_id}", dependencies=[Depends(require_admin)])
async def update_qa(qa_id: str, req: QaPairRequest):
    if not req.question.strip() or not req.answer.strip():
        raise HTTPException(status_code=400, detail="問題與回答都不可空白")
    pair = await asyncio.to_thread(db.update_qa_pair, qa_id, req.model_dump())
    if pair is None:
        raise HTTPException(status_code=404, detail="找不到此問答")
    return {"ok": True, "pair": pair}


@app.delete("/api/admin/qa/{qa_id}", dependencies=[Depends(require_admin)])
async def delete_qa(qa_id: str):
    await asyncio.to_thread(db.delete_qa_pair, qa_id)
    return {"ok": True}


# ─── 分店特色資訊管理 ─────────────────────────────────────────────────────────

@app.get("/api/admin/stores", dependencies=[Depends(require_admin)])
async def admin_list_stores() -> dict:
    """列出所有分店及其已設定的特色資訊。"""
    store_notes_map = await asyncio.to_thread(db.list_store_notes)
    stores = [
        {
            "name": name,
            "address": info.get("address", ""),
            "phone": info.get("phone", ""),
            "phone_note": info.get("phone_note", ""),
            "notes": store_notes_map.get(name, {}),
        }
        for name, info in _STORES.items()
    ]
    return {"stores": stores}


@app.post("/api/admin/stores", dependencies=[Depends(require_admin)])
async def admin_create_store(body: StoreCreateIn) -> dict:
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="分店名稱不能為空")
    if name in _STORES:
        raise HTTPException(status_code=409, detail=f"分店「{name}」已存在")
    new_info = {
        "address": body.address.strip(),
        "phone": body.phone.strip(),
        "hours": body.hours.strip(),
    }
    _STORES[name] = new_info
    STORE_INFO[name] = new_info  # 同步 booking 模組的店資料(它在 import 時另載一份)

    await asyncio.to_thread(_write_stores)
    return {"ok": True, "store": {"name": name, **new_info}}


def _write_stores() -> None:
    with open(_STORES_PATH, "w", encoding="utf-8") as f:
        json.dump(_STORES, f, ensure_ascii=False, indent=2)


@app.put("/api/admin/stores/{store_name:path}", dependencies=[Depends(require_admin)])
async def admin_update_store(store_name: str, body: StoreNotesIn) -> dict:
    if store_name not in _STORES:
        raise HTTPException(status_code=404, detail="找不到此門市")
    if body.phone is not None or body.phone_note is not None:
        info = _STORES[store_name]
        if body.phone is not None:
            info["phone"] = body.phone.strip()
        if body.phone_note is not None:
            info["phone_note"] = body.phone_note.strip()
        STORE_INFO[store_name] = info  # 同步 booking 模組,讓 show_store_card 立即生效
        await asyncio.to_thread(_write_stores)
    notes = await asyncio.to_thread(
        db.upsert_store_notes, store_name, body.model_dump(exclude={"phone", "phone_note"})
    )
    return {"ok": True, "notes": notes}


# ─── 菜單品項備注管理 ─────────────────────────────────────────────────────────

@app.get("/api/admin/menu", dependencies=[Depends(require_admin)])
async def admin_list_menu() -> dict:
    """列出全部菜單品項及其已設定的備注。"""
    menu_notes_map = await asyncio.to_thread(db.list_menu_notes)
    items = [
        {
            "name": item["name"],
            "category": item["category"],
            "price": item.get("price"),
            "notes": menu_notes_map.get(item["name"], {}),
        }
        for item in MENU_INDEX
    ]
    return {"items": items}


@app.put("/api/admin/menu/{item_name:path}", dependencies=[Depends(require_admin)])
async def admin_update_menu_item(item_name: str, body: MenuNoteIn) -> dict:
    if not any(i["name"] == item_name for i in MENU_INDEX):
        raise HTTPException(status_code=404, detail="找不到此菜單品項")
    notes = await asyncio.to_thread(db.upsert_menu_note, item_name, body.model_dump())
    return {"ok": True, "notes": notes}
