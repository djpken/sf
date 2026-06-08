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
import json
import os
import secrets
import time
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
    TOOL_GUIDANCE,
    TOOLS,
    build_location_hint,
)
from .menu import build_system_prompt, infer_opts, retrieve  # noqa: E402

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


app = FastAPI(title="Second Floor Chatbot API")

# Per-IP rate limiting (dict+TTL, 無外部依賴)
# RATE_LIMIT=N 設定每 60 秒最多 N 次(預設 60)
_RATE_WINDOW = 60.0
_RATE_LIMIT = int(os.environ.get("RATE_LIMIT") or 60)
_rate_store: dict[str, list[float]] = defaultdict(list)


def _check_rate_limit(request: Request) -> None:
    ip = request.headers.get("X-Forwarded-For", request.client.host if request.client else "unknown").split(",")[0].strip()
    now = time.time()
    window_start = now - _RATE_WINDOW
    timestamps = _rate_store[ip]
    # 清掉超出視窗的舊記錄
    _rate_store[ip] = [t for t in timestamps if t > window_start]
    if len(_rate_store[ip]) >= _RATE_LIMIT:
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
    return {"ok": True, **llm.active_info()}


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
    system_prompt = build_system_prompt(items, locale=req.locale) + _remembered_pref_hint(profile) + TOOL_GUIDANCE
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
        if last_user:
            await asyncio.to_thread(db.append_message, conversation_id, "user", last_user)

    async def event_stream():
        reply_parts: list[str] = []
        booking_seen = False
        suggestions: dict = {"ask": [], "say": []}
        try:
            if conv_event:
                yield f"data: {json.dumps(conv_event, ensure_ascii=False)}\n\n"
            # 把這次 RAG 到的菜色名稱傳給前端，讓它顯示縮圖
            if items:
                menu_ctx = [{"name": it["name"]} for it in items[:8]]
                yield f"data: {json.dumps({'menu_context': menu_ctx}, ensure_ascii=False)}\n\n"
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
                    yield f"data: {json.dumps({'booking': payload['result']}, ensure_ascii=False)}\n\n"
                elif kind == "tool" and payload.get("name") == "check_availability":
                    yield f"data: {json.dumps({'availability': payload['result']}, ensure_ascii=False)}\n\n"
                elif kind == "tool" and payload.get("name") == "lookup_reservation":
                    yield f"data: {json.dumps({'reservation_lookup': payload['result']}, ensure_ascii=False)}\n\n"
                elif kind == "tool" and payload.get("name") == "show_store_card":
                    yield f"data: {json.dumps({'store_card': payload['result']}, ensure_ascii=False)}\n\n"
                elif kind == "tool" and payload.get("name") == "propose_followups":
                    suggestions = payload["result"]  # {"ask": [...], "say": [...]}
            # 串完存助理回覆 + 更新對話時間
            if session_id and conversation_id and reply_parts:
                await asyncio.to_thread(
                    db.append_message, conversation_id, "model", "".join(reply_parts)
                )
                await asyncio.to_thread(db.touch_conversation, conversation_id)
            # 建議追問放在 done 之前送;訂位回合以 booking 為準,丟棄 suggestions。
            if (suggestions.get("ask") or suggestions.get("say")) and not booking_seen:
                yield f"data: {json.dumps({'suggestions': suggestions}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'done': True})}\n\n"
        except Exception as exc:  # noqa: BLE001 — 把錯誤回給前端而非 500 斷線
            logger.exception("chat stream error: {}", exc)
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


@app.post("/api/admin/auth")
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
    p = await asyncio.to_thread(db.create_provider, body.model_dump())
    # 首筆自動設為 active
    active_id = await asyncio.to_thread(db.get_setting, "active_provider_id")
    if not active_id:
        await asyncio.to_thread(db.set_setting, "active_provider_id", p["id"])
    return {"provider": _public_provider(p)}


@app.put("/api/admin/providers/{provider_id}", dependencies=[Depends(require_admin)])
async def admin_update_provider(provider_id: str, body: ProviderIn) -> dict:
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
