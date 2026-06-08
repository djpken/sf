"""Gemini provider —— streaming + function calling(google-genai SDK)。

對外介面與 openai_provider 一致(中性 messages + tool_specs),由 llm.py 依
LLM_PROVIDER 分派。Key 從環境變數讀,絕不寫進程式碼。
"""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator, Callable

from google import genai
from google.genai import types

# Gemini 預設走 google-genai SDK 內建 endpoint;自訂 URL 走 http_options。
DEFAULT_BASE_URL: str | None = None
DEFAULT_MODEL = "gemini-2.5-flash-lite"

# 依 (api_key, base_url) 快取 client,避免每次請求重建。
_clients: dict[tuple[str, str], genai.Client] = {}


def is_rate_limit(exc: Exception) -> bool:
    s = str(exc)
    return "429" in s or "RESOURCE_EXHAUSTED" in s or "quota" in s.lower()


def get_client(cfg: dict) -> genai.Client:
    api_key = cfg.get("api_key")
    if not api_key:
        raise RuntimeError("此 Gemini provider 未設定 API key")
    base_url = cfg.get("base_url") or ""
    cache_key = (api_key, base_url)
    client = _clients.get(cache_key)
    if client is None:
        kwargs: dict = {"api_key": api_key}
        if base_url:
            kwargs["http_options"] = types.HttpOptions(base_url=base_url)
        client = genai.Client(**kwargs)
        _clients[cache_key] = client
    return client


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
    cfg: dict,
    system_prompt: str,
    messages: list[dict],
    *,
    tool_specs: list[dict] | None = None,
    tool_registry: dict[str, Callable] | None = None,
    temperature: float = 0.5,
    max_tool_rounds: int = 3,
) -> AsyncIterator[tuple[str, object]]:
    client = get_client(cfg)
    model = cfg.get("model") or DEFAULT_MODEL
    registry = tool_registry or {}
    config = types.GenerateContentConfig(
        system_instruction=system_prompt,
        temperature=temperature,
        tools=_to_tools(tool_specs),
    )
    working = _to_contents(messages)
    terminal = {s["name"] for s in (tool_specs or []) if s.get("terminal")}

    for _ in range(max_tool_rounds):
        fcall_parts: list[types.Part] = []

        # 流量上限(429)通常在開串流瞬間發生(還沒吐 token),可安全退避重試。
        attempt = 0
        while True:
            emitted = False
            fcall_parts = []
            try:
                async for chunk in await client.aio.models.generate_content_stream(
                    model=model,
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

        response_parts: list[types.Part] = []
        has_non_terminal = False
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
            if name not in terminal:
                has_non_terminal = True

        # terminal 工具(如 propose_followups)結果不必餵回模型,也不該為它多起一輪。
        # 只有存在非 terminal 工具(如 submit_reservation)時,才接回對話、進下一輪
        # 讓模型根據工具結果產出後續回覆。全部都是 terminal 就直接結束。
        if not has_non_terminal:
            return
        working.append(types.Content(role="model", parts=fcall_parts))
        working.append(types.Content(role="tool", parts=response_parts))
