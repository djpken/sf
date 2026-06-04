"""Gemini provider —— streaming + function calling(google-genai SDK)。

對外介面與 openai_provider 一致(中性 messages + tool_specs),由 llm.py 依
LLM_PROVIDER 分派。Key 從環境變數讀,絕不寫進程式碼。
"""

from __future__ import annotations

import asyncio
import os
from collections.abc import AsyncIterator, Callable

from google import genai
from google.genai import types

MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash-lite")

_client: genai.Client | None = None


def is_rate_limit(exc: Exception) -> bool:
    s = str(exc)
    return "429" in s or "RESOURCE_EXHAUSTED" in s or "quota" in s.lower()


def get_client() -> genai.Client:
    global _client
    if _client is None:
        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key:
            raise RuntimeError("GEMINI_API_KEY 未設定(請放在 server/.env)")
        _client = genai.Client(api_key=api_key)
    return _client


def _to_contents(messages: list[dict]) -> list[types.Content]:
    out: list[types.Content] = []
    for m in messages:
        role = "user" if m["role"] == "user" else "model"
        out.append(types.Content(role=role, parts=[types.Part.from_text(text=m["content"])]))
    return out


def _to_tools(tool_specs: list[dict] | None) -> list[types.Tool] | None:
    if not tool_specs:
        return None
    decls = [
        types.FunctionDeclaration(
            name=spec["name"],
            description=spec.get("description", ""),
            parameters_json_schema=spec.get("parameters"),
        )
        for spec in tool_specs
    ]
    return [types.Tool(function_declarations=decls)]


async def stream_chat(
    system_prompt: str,
    messages: list[dict],
    *,
    tool_specs: list[dict] | None = None,
    tool_registry: dict[str, Callable] | None = None,
    temperature: float = 0.5,
    max_tool_rounds: int = 3,
) -> AsyncIterator[tuple[str, object]]:
    client = get_client()
    registry = tool_registry or {}
    config = types.GenerateContentConfig(
        system_instruction=system_prompt,
        temperature=temperature,
        tools=_to_tools(tool_specs),
    )
    working = _to_contents(messages)

    for _ in range(max_tool_rounds):
        fcall_parts: list[types.Part] = []

        # 流量上限(429)通常在開串流瞬間發生(還沒吐 token),可安全退避重試。
        attempt = 0
        while True:
            emitted = False
            fcall_parts = []
            try:
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
                            emitted = True
                            yield ("text", part.text)
                break
            except Exception as exc:  # noqa: BLE001
                if is_rate_limit(exc) and not emitted and attempt < 2:
                    attempt += 1
                    await asyncio.sleep(2 * attempt)
                    continue
                raise

        if not fcall_parts:
            return

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
                except Exception as exc:  # noqa: BLE001
                    result = {"error": str(exc)}
            yield ("tool", {"name": name, "args": args, "result": result})
            response_parts.append(types.Part.from_function_response(name=name, response=result))
        working.append(types.Content(role="tool", parts=response_parts))
