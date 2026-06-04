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

from dotenv import load_dotenv

# 先載入 server/.env(gitignored)再 import 用到 key 的模組
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

from fastapi import FastAPI  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from fastapi.responses import StreamingResponse  # noqa: E402
from google.genai import types  # noqa: E402
from pydantic import BaseModel  # noqa: E402

from . import db  # noqa: E402
from .booking import RESERVATION_TOOL, TOOL_GUIDANCE, TOOLS  # noqa: E402
from .gemini import MODEL, stream_chat  # noqa: E402
from .menu import build_system_prompt, infer_opts, retrieve  # noqa: E402

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


class ChatRequest(BaseModel):
    messages: list[Message]
    session_id: str | None = None
    conversation_id: str | None = None


app = FastAPI(title="Second Floor Chatbot API")

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
    return {"ok": True, "model": MODEL}


def _to_contents(messages: list[Message]) -> list[types.Content]:
    out: list[types.Content] = []
    for m in messages:
        role = "user" if m.role == "user" else "model"
        out.append(types.Content(role=role, parts=[types.Part.from_text(text=m.content)]))
    return out


def _remembered_pref_hint(prefs: dict) -> str:
    active = [label for key, label in _PREF_LABELS.items() if prefs.get(key)]
    if not active:
        return ""
    return (
        "\n\n## 這位客人記錄的長期忌口\n"
        + "、".join(active)
        + "\n推薦與訂位時請預設套用這些限制,除非客人當下明確說要改。"
    )


@app.post("/api/chat")
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
    system_prompt = build_system_prompt(items) + _remembered_pref_hint(profile) + TOOL_GUIDANCE
    contents = _to_contents(req.messages)

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
        try:
            if conv_event:
                yield f"data: {json.dumps(conv_event, ensure_ascii=False)}\n\n"
            async for kind, payload in stream_chat(
                system_prompt,
                contents,
                tools=[RESERVATION_TOOL],
                tool_registry=TOOLS,
            ):
                if kind == "text":
                    reply_parts.append(payload)
                    yield f"data: {json.dumps({'delta': payload}, ensure_ascii=False)}\n\n"
                elif kind == "tool" and payload.get("name") == "submit_reservation":
                    yield f"data: {json.dumps({'booking': payload['result']}, ensure_ascii=False)}\n\n"
            # 串完存助理回覆 + 更新對話時間
            if session_id and conversation_id and reply_parts:
                await asyncio.to_thread(
                    db.append_message, conversation_id, "model", "".join(reply_parts)
                )
                await asyncio.to_thread(db.touch_conversation, conversation_id)
            yield f"data: {json.dumps({'done': True})}\n\n"
        except Exception as exc:  # noqa: BLE001 — 把錯誤回給前端而非 500 斷線
            yield f"data: {json.dumps({'error': str(exc)}, ensure_ascii=False)}\n\n"

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
