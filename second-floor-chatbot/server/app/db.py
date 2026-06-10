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
_MIGRATIONS_DIR = Path(__file__).parent.parent / "migrations"

# 只有這些「長期忌口」才寫進 profile 並自動套用;辣度等看當下心情的不長期記。
PROFILE_PREF_KEYS = ("no_pork", "no_beef", "no_seafood", "vegetarian", "no_nuts")


def _conn() -> sqlite3.Connection:
    conn = sqlite3.connect(_DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def _run_migrations() -> None:
    """依序套用 migrations/*.sql,每個只跑一次,結果記在 _migrations 表。"""
    _DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(_DB_PATH), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    try:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS _migrations"
            " (name TEXT PRIMARY KEY, applied_at REAL)"
        )
        conn.commit()

        tables = {
            r[0]
            for r in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
        applied = {r[0] for r in conn.execute("SELECT name FROM _migrations").fetchall()}

        # Bootstrap:既有 DB 沒有 _migrations 表時,直接標記 0001_init 為已套用。
        # 同時補上歷史上曾以 ad-hoc 方式新增的 api_version 欄位(如果還沒有),
        # 並建立 0001_init 之後才新增的 app_settings/store_notes/menu_notes 表。
        if "conversations" in tables and not applied:
            conn.execute(
                "INSERT OR IGNORE INTO _migrations (name, applied_at) VALUES (?, ?)",
                ("0001_init", time.time()),
            )
            cols = {
                r["name"]
                for r in conn.execute("PRAGMA table_info(providers)").fetchall()
            }
            if "api_version" not in cols:
                conn.execute("ALTER TABLE providers ADD COLUMN api_version TEXT")
            # 補建可能因舊版 init() 未建立的新資料表
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS app_settings (
                  key    TEXT PRIMARY KEY,
                  value  TEXT
                );
                CREATE TABLE IF NOT EXISTS store_notes (
                  store_name       TEXT PRIMARY KEY,
                  seating_capacity INTEGER,
                  table_spacing    TEXT,
                  has_private_room INTEGER DEFAULT 0,
                  has_outdoor      INTEGER DEFAULT 0,
                  noise_level      TEXT,
                  notes            TEXT,
                  updated_at       REAL
                );
                CREATE TABLE IF NOT EXISTS menu_notes (
                  item_name        TEXT PRIMARY KEY,
                  spice_adjustable INTEGER DEFAULT 0,
                  notes            TEXT,
                  updated_at       REAL
                );
                """
            )
            conn.commit()
            applied = {r[0] for r in conn.execute("SELECT name FROM _migrations").fetchall()}

        for path in sorted(_MIGRATIONS_DIR.glob("*.sql")):
            name = path.stem
            if name in applied:
                continue
            conn.executescript(path.read_text(encoding="utf-8"))
            conn.execute(
                "INSERT INTO _migrations (name, applied_at) VALUES (?, ?)",
                (name, time.time()),
            )
            conn.commit()
    finally:
        conn.close()


def init() -> None:
    _run_migrations()


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


def conversation_owned_by(session_id: str, conversation_id: str) -> bool:
    """確認對話屬於此 session;用於防止 IDOR 跨 session 注入。"""
    with _conn() as c:
        row = c.execute(
            "SELECT 1 FROM conversations WHERE id = ? AND session_id = ?",
            (conversation_id, session_id),
        ).fetchone()
    return row is not None


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


# ─── store_notes(分店特色資訊) ─────────────────────────────────────────────

def _row_to_store_notes(row: sqlite3.Row) -> dict:
    return {
        "seating_capacity": row["seating_capacity"],
        "table_spacing": row["table_spacing"] or "",
        "has_private_room": bool(row["has_private_room"]),
        "has_outdoor": bool(row["has_outdoor"]),
        "noise_level": row["noise_level"] or "",
        "notes": row["notes"] or "",
    }


def list_store_notes() -> dict:
    """回傳 {store_name: notes_dict}。"""
    with _conn() as c:
        rows = c.execute("SELECT * FROM store_notes").fetchall()
    return {row["store_name"]: _row_to_store_notes(row) for row in rows}


def upsert_store_notes(store_name: str, data: dict) -> dict:
    with _conn() as c:
        c.execute(
            "INSERT INTO store_notes"
            " (store_name, seating_capacity, table_spacing, has_private_room,"
            "  has_outdoor, noise_level, notes, updated_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            " ON CONFLICT(store_name) DO UPDATE SET"
            " seating_capacity=excluded.seating_capacity,"
            " table_spacing=excluded.table_spacing,"
            " has_private_room=excluded.has_private_room,"
            " has_outdoor=excluded.has_outdoor,"
            " noise_level=excluded.noise_level,"
            " notes=excluded.notes,"
            " updated_at=excluded.updated_at",
            (
                store_name,
                data.get("seating_capacity") or None,
                data.get("table_spacing") or "",
                1 if data.get("has_private_room") else 0,
                1 if data.get("has_outdoor") else 0,
                data.get("noise_level") or "",
                data.get("notes") or "",
                time.time(),
            ),
        )
    with _conn() as c:
        row = c.execute(
            "SELECT * FROM store_notes WHERE store_name = ?", (store_name,)
        ).fetchone()
    return _row_to_store_notes(row)


# ─── menu_notes(菜單品項備注) ──────────────────────────────────────────────

def list_menu_notes() -> dict:
    """回傳 {item_name: notes_dict}。"""
    with _conn() as c:
        rows = c.execute("SELECT * FROM menu_notes").fetchall()
    return {
        row["item_name"]: {
            "spice_adjustable": bool(row["spice_adjustable"]),
            "notes": row["notes"] or "",
        }
        for row in rows
    }


def upsert_menu_note(item_name: str, data: dict) -> dict:
    with _conn() as c:
        c.execute(
            "INSERT INTO menu_notes (item_name, spice_adjustable, notes, updated_at)"
            " VALUES (?, ?, ?, ?)"
            " ON CONFLICT(item_name) DO UPDATE SET"
            " spice_adjustable=excluded.spice_adjustable,"
            " notes=excluded.notes,"
            " updated_at=excluded.updated_at",
            (
                item_name,
                1 if data.get("spice_adjustable") else 0,
                data.get("notes") or "",
                time.time(),
            ),
        )
    with _conn() as c:
        row = c.execute(
            "SELECT * FROM menu_notes WHERE item_name = ?", (item_name,)
        ).fetchone()
    return {"spice_adjustable": bool(row["spice_adjustable"]), "notes": row["notes"] or ""}
