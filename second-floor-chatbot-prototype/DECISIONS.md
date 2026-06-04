# 專案決策紀錄 (Second Floor Chatbot Prototype)

## 對話引擎為腳本機,RAG / LLM 尚未串接 — 刻意為之

目前每個場景都是 `src/mockData.js` 裡寫死的 `steps` 腳本,`advanceConversation()`
依序播放預錄回覆。`src/systemPrompt.js`(RAG system prompt + `MENU_INDEX`)已備好但
**刻意尚未接上任何真實 LLM**。

**原因:** 這一版的目的是先讓客戶確認這 6 個場景的「價值定型」是否正確。場景方向
確認後,下一版才會處理 RAG / LLM / 意圖識別 / 對話狀態 / 個人化資料層等真實系統串接。

**因此:** RAG、LLM、後端串接「未完成」是預期狀態,不是缺陷,評估完整度時不需重複提起。

---

## 已知的刻意佔位 (placeholder,非 bug)

- 側欄按鈕「搜尋對話 / 歷史紀錄 / 更多操作」為展示用空殼,本版不實作。

## 菜色卡圖片來源

菜色圖經由 `vite.config.js` 的 `publicDir: '../sf-menu'` 提供,圖檔位於
`../sf-menu/images/*.webp`,目前 8 個 dish-card label 都有對應圖、dev 與
production build(會複製進 `dist/images`)皆正常載入。

`App.jsx` 的 `DishPhoto` 仍保留 `onError` fallback(載入失敗時顯示 2F 字標),
純屬防呆 —— 萬一未來新增的 label 沒有對應圖檔,不會出現瀏覽器破圖 icon。
