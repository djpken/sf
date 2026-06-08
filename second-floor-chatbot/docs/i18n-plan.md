# 計畫：i18n（繁中 + 英文）

> 決策已定：語言 = `zh-TW`(預設) + `en`；菜名保留中文、描述讓模型即時翻譯；語言 = 自動偵測 + 可手動覆蓋。

## 核心問題：對話需要調整嗎？

**需要。** UI 字串只是表層,對話層有 4 處要動,其中 1 處是正確性風險：

1. **回應語言指令**(必做) — system prompt 目前硬寫「說繁體中文」。
2. **忌口偵測 `infer_opts`**(必做·正確性) — 純中文關鍵字,英文「no pork」偵測不到 → RAG 硬篩失效 → 可能推薦含豬給說不吃豬的人。
3. **後端生成字串**(必做) — 429 錯誤文案、booking 測試提示。
4. **追問工具語言**(必做) — `propose_followups` 描述寫死繁中,要改成「跟回覆同語言」。

菜單資料本身**不動**(菜名留中文,描述由模型翻),所以 menu.json 零維護。

## Locale 模型
- locales：`zh-TW`(fallback)、`en`。
- 偵測：首次載入看 `navigator.language`,`en*` → en,否則 zh-TW;存 `localStorage.sf_locale`。
- 覆蓋：header 語言選擇器,選了即存 + 重送。`document.documentElement.lang` 同步。

## Phase 1 — 讓它動起來（前端 i18n + 回應語言）

### 前端 web/
- 新增 `src/i18n.js`：`{ 'zh-TW': {...}, en: {...} }` 字典 + `t(locale, key)`(這 app 約 40 條字串,輕量自製即可;react-i18next 為可選替代)。
- `App.jsx`：
  - `const [locale, setLocale] = useState(getLocale())`,`useEffect` 同步 `<html lang>` + localStorage。
  - 所有靜態字串改 `t()`：welcome 標題/副標、`STARTERS`(改 per-locale 陣列)、composer placeholder、側欄(新對話/歷史對話/還沒有對話紀錄)、複製/已複製、error、追問標題(你可能想問/想說)、booking 卡標籤(時段/人數/備註/訂位已送出·測試提示)。
  - `formatTime` → `new Intl.DateTimeFormat(locale, {hour:'numeric',minute:'2-digit'})`,移除手寫「上午/下午」。
  - header 加語言選擇器。
  - `/api/chat` body 加 `locale`。

### 後端 server/
- `ChatRequest` 加 `locale: str = "zh-TW"`。
- `menu.py` `build_system_prompt(items, locale="zh-TW")`：prompt 骨架維持中文(對模型的指令),但**回應語言指令依 locale**：
  - en：「Respond in English. Keep dish names in their original Chinese (a short English gloss is fine). Translate descriptions to English.」
  - zh-TW：維持現狀。
- `main.py`：把 `req.locale` 傳進 `build_system_prompt`。
- `booking.py` `propose_followups` 工具描述：「用與你回覆相同的語言」(移除寫死繁中)。

**Phase 1 完成效果**：切英文 → AI 回覆 + 追問(ask/say) 都英文、菜名留中文、描述翻英;UI 全英文。

## Phase 2 — 補正確性破口 + 後端字串

- `infer_opts`：**同時跑中英關鍵字表(union)**,容忍中英夾雜,不需 locale 參數即安全。英文表至少涵蓋：
  - no pork / pork-free / without pork；no beef；no seafood / shellfish allergy；
  - vegetarian / vegan / veggie；not spicy / mild / no chili；
  - no alcohol / non-alcoholic / pregnant；nut allergy。
- `_friendly_error(exc, locale)`：429/一般錯誤文案本地化。
- booking「測試訂位」提示：改由前端依 locale 渲染(後端 message 可留作備援)。
- `_remembered_pref_hint`：對模型的 context,可留中文(模型會用回應語言轉述);要更乾淨可一併本地化。

## 不在範圍
- 完整菜單翻譯欄位(已決定走即時翻譯)。
- 日文/簡中等其他語言、RTL layout。
- 歷史對話回溯翻譯(已存的是當時語言,維持原樣)。

## DB
不用改。訊息存純文字,任何語言皆可。(可選:`conversations` 加 `lang` 欄,讓重開時 UI 一致,非必須。)
