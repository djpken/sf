"""Gemini streaming + function calling wrapper (google-genai SDK)。

Key 從環境變數讀,絕不寫進程式碼。model 預設 Flash-Lite(客服量大最省),
用 GEMINI_MODEL 環境變數即可切到 flash / pro。
"""

from __future__ import annotations

import os
from collections.abc import AsyncIterator, Callable

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


async def stream_chat(
    system_prompt: str,
    contents: list[types.Content],
    *,
    tools: list[types.Tool] | None = None,
    tool_registry: dict[str, Callable] | None = None,
    temperature: float = 0.5,
    max_tool_rounds: int = 3,
) -> AsyncIterator[tuple[str, object]]:
    """串流對話,支援 function calling。

    yield ('text', str)  : 模型輸出的文字片段(即時串流)
    yield ('tool', dict) : 某個工具被呼叫,內容為 {name, args, result}

    一般對話:模型只輸出 text → 直接串完結束。
    訂位等需要寫入時:模型發 function_call → 執行對應 handler → 把結果送回 →
    模型再串出確認文字。整個迴圈最多 max_tool_rounds 次,避免無限呼叫。
    """
    client = get_client()
    registry = tool_registry or {}
    config = types.GenerateContentConfig(
        system_instruction=system_prompt,
        temperature=temperature,
        tools=tools or None,
    )
    working = list(contents)

    for _ in range(max_tool_rounds):
        fcall_parts: list[types.Part] = []

        async for chunk in await client.aio.models.generate_content_stream(
            model=MODEL,
            contents=working,
            config=config,
        ):
            cand = chunk.candidates[0] if getattr(chunk, "candidates", None) else None
            parts = cand.content.parts if (cand and cand.content and cand.content.parts) else []
            for part in parts:
                if getattr(part, "function_call", None):
                    fcall_parts.append(part)
                elif getattr(part, "text", None):
                    yield ("text", part.text)

        if not fcall_parts:
            return

        # 把模型的 function_call 內容接回對話,執行工具,再把結果送回模型
        working.append(types.Content(role="model", parts=fcall_parts))
        response_parts: list[types.Part] = []
        for part in fcall_parts:
            fc = part.function_call
            name = fc.name
            args = dict(fc.args) if fc.args else {}
            handler = registry.get(name)
            if handler is None:
                result = {"error": f"unknown tool: {name}"}
            else:
                try:
                    result = handler(**args)
                except Exception as exc:  # noqa: BLE001 — 讓模型自行向客人解釋失敗
                    result = {"error": str(exc)}
            yield ("tool", {"name": name, "args": args, "result": result})
            response_parts.append(
                types.Part.from_function_response(name=name, response=result)
            )
        working.append(types.Content(role="tool", parts=response_parts))
