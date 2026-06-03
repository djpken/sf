# sf-pos Phase A 實現計劃

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推薦）或 superpowers:executing-plans 逐任務實現此計劃。步驟使用復選框（`- [ ]`）語法來跟蹤進度。

**目標：** 穩定現有 iPad POS 核心流程，讓開桌、點餐、送廚、出餐、回訪、結帳與清桌在 mock state 中一致運作。

**架構：** 保留現有 React/Vite 單頁 POC，先在 `src/ipad-pos.jsx` 中抽出小型狀態 helper，避免大規模重構。以 Playwright smoke test 驅動行為修正，再補 UI/CSS 打磨。

**技術棧：** React, Vite, CSS, Playwright, Node.js CommonJS smoke test.

---

## 文件結構

- 修改 `sf-pos/src/ipad-pos.jsx`: POS 狀態轉換、訂單 overlay、drawer、checkout、helper 函式。
- 修改 `sf-pos/src/styles.css`: Phase A UI/UX 修正，包含長文字、disabled sent line、行動 CTA、桌卡與 overlay 細節。
- 修改 `sf-pos/tests/smoke-pos.cjs`: 新增紅燈測試與完整 smoke regression。
- 可能修改 `sf-pos/src/pos-ui.jsx`: 若需要共用 disabled icon/button 樣式。
- 不修改 `sf-pos/src/pos-data.js`，除非測試需要更穩定的 mock 初始資料。

## 任務 1：追加點餐不覆蓋既有送廚品項

**文件：**
- 修改：`sf-pos/tests/smoke-pos.cjs`
- 修改：`sf-pos/src/ipad-pos.jsx`

- [ ] **步驟 1：編寫失敗測試**

在 `tests/smoke-pos.cjs` 中，在 106 桌第一次送單後，再打開同桌點餐，新增另一個品項並送出。測試應確認第一次送出的 `水牛城辣雞翅` 仍存在，新增品項也存在。

```js
await page.locator('.floor-table').filter({ hasText: /^106/ }).click();
await page.getByRole('button', { name: '繼續點餐' }).click();
await page.getByRole('button', { name: /舊金山蒜香薯條/ }).click();
await page.getByRole('button', { name: '送出訂單 · 開始計時' }).click();
await mustBeVisible(page.getByText('水牛城辣雞翅').first(), 'first sent item remains after append order');
await mustBeVisible(page.getByText('舊金山蒜香薯條').first(), 'new appended item appears after append order');
```

- [ ] **步驟 2：執行測試確認失敗**

執行：`node tests/smoke-pos.cjs`

預期：FAIL，原因是第二次送單覆蓋了第一次送出的品項。

- [ ] **步驟 3：最少實作**

修改 `submitOrder(tableId, draftLines)`，只將未送廚的新 draft lines 轉為 sent，並與既有 sent lines 合併。

```js
setOrders((prev) => {
  const existing = prev[tableId] || [];
  const existingIds = new Set(existing.map((line) => line.id));
  const nextDraftLines = draftLines
    .filter((line) => !line.sent && !existingIds.has(line.id))
    .map((line) => ({ ...line, sent: true }));
  return { ...prev, [tableId]: [...existing, ...nextDraftLines] };
});
```

- [ ] **步驟 4：執行測試確認通過**

執行：`node tests/smoke-pos.cjs`

預期：PASS。

## 任務 2：點餐 overlay 區分已送與未送品項

**文件：**
- 修改：`sf-pos/tests/smoke-pos.cjs`
- 修改：`sf-pos/src/ipad-pos.jsx`
- 修改：`sf-pos/src/styles.css`

- [ ] **步驟 1：編寫失敗測試**

在追加點餐 overlay 打開後，測試已送廚品項顯示為不可移除，且新增 draft 品項可以移除。

```js
await mustBeVisible(page.getByText('已送廚不可移除'), 'sent line locked hint');
await page.getByRole('button', { name: /移除 舊金山蒜香薯條/ }).click();
await mustBeVisible(page.getByText('尚未點選任何品項'), 'draft line can still be removed');
```

- [ ] **步驟 2：執行測試確認失敗**

執行：`node tests/smoke-pos.cjs`

預期：FAIL，原因是目前移除按鈕名稱不含品項，且 sent line 仍可移除。

- [ ] **步驟 3：最少實作**

在 `OrderOverlay` 的 `removeFromCart` 中禁止刪除 `line.sent`。渲染 sent line 時顯示 `已送廚不可移除`，draft line 的 IconButton label 改為 `移除 ${line.name}`。

