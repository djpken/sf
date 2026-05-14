# sf-pos

餐廳 iPad POS 操作端 POC，情境設定為「藍牛牛排館」晚餐時段。此版本聚焦在前期提案展示需要的 UX、workflow 與功能行為：選桌、開桌、點餐、送廚房、追出餐、結帳與清桌。

## 開啟方式

```bash
rtk npm run dev
```

瀏覽器開啟：

```text
http://localhost:5173/
```

## 設計目標

- 第一視窗就是橫向 iPad POS，不做 landing page。
- 讓 user 看到服務人員拿 iPad 操作的主要工作流，而不是後台 Dashboard。
- 把桌況、菜單、桌單與下一步動作放在同一個操作面。
- 用 mock state 支援完整互動：加入品項、調整數量、送單、標記上餐、結帳清桌。
- 檔名與模組邊界改成後續移植更直覺的結構。

## 目前結構

- `index.html`: 靜態 POC 入口，載入 React/Babel 與本地檔案。
- `src/main.jsx`: React 掛載點。
- `src/ipad-pos.jsx`: iPad POS 主流程與狀態。
- `src/pos-ui.jsx`: 共用 UI primitives 與格式化 helper。
- `src/pos-data.js`: 桌位、菜單、規格與備註 mock data。
- `src/styles.css`: iPad frame、POS layout 與元件樣式。

## 可展示 Workflow

1. 從左側選桌與區域。
2. 設定人數並開桌。
3. 在中間菜單選分類、熟度、備註並加入品項。
4. 從右側桌單調整數量或移除品項。
5. 送單到廚房，切到出餐流程。
6. 標記單品或整桌上餐。
7. 前往結帳，套用折扣、選付款方式。
8. 完成結帳並清桌。

## POC 注意事項

- 目前不串後端、不做登入權限、不保存 localStorage。
- 重點是操作動線、畫面資訊密度與互動行為。
- 付款、廚房、桌位狀態皆為前端 mock state。

## 驗證

使用本機 HTTP server 與 Playwright smoke test 驗證主要流程可操作。
