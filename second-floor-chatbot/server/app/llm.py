"""LLM provider 執行期分派器。

不再於 import 時固定挑 provider。改為每次請求向 DB 取「目前啟用的 provider」設定,
依其 type 分派給對應 impl,並把 api_key / model / base_url 當參數傳入(不依賴環境變數)。

provider 設定(可多筆、可切換)由 db.providers 持久化,管理介面在 /admin。

對外介面:
  stream_chat(system_prompt, messages, *, tool_specs, tool_registry, ...) -> AsyncIterator[(kind, payload)]
  is_rate_limit(exc) -> bool
  active_info() -> {"provider": type, "model": model}
  resolve_active() -> dict  解析後的 active config(含預設 URL)
"""

from __future__ import annotations

from collections.abc import AsyncIterator, Callable

from . import azure_provider, db, gemini, openai_provider

_IMPL = {"gemini": gemini, "openai": openai_provider, "azure": azure_provider}


def _impl_for(provider_type: str):
    impl = _IMPL.get((provider_type or "").lower())
    if impl is None:
        raise RuntimeError(f"未知的 provider 類型:{provider_type}")
    return impl


def resolve_active() -> dict:
    """取得目前啟用的 provider,回傳解析後 config。

    依 use_custom_url 決定 base_url:勾自訂用 base_url,否則用該 type 的預設 URL。
    找不到啟用項時 fallback 第一筆;完全沒有 provider 時 raise 友善錯誤。
    """
    providers = db.list_providers()
    if not providers:
        raise RuntimeError("尚未設定任何 LLM provider,請到 /admin 新增並啟用一個。")

    active_id = db.get_setting("active_provider_id")
    active = next((p for p in providers if p["id"] == active_id), None) or providers[0]

    impl = _impl_for(active["type"])
    if active["type"] == "azure":
        # Azure 一定要自訂 endpoint,沒有「預設網址」可用。
        base_url = active["base_url"]
    else:
        base_url = active["base_url"] if active["use_custom_url"] else (impl.DEFAULT_BASE_URL or "")
    return {
        "id": active["id"],
        "type": active["type"],
        "name": active["name"],
        "api_key": active["api_key"],
        "model": active["model"] or impl.DEFAULT_MODEL,
        "base_url": base_url or "",
        "api_version": active.get("api_version") or "",
    }


def active_info() -> dict:
    try:
        cfg = resolve_active()
        return {"provider": cfg["type"], "model": cfg["model"], "name": cfg["name"]}
    except Exception as exc:  # noqa: BLE001
        return {"provider": None, "model": None, "error": str(exc)}


def is_rate_limit(exc: Exception) -> bool:
    try:
        impl = _impl_for(resolve_active()["type"])
    except Exception:  # noqa: BLE001
        # 退而求其次:任一 impl 命中即視為流量上限。
        return gemini.is_rate_limit(exc) or openai_provider.is_rate_limit(exc)
    return impl.is_rate_limit(exc)


def stream_chat(
    system_prompt: str,
    messages: list[dict],
    *,
    tool_specs: list[dict] | None = None,
    tool_registry: dict[str, Callable] | None = None,
    temperature: float = 0.5,
    max_tool_rounds: int = 3,
) -> AsyncIterator[tuple[str, object]]:
    cfg = resolve_active()
    impl = _impl_for(cfg["type"])
    return impl.stream_chat(
        cfg,
        system_prompt,
        messages,
        tool_specs=tool_specs,
        tool_registry=tool_registry,
        temperature=temperature,
        max_tool_rounds=max_tool_rounds,
    )
