"""Azure OpenAI provider —— streaming + function calling。

Azure 與標準 OpenAI 的差異:認證走 `api-key`、URL 為
`{endpoint}/openai/deployments/{deployment}/chat/completions?api-version=...`。
由 openai SDK 的 AsyncAzureOpenAI 處理路徑組裝;串流/工具邏輯與 openai_provider 共用。

config 對應:
  base_url     → azure resource endpoint(如 https://xxx.cognitiveservices.azure.com/)
  model        → deployment 名稱(如 gpt-4o-mini)
  api_version  → 如 2024-10-21
"""

from __future__ import annotations

from collections.abc import AsyncIterator, Callable

from openai import AsyncAzureOpenAI

from . import openai_provider

# Azure 沒有「預設 endpoint」,一定要填 resource endpoint。
DEFAULT_BASE_URL: str | None = None
DEFAULT_MODEL = ""  # = deployment 名稱,必填
DEFAULT_API_VERSION = "2024-10-21"

# Azure 與 OpenAI 的流量上限判斷相同。
is_rate_limit = openai_provider.is_rate_limit

# 依 (api_key, endpoint, api_version) 快取 client。
_clients: dict[tuple[str, str, str], AsyncAzureOpenAI] = {}


def get_client(cfg: dict) -> AsyncAzureOpenAI:
    api_key = cfg.get("api_key")
    if not api_key:
        raise RuntimeError("此 Azure OpenAI provider 未設定 API key")
    endpoint = cfg.get("base_url")
    if not endpoint:
        raise RuntimeError("此 Azure OpenAI provider 未設定 endpoint(base_url)")
    api_version = cfg.get("api_version") or DEFAULT_API_VERSION
    cache_key = (api_key, endpoint, api_version)
    client = _clients.get(cache_key)
    if client is None:
        client = AsyncAzureOpenAI(
            api_key=api_key,
            azure_endpoint=endpoint,
            api_version=api_version,
        )
        _clients[cache_key] = client
    return client


async def stream_chat(
    cfg: dict,
    system_prompt: str,
    messages: list[dict],
    **kw,
) -> AsyncIterator[tuple[str, object]]:
    client = get_client(cfg)
    model = cfg.get("model") or DEFAULT_MODEL  # = deployment 名稱
    async for item in openai_provider.stream_with_client(
        client, model, system_prompt, messages, **kw
    ):
        yield item
