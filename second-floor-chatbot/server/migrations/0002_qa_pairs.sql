-- admin 在後台設計的「指定問答」(類 skills 的 trigger→answer)。
-- enabled=0 時保留資料但不注入 system prompt;sort_order 控制顯示與注入順序。
BEGIN;
CREATE TABLE IF NOT EXISTS qa_pairs (
  id          TEXT PRIMARY KEY,
  question    TEXT NOT NULL,
  answer      TEXT NOT NULL,
  enabled     INTEGER DEFAULT 1,
  sort_order  INTEGER DEFAULT 0,
  updated_at  REAL
);
COMMIT;
