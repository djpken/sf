"""OpenAI 相容 provider —— streaming + function calling(openai SDK)。

可接任何 OpenAI 相容 endpoint(自架 vLLM、Qwen、本地 lab 等),用
OPENAI_BASE_URL / OPENAI_API_KEY / OPENAI_MODEL 設定。對外介面與 gemini 一致。
"""

from __future__ import annotations

import asyncio
import json
import os
from collections.abc import AsyncIterator, Callable

from openai import AsyncOpenAI

MODEL = os.environ.get("OPENAI_MODEL", "openai/Qwen3.5-122B-A10B")

_client: AsyncOpenAI | None = None


def is_rate_limit(exc: Exception) -> bool:
    s = str(exc)
    return "429" in s or "rate limit" in s.lower() or "quota" in s.lower()


def get_client() -> AsyncOpenAI:
    global _client
    if _client is None:
        api_key = os.environ.get("OPENAI_API_KEY")
        base_url = os.environ.get("OPENAI_BASE_URL")
        if not api_key:
            raise RuntimeError("OPENAI_API_KEY 未設定(請放在 server/.env)")
        _client = AsyncOpenAI(api_key=api_key, base_url=base_url or None)
    return _client


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
    tools = _to_tools(tool_specs)
    convo = _to_messages(system_prompt, messages)

    for _ in range(max_tool_rounds):
        acc: dict[int, dict] = {}  # tool-call deltas 依 index 累積

        attempt = 0
        while True:
            emitted = False
            acc = {}
            try:
                stream = await client.chat.completions.create(
                    model=MODEL,
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

        # 把模型的 tool_call 回合接回對話,執行工具,再把結果送回
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
            convo.append(
                {
                    "role": "tool",
                    "tool_call_id": s["id"],
                    "content": json.dumps(result, ensure_ascii=False),
                }
            )
