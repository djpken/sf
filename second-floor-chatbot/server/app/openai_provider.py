"""OpenAI 相容 provider —— streaming + function calling(openai SDK)。

可接任何 OpenAI 相容 endpoint(自架 vLLM、Qwen、本地 lab 等)。
api_key / base_url / model 透過 admin 後台設定,不從 env 讀取。對外介面與 gemini 一致。
"""

from __future__ import annotations

import asyncio
import json
from collections.abc import AsyncIterator, Callable

from openai import AsyncOpenAI

DEFAULT_BASE_URL = "https://api.openai.com/v1"
DEFAULT_MODEL = "openai/Qwen3.5-122B-A10B"

# 依 (api_key, base_url) 快取 client,避免每次請求重建。
_clients: dict[tuple[str, str], AsyncOpenAI] = {}


def is_rate_limit(exc: Exception) -> bool:
    s = str(exc)
    return "429" in s or "rate limit" in s.lower() or "quota" in s.lower()


def get_client(cfg: dict) -> AsyncOpenAI:
    api_key = cfg.get("api_key")
    if not api_key:
        raise RuntimeError("此 OpenAI provider 未設定 API key")
    base_url = cfg.get("base_url") or DEFAULT_BASE_URL
    cache_key = (api_key, base_url)
    client = _clients.get(cache_key)
    if client is None:
        client = AsyncOpenAI(api_key=api_key, base_url=base_url)
        _clients[cache_key] = client
    return client


def _to_messages(system_prompt: str, messages: list[dict]) -> list[dict]:
    out = [{"role": "system", "content": system_prompt}]
    for m in messages:
        role = "user" if m["role"] == "user" else "assistant"
        out.append({"role": role, "content": m["content"]})
    return out


def _to_tools(tool_specs: list[dict] | None) -> list[dict] | None:
    if not tool_specs:
        return None
    return [
        {
            "type": "function",
            "function": {
                "name": spec["name"],
                "description": spec.get("description", ""),
                "parameters": spec.get("parameters", {}),
            },
        }
        for spec in tool_specs
    ]


async def stream_chat(
    cfg: dict,
    system_prompt: str,
    messages: list[dict],
    **kw,
) -> AsyncIterator[tuple[str, object]]:
    client = get_client(cfg)
    model = cfg.get("model") or DEFAULT_MODEL
    async for item in stream_with_client(client, model, system_prompt, messages, **kw):
        yield item


async def stream_with_client(
    client,
    model: str,
    system_prompt: str,
    messages: list[dict],
    *,
    tool_specs: list[dict] | None = None,
    tool_registry: dict[str, Callable] | None = None,
    temperature: float = 0.5,
    max_tool_rounds: int = 3,
) -> AsyncIterator[tuple[str, object]]:
    """OpenAI Chat Completions 串流核心。

    client 為任何相容 `AsyncOpenAI` 介面者(含 `AsyncAzureOpenAI`),
    model 在 Azure 為 deployment 名稱。Azure provider 直接共用此函式。
    """
    registry = tool_registry or {}
    tools = _to_tools(tool_specs)
    convo = _to_messages(system_prompt, messages)
    terminal = {s["name"] for s in (tool_specs or []) if s.get("terminal")}

    for _ in range(max_tool_rounds):
        acc: dict[int, dict] = {}  # tool-call deltas 依 index 累積

        attempt = 0
        while True:
            emitted = False
            acc = {}
            try:
                stream = await client.chat.completions.create(
                    model=model,
                    messages=convo,
                    tools=tools,
                    stream=True,
                    temperature=temperature,
                )
                async for chunk in stream:
                    if not chunk.choices:
                        continue
                    delta = chunk.choices[0].delta
                    if getattr(delta, "content", None):
                        emitted = True
                        yield ("text", delta.content)
                    for tc in getattr(delta, "tool_calls", None) or []:
                        slot = acc.setdefault(tc.index, {"id": "", "name": "", "args": ""})
                        if tc.id:
                            slot["id"] = tc.id
                        if tc.function and tc.function.name:
                            slot["name"] = tc.function.name
                        if tc.function and tc.function.arguments:
                            slot["args"] += tc.function.arguments
                break
            except Exception as exc:  # noqa: BLE001
                if is_rate_limit(exc) and not emitted and attempt < 2:
                    attempt += 1
                    await asyncio.sleep(2 * attempt)
                    continue
                raise

        if not acc:
            return

        # 執行工具並 yield 結果。terminal 工具(如 propose_followups)的結果不接回模型、
        # 也不為它多起一輪;只有非 terminal 工具(如 submit_reservation)才續跑。
        tool_results: list[dict] = []
        has_non_terminal = False
        for s in acc.values():
            name = s["name"]
            try:
                args = json.loads(s["args"] or "{}")
            except (ValueError, TypeError):
                args = {}
            handler = registry.get(name)
            if handler is None:
                result = {"error": f"unknown tool: {name}"}
            else:
                try:
                    result = handler(**args)
                except Exception as exc:  # noqa: BLE001
                    result = {"error": str(exc)}
            yield ("tool", {"name": name, "args": args, "result": result})
            tool_results.append({"id": s["id"], "result": result})
            if name not in terminal:
                has_non_terminal = True

        if not has_non_terminal:
            return

        # 把模型的 tool_call 回合接回對話,再把工具結果送回,進下一輪
        convo.append(
            {
                "role": "assistant",
                "content": None,
                "tool_calls": [
                    {
                        "id": s["id"],
                        "type": "function",
                        "function": {"name": s["name"], "arguments": s["args"] or "{}"},
                    }
                    for s in acc.values()
                ],
            }
        )
        for tr in tool_results:
            convo.append(
                {
                    "role": "tool",
                    "tool_call_id": tr["id"],
                    "content": json.dumps(tr["result"], ensure_ascii=False),
                }
            )
