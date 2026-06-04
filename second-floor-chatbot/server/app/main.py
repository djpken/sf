"""Second Floor Chatbot API — FastAPI + Gemini streaming。

POST /api/chat  : 收前端對話歷史 → RAG 篩菜單 → Gemini SSE streaming
GET  /api/health: 健康檢查 + 目前 model
"""

from __future__ import annotations

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

from .gemini import MODEL, stream_reply  # noqa: E402
from .menu import build_system_prompt, infer_opts, retrieve  # noqa: E402


class Message(BaseModel):
    role: str  # 'user' | 'model'
    content: str


class ChatRequest(BaseModel):
    messages: list[Message]


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


@app.post("/api/chat")
async def chat(req: ChatRequest) -> StreamingResponse:
    last_user = next((m.content for m in reversed(req.messages) if m.role == "user"), "")

    # RAG:依最後一句使用者訊息偵測忌口/辣度,硬篩菜單後注入 system prompt。
    opts = infer_opts(last_user)
    items = retrieve(last_user, max_items=24, **opts)
    system_prompt = build_system_prompt(items)
    contents = _to_contents(req.messages)

    async def event_stream():
        try:
            async for piece in stream_reply(system_prompt, contents):
                yield f"data: {json.dumps({'delta': piece}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'done': True})}\n\n"
        except Exception as exc:  # noqa: BLE001 — 把錯誤回給前端而非 500 斷線
            yield f"data: {json.dumps({'error': str(exc)}, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
