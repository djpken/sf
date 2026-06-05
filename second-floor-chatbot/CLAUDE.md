# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> 注意:本檔涵蓋 `second-floor-chatbot/`(真實 LLM 串接版)。monorepo 根目錄的
> `AGENT.md` 是 codex 用的,只涵蓋 `pos-poc/` 與 `warehouse-keeper/`,不含本專案。

## 工作分工(本專案約定)

- **實作交給 codex**:寫程式、改檔案、跑指令的動手部分由 codex 執行。
- **Claude Code 負責規劃與驗收**:拆解需求、設計方案、定義驗收標準,並在 codex 完成後
  做 review 與驗證(跑 build / health check、檢視畫面、對照需求)。
- 預設不要直接動手改 code;先產出計畫與驗收清單。除非使用者明確要求 Claude Code 親自實作。

## 常用指令

兩個服務要分別在不同終端機跑。

```bash
# 後端 (:8000) — FastAPI + LLM streaming
cd server
./.venv/bin/uvicorn app.main:app --reload --port 8000
# 首次:python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt && cp .env.example .env

# 前端 (:5173) — Vite + React,/api 自動 proxy 到 :8000
cd web
npm run dev          # 首次先 npm install
npm run build        # 產出 dist/(驗收前端用)

# 驗收用快速檢查
curl http://127.0.0.1:8000/api/health     # {"ok":true,"provider":"gemini","model":"..."}
./.venv/bin/python check_key.py           # 探測 Gemini key 是否有效/有額度
```

沒有自動化測試套件(無 pytest / vitest)。驗收靠:`npm run build` 通過、`/api/health` 正常、
本機開 http://127.0.0.1:5173 實際操作對話/訂位/歷史/忌口。

## 架構大圖(需跨檔閱讀才懂的部分)

**前後端分離、SSE streaming 對話。** 前端 `web/src/App.jsx` 單檔 fetch `/api/chat` 讀 SSE;
後端 `server/app/main.py` 是唯一 API 入口,串起 RAG → LLM provider → 持久化。

### 三層 LLM provider 分派

`app/llm.py` 依環境變數 `LLM_PROVIDER`(`gemini`|`openai`)在 import 時選一個 provider,
對上層暴露統一介面。**新增/修改 provider 必須維持這個契約**:

- `stream_chat(system_prompt, messages, *, tool_specs, tool_registry)` → async 產出 `(kind, payload)`
  - `kind == "text"` → `payload` 是文字 delta(字串)
  - `kind == "tool"` → `payload` 是 `{"name", "result"}`(工具已在 provider 內執行完)
- `is_rate_limit(exc) -> bool`、模組級 `MODEL` 名稱
- 工具宣告用中性 JSON schema(`booking.py` 的 `RESERVATION_TOOL_SPEC`),各 provider 自行轉成
  Gemini `types.Tool` 或 OpenAI `tools` 格式 — 新工具只在 `booking.py` 定義一次,兩 provider 共用。

### RAG 是「硬篩選」,正確性不靠 model 智商

`app/menu.py` 的 `retrieve()` 把不符合忌口/辣度的菜色**直接排除**,模型只看得到合格清單;
`build_system_prompt()` 再把清單 + 行為守則組成 system prompt。`infer_opts()` 用關鍵字偵測
中文忌口/辣度。設計哲學:**正確性由程式硬篩 + prompt guardrail + function-calling schema 保證**,
因此 model 策略鎖定 `gemini-2.5-flash-lite`,不做 Pro 路由(見 README「Model 策略(已定案)」)。

- `app/data/menu.json` 是菜單**單一資料源**,由 prototype 的 `systemPrompt.js` `MENU_INDEX` dump 而來。
  `retrieve()`/`build_system_prompt()` 是那份 JS 邏輯的忠實 port,**行為要對齊**,改動需兩邊一致。

### 持久化 + 忌口記憶(匿名 session,無登入)

`app/db.py` 同步 sqlite3,在 async 端點一律用 `asyncio.to_thread()` 包起來避免卡事件迴圈。

- 身分 = 前端 localStorage 產生的 `session_id`,綁定對話歷史與忌口 profile。
- **長期 vs 當下的區別很關鍵**:只有 `db.PROFILE_PREF_KEYS`(不吃豬/牛/海鮮/素/堅果)會寫進
  profile 並跨對話自動套用;辣度等「看當下心情」的偵測只用於本次 `retrieve()`,不長期記憶。

### 訂位是 MOCK,介面為接真系統預留 seam

`app/booking.py` 的 `submit_reservation()` 目前只回模擬單號。接真實門市/訂位系統時**只改函式內部**
(換成廠商 API 寫入 + 取真實單號 + Line/SMS 通知),對外介面(參數、回傳結構、`RESERVATION_TOOL_SPEC`、
前端訂位卡)維持不動。

### SSE 事件協定(main.py ↔ App.jsx 的跨檔契約)

`/api/chat` 每筆 `data:` JSON 可能是:`{delta}` 文字增量、`{booking}` 訂位確認卡資料、
`{conversation}` 新建對話 id、`{done:true}` 結束、`{error}` 友善錯誤訊息(429 額度等不丟 500,
改用 `_friendly_error()` 包成可顯示文字)。前端據此分流渲染。

## 環境與慣例

- 後端 secrets 在 `server/.env`(gitignored):`GEMINI_API_KEY`、`GEMINI_MODEL`、`ALLOWED_ORIGINS`;
  openai provider 用 `OPENAI_BASE_URL`/`OPENAI_API_KEY`/`OPENAI_MODEL`。`app/data/app.db` 自動建立、gitignored。
- 前端菜色圖透過 vite `publicDir: '../../sf-menu'` 取用(與 prototype 共用)。
- **UI 一律遵循 `/Users/kunkun/Projects/sf/Design System.html` 的 token 系統**(色彩、字型、圓角、陰影);
  `web/src/styles.css` 頂部已把這些 token 鏡射為 CSS 變數,新樣式用變數、勿寫死色值。
