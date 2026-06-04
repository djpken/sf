"""LLM provider 分派器。

用環境變數 LLM_PROVIDER 切換:
  gemini  → google-genai(預設)
  openai  → 任何 OpenAI 相容 endpoint(OPENAI_BASE_URL / OPENAI_API_KEY / OPENAI_MODEL)

兩個 provider 對外介面一致:
  stream_chat(system_prompt, messages, *, tool_specs, tool_registry, ...) -> AsyncIterator[(kind, payload)]
  is_rate_limit(exc) -> bool
  MODEL : 目前使用的 model 名稱
"""

from __future__ import annotations

import os

PROVIDER = os.environ.get("LLM_PROVIDER", "gemini").lower()

if PROVIDER == "openai":
    from . import openai_provider as _impl
else:
    PROVIDER = "gemini"
    from . import gemini as _impl

MODEL = _impl.MODEL
stream_chat = _impl.stream_chat
is_rate_limit = _impl.is_rate_limit
