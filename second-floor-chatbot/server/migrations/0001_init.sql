-- 初始 schema:所有核心資料表與索引。
-- 使用 IF NOT EXISTS,可安全在既有空 DB 或首次建立時執行。
-- BEGIN/COMMIT 確保原子性:executescript() 在執行前自動 COMMIT,
-- 若不包裹則 schema 可能部分套用後 crash 而 _migrations 記錄未寫入。
BEGIN;
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
  type            TEXT NOT NULL,
  api_key         TEXT,
  model           TEXT,
  base_url        TEXT,
  use_custom_url  INTEGER DEFAULT 0,
  api_version     TEXT,
  created_at      REAL
);
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
CREATE INDEX IF NOT EXISTS idx_conv_session ON conversations(session_id);
CREATE INDEX IF NOT EXISTS idx_msg_conv ON messages(conversation_id);
COMMIT;