```jsx
function removeFromCart(lineId) {
  setCart((prev) => prev.filter((line) => line.sent || line.id !== lineId));
}
```

- [ ] **步驟 4：執行測試確認通過**

執行：`node tests/smoke-pos.cjs`

預期：PASS。

## 任務 3：補數量調整與實際結帳金額

**文件：**
- 修改：`sf-pos/tests/smoke-pos.cjs`
- 修改：`sf-pos/src/ipad-pos.jsx`
- 修改：`sf-pos/src/styles.css`

- [ ] **步驟 1：編寫失敗測試**

在 draft 品項加入購物車後點擊增加，確認小計改變；結帳佇列與 drawer 使用實際訂單合計，而不是 `estimateTotal()`。

```js
await page.getByRole('button', { name: /水牛城辣雞翅/ }).click();
await page.getByLabel('增加 水牛城辣雞翅').click();
await mustBeVisible(page.getByText('NT$ 680'), 'cart subtotal reflects quantity change');
```

- [ ] **步驟 2：執行測試確認失敗**

執行：`node tests/smoke-pos.cjs`

預期：FAIL，原因是 order overlay 沒有數量調整控制。

- [ ] **步驟 3：最少實作**

在 `OrderOverlay` 增加 `updateCartQty(lineId, qty)`，draft lines 顯示 Stepper，sent lines 顯示鎖定數量。新增 helper `tableOrderTotal(tableId, orders)`，CheckoutBoard 和 TableCard 優先使用實際訂單 total。

- [ ] **步驟 4：執行測試確認通過**

執行：`node tests/smoke-pos.cjs`

預期：PASS。

## 任務 4：整桌出餐與待訪轉換

**文件：**
- 修改：`sf-pos/tests/smoke-pos.cjs`
- 修改：`sf-pos/src/ipad-pos.jsx`

- [ ] **步驟 1：編寫失敗測試**

在出菜追蹤或 drawer 中標記 106 桌所有品項已上餐，確認桌位狀態變成 `待訪桌` 或可明確進入待訪。

```js
await page.locator('.side-nav button').filter({ hasText: '出菜追蹤' }).click();
await page.locator('.dish-card').filter({ hasText: '106 桌' }).getByRole('button', { name: '已上餐' }).click();
await page.locator('.side-nav button').filter({ hasText: '訪桌紀錄' }).click();
await mustBeVisible(page.getByText('106'), 'served table appears in visit flow');
```

- [ ] **步驟 2：執行測試確認失敗**

執行：`node tests/smoke-pos.cjs`

預期：FAIL 或 106 只停在 `已上齊`，沒有進入訪桌流程。

- [ ] **步驟 3：最少實作**

新增 `markAllServed(tableId)`，並在所有 sent lines served 後將 table 狀態設為 `waitingVisit`。保留 checkout board 對 `served` 與 `waitingVisit` 的支援。

- [ ] **步驟 4：執行測試確認通過**

執行：`node tests/smoke-pos.cjs`

預期：PASS。

## 任務 5：UIUX 打磨與驗證

**文件：**
- 修改：`sf-pos/src/styles.css`
- 修改：`sf-pos/tests/smoke-pos.cjs`

- [ ] **步驟 1：編寫失敗測試**

新增 DOM 檢查，確認 cart line 不會出現空 accessible name 的移除按鈕，sent lock hint 可見，長菜名不造成水平 overflow。

```js
const overflowAudit = await page.evaluate(() => ({
  bodyOverflowX: document.documentElement.scrollWidth > window.innerWidth,
  cartOverflow: Array.from(document.querySelectorAll('.cart-line')).some((node) => node.scrollWidth > node.clientWidth + 2),
}));
if (overflowAudit.bodyOverflowX || overflowAudit.cartOverflow) {
  throw new Error(`Expected no horizontal overflow, got ${JSON.stringify(overflowAudit)}`);
}
```

- [ ] **步驟 2：執行測試確認失敗**

執行：`node tests/smoke-pos.cjs`

預期：FAIL，若目前沒有 overflow，也至少因 sent lock hint 或 accessible label 缺失而失敗。

- [ ] **步驟 3：最少實作**

調整 `.cart-line`、`.order-menu-grid button`、`.drawer-line`、`.floor-table` 的 `min-width: 0`、line-height、overflow、disabled/locked hint 樣式。避免新增裝飾性頁面。

- [ ] **步驟 4：完整驗證**

執行：

```bash
npm run build
node tests/smoke-pos.cjs
```

預期：兩者 exit 0，且產生更新後 `screenshots/smoke-ipad-pos.png`。
