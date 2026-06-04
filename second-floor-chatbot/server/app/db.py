"""SQLite 資料層 —— 對話持久化 + 忌口記憶(匿名 session)。

身分:匿名裝置 session_id(前端 localStorage 產生),無登入。
- conversations / messages:對話歷史,可列表、重開續聊
- profiles:長期忌口記憶(不吃豬/牛/海鮮/素/堅果),自動套用到 RAG

所有函式為同步 sqlite3;在 async 端點用 asyncio.to_thread 包起來避免卡事件迴圈。
"""

from __future__ import annotations

import json
import sqlite3
import time
import uuid
from pathlib import Path

_DB_PATH = Path(__file__).parent / "data" / "app.db"

# 只有這些「長期忌口」才寫進 profile 並自動套用;辣度等看當下心情的不長期記。
PROFILE_PREF_KEYS = ("no_pork", "no_beef", "no_seafood", "vegetarian", "no_nuts")


def _conn() -> sqlite3.Connection:
    conn = sqlite3.connect(_DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
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
            CREATE INDEX IF NOT EXISTS idx_conv_session ON conversations(session_id);
            CREATE INDEX IF NOT EXISTS idx_msg_conv ON messages(conversation_id);
            """
        )


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
