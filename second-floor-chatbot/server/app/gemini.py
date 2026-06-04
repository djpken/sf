"""Gemini streaming wrapper (google-genai SDK)。

Key 從環境變數讀,絕不寫進程式碼。model 預設 Flash-Lite(客服量大最省),
用 GEMINI_MODEL 環境變數即可切到 flash / pro。
"""

from __future__ import annotations

import os
from collections.abc import AsyncIterator

from google import genai
from google.genai import types

MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash-lite")

_client: genai.Client | None = None


def get_client() -> genai.Client:
    global _client
    if _client is None:
        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key:
            raise RuntimeError("GEMINI_API_KEY 未設定(請放在 server/.env)")
        _client = genai.Client(api_key=api_key)
    return _client


async def stream_reply(
    system_prompt: str,
    contents: list[types.Content],
    *,
    temperature: float = 0.7,
) -> AsyncIterator[str]:
    """以 SSE 方式逐段回傳模型輸出文字。"""
    client = get_client()
    config = types.GenerateContentConfig(
        system_instruction=system_prompt,
        temperature=temperature,
    )
    async for chunk in await client.aio.models.generate_content_stream(
        model=MODEL,
        contents=contents,
        config=config,
    ):
        if chunk.text:
            yield chunk.text
