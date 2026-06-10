# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> 注意:本檔涵蓋 `second-floor-chatbot/`(真實 LLM 串接版)。monorepo 根目錄的
> `AGENT.md` 是 codex 用的,只涵蓋 `pos-poc/` 與 `warehouse-keeper/`,不含本專案。

## 工作分工(本專案約定)

- **Claude Code 全程負責**:規劃、實作、驗收都由 Claude Code 執行 — 拆解需求、設計方案、
  動手寫程式改檔案、跑指令,並自行驗證(跑 build / health check、檢視畫面、對照需求)。
- 不再交給 codex 實作(2026-06 起改為 Claude Code 親自實作)。

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

### LLM provider 分派（動態，Admin 管理）

`app/llm.py` 在執行期從 DB `providers` 表讀取 active provider config（api_key / model / base_url），
**不再**依環境變數在 import 時固定選 provider。Provider 透過 `/admin` 介面管理（新增、切換）。
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
- **送進模型的對話有截斷**:前端每輪送完整歷史,但 `main.py` 只取最近
  `MAX_HISTORY_MESSAGES`(16 則 ≈ 8 來回)進 LLM,避免長對話 token/延遲線性膨脹、
  稀釋 flash-lite 注意力。**持久化(`append_message`)仍存完整歷史**,只裁送模型的部分。
- **分店備註按需帶入**:`_select_store_notes()` 依對話挑分店特色 — 提到特定門市→只給那幾家;
  問到店況關鍵字(包廂/座位/環境…)但沒指名→給全部;純菜單詢問→完全不帶。避免每次扛全部分店。
- **長期 vs 當下的區別很關鍵**:只有 `db.PROFILE_PREF_KEYS`(不吃豬/牛/海鮮/素/堅果)會寫進
  profile 並跨對話自動套用;辣度等「看當下心情」的偵測只用於本次 `retrieve()`,不長期記憶。

### 訂位/查詢是 MOCK,介面為接真系統預留 seam

`app/booking.py` 有三個 mock 工具,**都不接真實門市/訂位系統**,接真系統時只改函式內部,
對外介面(參數、回傳結構、各 `*_TOOL_SPEC`、前端卡片)維持不動:

- `submit_reservation()` — 送出訂位。可能**客滿失敗**(`status:"failed"`,無單號、附 `alternatives` 建議時段)
  或成功(`status:"confirmed"` + 模擬單號)。成功單暫存進**記憶體** `_RESERVATIONS`(非 sqlite,
  避免違反「db 一律走 `to_thread`」的慣例;重啟即清空)。
- `check_availability()` — 查某門市/時段有沒有位(只查不訂)。
- `lookup_reservation()` — 用單號查 `_RESERVATIONS` 裡的既有訂位。

**客滿判定是決定性偽隨機**:`_is_slot_full()` 用 `hash(門市|日期|時段|人數)`,所以同一組輸入永遠
同一結果——「查到客滿就一定訂不到、重試也不跳動」,且 `check_availability` 與 `submit_reservation`
共用它,保證「查到有位→送出就成功、查到客滿→送出就失敗」一致。熱門時段(18–20 點)與大桌(≥6)
客滿機率較高。`submit_reservation`/`lookup_reservation` 為**非 terminal**(結果餵回模型,讓它在
客滿/查無時接話引導);`show_store_card`/`propose_followups` 為 terminal(見下)。

### SSE 事件協定(main.py ↔ App.jsx 的跨檔契約)

`/api/chat` 每筆 `data:` JSON 可能是:
- `{delta}` — 文字增量。
- `{booking}` — 訂位卡資料,含 `status`:`"confirmed"`(成功,有 `booking_id`)或 `"failed"`
  (客滿,有 `alternatives`)。前端據 `status` 渲染確認卡或失敗卡(`App.jsx` `role:'booking'`)。
- `{availability}` — 空位查詢卡(`check_availability` 結果:`available` + 客滿時的 `alternatives`)。
- `{reservation_lookup}` — 訂位查詢卡(`lookup_reservation` 結果:`found` + 明細或查無提示)。
- `{store_card}` — 門市資訊卡(`show_store_card` 結果:地址/電話/時間/標籤/`image` 店面照)。
- `{suggestions:{ask:[...],say:[...]}}` — 建議追問,分「你可能想問」(ask)/「你可能想說」(say)兩類
  (每則回答尾端、`{done}` 之前;訂位回合以 booking 為準會丟棄)。
- `{conversation}` — 新建對話 id。
- `{done:true}` — 結束。
- `{error}` — 友善錯誤訊息(429 額度等不丟 500,改用 `_friendly_error()` 包成可顯示文字)。

前端 `App.jsx` 的 SSE 迴圈據此分流:`booking`/`store_card` 走專屬 append,`availability`/
`reservation_lookup` 走通用 `appendCard(role, data)`,卡片一律插在串流中的助理訊息之前。

### 建議追問(follow-ups)是 terminal 工具,不多打一次 LLM

`booking.py` 的 `propose_followups`(`terminal=True`)由 system prompt 指示模型在每則回答尾端呼叫。
provider(`gemini.py`/`openai_provider.py`)收到 terminal 工具的 function_call 後 yield 即結束,
**不把結果餵回模型、也不為它多起一輪 generate** — 這是「同串流尾端產出、不加重 429 配額」的關鍵。
新增其他「fire-and-forget」工具時比照標 `terminal=True`。前端 chips 不持久化(歷史對話不回填)。

## 環境與慣例

- 後端 secrets 在 `server/.env`(gitignored):目前只需 `ADMIN_TOKEN`、`ALLOWED_ORIGINS`。
  LLM provider 的 api_key / model / base_url **改由 `/admin` 介面設定並存入 SQLite**,不從 env 讀取。
  `app/data/app.db` 自動建立、gitignored。
- 前端菜色圖透過 vite `publicDir: '../../sf-menu'` 取用(與 prototype 共用)。門市店面照放
  `sf-menu/images/stores/<店名>.webp`,由 `app/data/stores.json` 的 `image` 欄位指定;
  缺圖時前端 `StorePhoto` 自動退回帶店名首字的占位 banner(見該資料夾 README)。
- **UI 一律遵循 `/Users/kunkun/Projects/sf/Design System.html` 的 token 系統**(色彩、字型、圓角、陰影);
  `web/src/styles.css` 頂部已把這些 token 鏡射為 CSS 變數,新樣式用變數、勿寫死色值。
