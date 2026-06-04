# Second Floor Chatbot

貳樓 Second Floor Cafe AI 助理 —— **真實 LLM 串接版**(前後端分離)。

由 `second-floor-chatbot-prototype`(腳本機 demo)演進而來:對話改由真實
Gemini 模型驅動,菜單以 RAG 注入 grounding。

## 架構

```
web/                 前端 — Vite + React(沿用 prototype 手機殼 UI)
  src/App.jsx        聊天介面,fetch /api/chat 讀 SSE streaming
server/              後端 — Python + FastAPI
  app/main.py        /api/chat(SSE)、conversations、profile 等端點
  app/gemini.py      google-genai streaming + function calling wrapper
  app/menu.py        RAG:retrieve() 硬篩選 + build_system_prompt()
  app/booking.py     訂位 function calling(目前 MOCK)
  app/db.py          SQLite:對話持久化 + 忌口記憶
  app/data/menu.json 菜單單一資料源(51 道,由 prototype MENU_INDEX dump)
  app/data/app.db    SQLite 檔(gitignored,自動建立)
```

### API 端點

| 端點 | 用途 |
|------|------|
| `POST /api/chat` | 對話 SSE streaming(套用記憶忌口、持久化) |
| `GET /api/conversations` | 列出此 session 的對話 |
| `GET /api/conversations/{id}` | 取某段對話訊息(重開續聊) |
| `DELETE /api/conversations/{id}` | 刪除對話 |
| `GET /api/profile` | 取記住的忌口 |
| `DELETE /api/profile` | 清除忌口記憶 |
| `GET /api/health` | 健康檢查 + 目前 model |

- **Model**:Gemini **2.5 Flash-Lite**(env `GEMINI_MODEL` 可切 flash / pro)
- **RAG**:依使用者訊息偵測忌口/辣度 → `retrieve()` 把不合格菜色硬篩掉 →
  只把合格清單 + 行為守則注入 system prompt。正確性靠程式 + prompt,不靠大 model。
- **菜色圖**:沿用 `../sf-menu`(vite `publicDir`)

## 跑起來

需要兩個終端機。

### 後端(:8000)

```bash
cd server
python3 -m venv .venv
./.venv/bin/pip install -r requirements.txt
cp .env.example .env          # 填入你的 GEMINI_API_KEY
./.venv/bin/uvicorn app.main:app --reload --port 8000
```

### 前端(:5173)

```bash
cd web
npm install
npm run dev                   # /api 會 proxy 到 :8000
```

開 http://127.0.0.1:5173

### 快速檢查

```bash
curl http://127.0.0.1:8000/api/health
# {"ok":true,"model":"gemini-2.5-flash-lite"}
```

## 環境變數(server/.env,已 gitignore)

| 變數 | 說明 |
|------|------|
| `GEMINI_API_KEY` | Google AI Studio key(**勿進版控**) |
| `GEMINI_MODEL` | 預設 `gemini-2.5-flash-lite` |
| `ALLOWED_ORIGINS` | CORS 允許來源,逗號分隔 |

## 目前範圍 / 下一步

已完成:
- 真實 Gemini streaming 對話、菜單 RAG grounding、忌口硬篩選、前端沿用設計
- **訂位寫入(MOCK)**:Gemini function calling。客人確認後模型呼叫 `submit_reservation`,
  後端回傳模擬單號,前端渲染訂位確認卡。**目前不寫任何真實後台**(待與廠商溝通)。
- **對話持久化**:匿名裝置 session(localStorage,無登入)。對話存 SQLite,
  側欄可看歷史、重開續聊、刪除。
- **忌口記憶**:長期忌口(不吃豬/牛/海鮮/素/堅果)自動記住並套用到 RAG,
  跨對話有效;前端 chip 顯示、可一鍵清除。辣度等看當下心情的不長期記。

### 接真實訂位系統時

只需改 `server/app/booking.py` 的 `submit_reservation()` 內部:把 `return` 換成
廠商訂位 API 寫入 + 取得真實單號 + 發送 Line/SMS 通知。對外介面(參數、回傳結構、
function declaration、前端卡片)完全不動。

### Model 策略(已定案)

**一律使用 Gemini 2.5 Flash-Lite,不做 Pro 路由。** 本系統的正確性靠 RAG 硬篩選
+ system prompt guardrail + function calling schema 保證,不靠 model 智商;Flash-Lite
已驗證能處理菜單推薦、忌口篩選、多輪訂位、function calling。Pro 是預先優化,先不加。
日後若有真實資料顯示某類失敗純屬「推理不夠」(非 RAG/prompt 可修),再針對該類評估。
（env `GEMINI_MODEL` 仍可手動切換,但預設與建議都是 flash-lite。）

尚未做(下一版):
- **真實會員登入**:目前是匿名裝置 session,只能同裝置續聊。要跨裝置同步需做
  註冊/登入(email 或 OAuth),把 session 綁到會員帳號。
- **歷史訂單偏好**:訂位寫入接真系統後,才有真實歷史可做更深的個人化推薦。
