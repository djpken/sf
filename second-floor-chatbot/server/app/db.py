"""SQLite 資料層 —— 對話持久化 + 忌口記憶(匿名 session)。

身分:匿名裝置 session_id(前端 localStorage 產生),無登入。
- conversations / messages:對話歷史,可列表、重開續聊
- profiles:長期忌口記憶(不吃豬/牛/海鮮/素/堅果),自動套用到 RAG

所有函式為同步 sqlite3;在 async 端點用 asyncio.to_thread 包起來避免卡事件迴圈。
"""

from __future__ import annotations

import json
import os
import sqlite3
import time
import uuid
from pathlib import Path

_DB_PATH = Path(os.environ.get("SF_DB_PATH") or (Path(__file__).parent / "data" / "app.db"))

# 只有這些「長期忌口」才寫進 profile 並自動套用;辣度等看當下心情的不長期記。
PROFILE_PREF_KEYS = ("no_pork", "no_beef", "no_seafood", "vegetarian", "no_nuts")


def _conn() -> sqlite3.Connection:
    conn = sqlite3.connect(_DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init() -> None:
    with _conn() as c:
        c.executescript(
            """
            CREATE TABLE IF NOT EXISTS conversations (
              id          TEXT PRIMARY KEY,
              session_id  TEXT NOT NULL,
              title       TEXT,
              created_at  REAL,
              updated_at  REAL
            );
            CREATE TABLE IF NOT EXISTS messages (
              id              INTEGER PRIMARY KEY AUTOINCREMENT,
              conversation_id TEXT NOT NULL,
              role            TEXT NOT NULL,
              content         TEXT NOT NULL,
              created_at      REAL
            );
            CREATE TABLE IF NOT EXISTS profiles (
              session_id  TEXT PRIMARY KEY,
              prefs       TEXT,
              updated_at  REAL
            );
            CREATE TABLE IF NOT EXISTS providers (
              id              TEXT PRIMARY KEY,
              name            TEXT NOT NULL,
              type            TEXT NOT NULL,          -- 'gemini' | 'openai' | 'azure'
              api_key         TEXT,
              model           TEXT,                   -- azure 時 = deployment 名稱
              base_url        TEXT,                   -- 自訂 URL;空字串=用預設;azure=resource endpoint
              use_custom_url  INTEGER DEFAULT 0,
              api_version     TEXT,                   -- 僅 azure 用
              created_at      REAL
            );
            CREATE TABLE IF NOT EXISTS app_settings (
              key    TEXT PRIMARY KEY,
              value  TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_conv_session ON conversations(session_id);
            CREATE INDEX IF NOT EXISTS idx_msg_conv ON messages(conversation_id);
            """
        )
        # 既有 db 遷移:補上後加的欄位
        cols = {r["name"] for r in c.execute("PRAGMA table_info(providers)").fetchall()}
        if "api_version" not in cols:
            c.execute("ALTER TABLE providers ADD COLUMN api_version TEXT")
    seed_providers_from_env()


# ─── conversations ──────────────────────────────────────────────────────────

def create_conversation(session_id: str, title: str) -> dict:
    cid = uuid.uuid4().hex
    now = time.time()
    with _conn() as c:
        c.execute(
            "INSERT INTO conversations (id, session_id, title, created_at, updated_at)"
            " VALUES (?, ?, ?, ?, ?)",
            (cid, session_id, title[:40], now, now),
        )
    return {"id": cid, "title": title[:40], "updated_at": now}


def touch_conversation(conversation_id: str) -> None:
    with _conn() as c:
        c.execute(
            "UPDATE conversations SET updated_at = ? WHERE id = ?",
            (time.time(), conversation_id),
        )


def list_conversations(session_id: str) -> list[dict]:
    with _conn() as c:
        rows = c.execute(
            "SELECT id, title, updated_at FROM conversations"
            " WHERE session_id = ? ORDER BY updated_at DESC",
            (session_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def delete_conversation(session_id: str, conversation_id: str) -> None:
    with _conn() as c:
        owned = c.execute(
            "SELECT 1 FROM conversations WHERE id = ? AND session_id = ?",
            (conversation_id, session_id),
        ).fetchone()
        if not owned:
            return
        c.execute("DELETE FROM messages WHERE conversation_id = ?", (conversation_id,))
        c.execute("DELETE FROM conversations WHERE id = ?", (conversation_id,))


def append_message(conversation_id: str, role: str, content: str) -> None:
    with _conn() as c:
        c.execute(
            "INSERT INTO messages (conversation_id, role, content, created_at)"
            " VALUES (?, ?, ?, ?)",
            (conversation_id, role, content, time.time()),
        )


def get_messages(session_id: str, conversation_id: str) -> list[dict]:
    """取某段對話的訊息;驗證該對話屬於此 session(避免越權讀別人的)。"""
    with _conn() as c:
        owned = c.execute(
            "SELECT 1 FROM conversations WHERE id = ? AND session_id = ?",
            (conversation_id, session_id),
        ).fetchone()
        if not owned:
            return []
        rows = c.execute(
            "SELECT role, content FROM messages WHERE conversation_id = ? ORDER BY id",
            (conversation_id,),
        ).fetchall()
    return [{"role": r["role"], "content": r["content"]} for r in rows]


# ─── profiles(忌口記憶) ────────────────────────────────────────────────────

def get_profile(session_id: str) -> dict:
    with _conn() as c:
        row = c.execute(
            "SELECT prefs FROM profiles WHERE session_id = ?", (session_id,)
        ).fetchone()
    if not row or not row["prefs"]:
        return {}
    try:
        return json.loads(row["prefs"])
    except (ValueError, TypeError):
        return {}


def merge_profile(session_id: str, new_prefs: dict) -> dict:
    """把新偵測到的長期忌口併入 profile(只收 PROFILE_PREF_KEYS)。回傳合併後結果。"""
    filtered = {k: v for k, v in new_prefs.items() if k in PROFILE_PREF_KEYS and v}
    current = get_profile(session_id)
    if not filtered:
        return current
    merged = {**current, **filtered}
    with _conn() as c:
        c.execute(
            "INSERT INTO profiles (session_id, prefs, updated_at) VALUES (?, ?, ?)"
            " ON CONFLICT(session_id) DO UPDATE SET prefs = excluded.prefs,"
            " updated_at = excluded.updated_at",
            (session_id, json.dumps(merged, ensure_ascii=False), time.time()),
        )
    return merged


def clear_profile(session_id: str) -> None:
    with _conn() as c:
        c.execute("DELETE FROM profiles WHERE session_id = ?", (session_id,))


# ─── app_settings(鍵值設定,如目前啟用的 provider) ──────────────────────────

def get_setting(key: str) -> str | None:
    with _conn() as c:
        row = c.execute(
            "SELECT value FROM app_settings WHERE key = ?", (key,)
        ).fetchone()
    return row["value"] if row else None


def set_setting(key: str, value: str) -> None:
    with _conn() as c:
        c.execute(
            "INSERT INTO app_settings (key, value) VALUES (?, ?)"
            " ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            (key, value),
        )


# ─── providers(LLM provider 設定,可多筆、可切換) ───────────────────────────

_PROVIDER_FIELDS = (
    "name", "type", "api_key", "model", "base_url", "use_custom_url", "api_version",
)


def _row_to_provider(row: sqlite3.Row) -> dict:
    keys = row.keys()
    return {
        "id": row["id"],
        "name": row["name"],
        "type": row["type"],
        "api_key": row["api_key"] or "",
        "model": row["model"] or "",
        "base_url": row["base_url"] or "",
        "use_custom_url": bool(row["use_custom_url"]),
        "api_version": (row["api_version"] if "api_version" in keys else None) or "",
        "created_at": row["created_at"],
    }


def list_providers() -> list[dict]:
    with _conn() as c:
        rows = c.execute(
            "SELECT * FROM providers ORDER BY created_at ASC"
        ).fetchall()
    return [_row_to_provider(r) for r in rows]


def get_provider(provider_id: str) -> dict | None:
    with _conn() as c:
        row = c.execute(
            "SELECT * FROM providers WHERE id = ?", (provider_id,)
        ).fetchone()
    return _row_to_provider(row) if row else None


def create_provider(data: dict) -> dict:
    pid = uuid.uuid4().hex
    with _conn() as c:
        c.execute(
            "INSERT INTO providers (id, name, type, api_key, model, base_url,"
            " use_custom_url, api_version, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                pid,
                data.get("name", "") or data.get("type", "provider"),
                data.get("type", "gemini"),
                data.get("api_key", ""),
                data.get("model", ""),
                data.get("base_url", ""),
                1 if data.get("use_custom_url") else 0,
                data.get("api_version", ""),
                time.time(),
            ),
        )
    return get_provider(pid)


def update_provider(provider_id: str, data: dict) -> dict | None:
    """更新 provider。api_key 傳入空值時保留原值(避免遮罩後被清空)。"""
    existing = get_provider(provider_id)
    if not existing:
        return None
    merged = {**existing}
    for f in _PROVIDER_FIELDS:
        if f not in data:
            continue
        if f == "api_key" and not data[f]:
            continue  # 空 api_key = 不變更
        merged[f] = data[f]
    with _conn() as c:
        c.execute(
            "UPDATE providers SET name = ?, type = ?, api_key = ?, model = ?,"
            " base_url = ?, use_custom_url = ?, api_version = ? WHERE id = ?",
            (
                merged["name"],
                merged["type"],
                merged["api_key"],
                merged["model"],
                merged["base_url"],
                1 if merged["use_custom_url"] else 0,
                merged.get("api_version", ""),
                provider_id,
            ),
        )
    return get_provider(provider_id)


def delete_provider(provider_id: str) -> None:
    with _conn() as c:
        c.execute("DELETE FROM providers WHERE id = ?", (provider_id,))
    # 若刪掉的是 active,自動把 active 指到剩下的第一筆(或清空)
    if get_setting("active_provider_id") == provider_id:
        remaining = list_providers()
        set_setting("active_provider_id", remaining[0]["id"] if remaining else "")


def seed_providers_from_env() -> None:
    """首次啟動且 providers 表為空時,依 .env 建立預設 provider,沿用既有設定。"""
    if list_providers():
        return
    active_type = (os.environ.get("LLM_PROVIDER", "gemini") or "gemini").lower()
    created: dict[str, str] = {}

    gemini_key = os.environ.get("GEMINI_API_KEY", "")
    if gemini_key and gemini_key != "your-aistudio-api-key-here":
        p = create_provider({
            "name": "Gemini",
            "type": "gemini",
            "api_key": gemini_key,
            "model": os.environ.get("GEMINI_MODEL", "gemini-2.5-flash-lite"),
            "base_url": "",
            "use_custom_url": False,
        })
        created["gemini"] = p["id"]

    openai_key = os.environ.get("OPENAI_API_KEY", "")
    if openai_key and openai_key != "your-openai-compatible-key":
        base_url = os.environ.get("OPENAI_BASE_URL", "")
        p = create_provider({
            "name": "OpenAI",
            "type": "openai",
            "api_key": openai_key,
            "model": os.environ.get("OPENAI_MODEL", "openai/Qwen3.5-122B-A10B"),
            "base_url": base_url,
            "use_custom_url": bool(base_url),
        })
        created["openai"] = p["id"]

    if created:
        active_id = created.get(active_type) or next(iter(created.values()))
        set_setting("active_provider_id", active_id)
