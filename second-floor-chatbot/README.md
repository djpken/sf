# Second Floor Chatbot

貳樓 Second Floor Cafe AI 助理 —— **真實 LLM 串接版**(前後端分離)。

由 `second-floor-chatbot-prototype`(腳本機 demo)演進而來:對話改由真實
Gemini 模型驅動,菜單以 RAG 注入 grounding。

## 架構

```
web/                 前端 — Vite + React(沿用 prototype 手機殼 UI)
  src/App.jsx        聊天介面,fetch /api/chat 讀 SSE streaming
server/              後端 — Python + FastAPI
  app/main.py        POST /api/chat(SSE)、GET /api/health
  app/gemini.py      google-genai streaming wrapper
  app/menu.py        RAG:retrieve() 硬篩選 + build_system_prompt()
  app/data/menu.json 菜單單一資料源(51 道,由 prototype MENU_INDEX dump)
```

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

v1 已完成:
- 真實 Gemini streaming 對話、菜單 RAG grounding、忌口硬篩選、前端沿用設計
- **訂位寫入(MOCK)**:Gemini function calling。客人確認後模型呼叫 `submit_reservation`,
  後端回傳模擬單號,前端渲染訂位確認卡。**目前不寫任何真實後台**(待與廠商溝通)。

### 接真實訂位系統時

只需改 `server/app/booking.py` 的 `submit_reservation()` 內部:把 `return` 換成
廠商訂位 API 寫入 + 取得真實單號 + 發送 Line/SMS 通知。對外介面(參數、回傳結構、
function declaration、前端卡片)完全不動。

尚未做(下一版):
- **意圖路由**:難題(多重忌口 + 模糊需求)再 routing 到 Gemini 2.5 Pro
- **對話狀態持久化**:跨裝置會話、歷史紀錄
- **個人化資料層**:會員、歷史偏好、忌口記憶
