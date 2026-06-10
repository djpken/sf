# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Monorepo Layout

```
sf/
├── second-floor-chatbot/       # AI 助理(真實 LLM 串接版) — FastAPI + React
├── second-floor-chatbot-prototype/  # 靜態 prototype，mock LLM，不是主線
├── pos-poc/                    # POS 系統 POC — Go backend + Flutter client
├── sf-pos/                     # iPad POS 設計確認 POC — React/Vite,全 mock
├── warehouse-keeper/           # 倉庫盤點 Flutter app
├── sf-menu/                    # 共用菜單資料源(menu.json + 餐點圖)
└── Design System.html          # 設計 token 參考(色彩/字型/圓角/陰影)
```

每個子專案有自己的 CLAUDE.md(`second-floor-chatbot/CLAUDE.md`、`pos-poc/CLAUDE.md`)含詳細架構說明,根目錄的本檔提供跨子專案的全局視野。

## Design System

**所有 UI 一律遵循 `Design System.html` 的 token 系統**。`second-floor-chatbot/web/src/styles.css` 已把 token 鏡射為 CSS 變數;新樣式用變數、勿寫死色值。

## second-floor-chatbot（主線 chatbot）

```bash
# 後端 (:8000)
cd second-floor-chatbot/server
./.venv/bin/uvicorn app.main:app --reload --port 8000
# 首次: python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt && cp .env.example .env

# 前端 (:5173)
cd second-floor-chatbot/web
npm run dev          # 首次先 npm install
npm run build        # 驗收前端

# 快速健康檢查
curl http://127.0.0.1:8000/api/health
cd second-floor-chatbot/server && ./.venv/bin/python check_key.py
```

無自動化測試套件。驗收方式:`npm run build` 通過 + `/api/health` 正常 + 本機實際操作。

詳細架構見 `second-floor-chatbot/CLAUDE.md`。

## sf-pos（iPad POS 設計確認 POC）

```bash
cd sf-pos
npm run dev          # http://localhost:5173/dev.html
npm run build
```

全前端 mock,不串後端。客戶確認入口:`sf-pos/index.html`(載入 build 靜態 assets)。

## pos-poc（POS 後端 + Flutter 客戶端 POC）

```bash
# Go 後端
cd pos-poc/pos-backend
make dev             # 啟動 PostgreSQL + Redis (Docker Compose)
make run             # 啟動 API server (http://localhost:8080)
make test            # 執行 Go 測試
make migrate-up

# Flutter 客戶端
cd pos-poc/pos_flutter
flutter pub get
flutter run -d macos
flutter test
```

詳細架構見 `pos-poc/CLAUDE.md`。

## warehouse-keeper（倉庫盤點 Flutter app）

```bash
cd warehouse-keeper
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

## second-floor-chatbot-prototype（靜態 prototype，非主線）

```bash
cd second-floor-chatbot-prototype
npm run dev          # Vite dev server
node --test          # 執行 Node test runner 測試
```

這是 LLM 串接前的手稿,`src/systemPrompt.js` 的 `MENU_INDEX` 是 `second-floor-chatbot/server/app/data/menu.json` 的資料來源。兩邊的菜單邏輯行為應對齊。

## Cross-project 資料流

`sf-menu/menu.json` 是所有菜單邏輯的單一資料源:
- `second-floor-chatbot/server/app/data/menu.json` — Python RAG 使用(由 prototype dump 而來)
- `sf-pos/src/pos-data.js` — POS mock data 的品項基礎
- `second-floor-chatbot/web/vite.config.js` 以 `publicDir: '../../sf-menu'` 共用圖片
- `second-floor-chatbot-prototype` 同樣透過 vite publicDir 取用圖片

修改菜單時,確認相關子專案的資料是否需要同步更新。

## 工作分工

- **Claude Code 全程負責** `second-floor-chatbot/`:規劃、實作、驗收。
- `pos-poc/` 與 `warehouse-keeper/` 原由 codex 處理,現可 Claude Code 接手。
- `sf-pos/` 是 React/Vite 靜態 POC,Claude Code 直接改。

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
- Author a backlog-ready spec/issue → invoke /spec
