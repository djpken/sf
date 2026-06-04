import { chromium } from 'playwright';
import assert from 'node:assert/strict';

const baseUrl = process.env.QA_BASE_URL ?? 'http://127.0.0.1:5173';

const browser = await chromium.launch({ headless: true });

try {
  const desktop = await browser.newPage({ viewport: { width: 1440, height: 920 } });
  // Force dish-card photos to fail so the fallback path is exercised
  // deterministically (the vite dev server otherwise 200s unknown paths).
  await desktop.route('**/images/**', (route) => route.abort());
  await desktop.goto(baseUrl);
  await desktop.waitForLoadState('networkidle');

  // ── Intro screen ───────────────────────────────────────────────
  // The app opens on a POC intro modal; everything else is behind it.
  await assertVisibleText(desktop, '貳樓助理');
  await assertVisibleText(desktop, '展示 AI 應對 6 種場景');
  await desktop.getByRole('button', { name: '開始了解' }).click();
  await assert.equal(await desktop.locator('.intro-screen').count(), 0);
  await desktop.screenshot({ path: '/tmp/second-floor-chatbot-desktop.png', fullPage: true });

  // ── Shell + legacy guardrails ──────────────────────────────────
  await assertVisibleText(desktop, 'Second Floor Assistant');
  await assert.equal(await desktop.title(), 'Second Floor Assistant');
  await assert.equal(await desktop.locator('.phone-label').count(), 0);
  await assert.equal(await desktop.getByText('線上接待員').count(), 0);
  await assert.equal(await desktop.locator('.brand-mark').count(), 0);
  await assert.equal(await desktop.getByText('Second Floor Concierge').count(), 0);
  await assert.equal(await desktop.locator('.quick-replies').count(), 0);
  await assert.equal(await desktop.locator('.conversation-select').count(), 0);
  await assert.equal(await desktop.locator('.context-panel').count(), 0);
  await assert.equal(await desktop.getByText('Guardrail', { exact: false }).count(), 0);
  await assert.equal(await desktop.getByText('候位', { exact: false }).count(), 0);

  // ── Composer is a textarea pre-filled with the reservation prompt ─
  const composer = desktop.locator('.composer-input');
  await assert.equal(await composer.evaluate((node) => node.tagName), 'TEXTAREA');
  await assert.equal(await desktop.getByRole('button', { name: /送出$/ }).count(), 0);
  await assert.equal(await desktop.getByRole('button', { name: /送出訊息/ }).count(), 1);
  await assert.equal(await desktop.locator('.composer-submit .send-arrow-icon').count(), 1);
  await assert.equal(
    await composer.inputValue(),
    '今晚 4 個朋友想吃貳樓，想找可以慢慢聊天的位子。',
  );

  // ── Reservation flow: intro → city → store → time → booking card ─
  await desktop.getByRole('button', { name: /送出訊息/ }).click();
  await assertVisibleText(desktop, '今晚 4 個朋友想吃貳樓');
  await desktop.locator('.message.is-streaming').first().waitFor({ state: 'visible', timeout: 5000 });
  await assertVisibleText(desktop, '可以。我先用 GPS');
  await assertVisibleText(desktop, '如果沒有開位置權限');
  await waitForFollowUp(desktop, '我在台北');
  await assert.equal(await composer.inputValue(), '我在台北');

  await clickFollowUp(desktop, '我在台北');
  await assertVisibleText(desktop, '收到，我先用台北幫你縮小範圍');
  await waitForFollowUp(desktop, '敦南店');
  await assertVisibleText(desktop, '微風南山店');

  await clickFollowUp(desktop, '敦南店');
  await assertVisibleText(desktop, '門店回傳的可訂時段是 15 分鐘刻度');
  await waitForFollowUp(desktop, '19:45');

  await clickFollowUp(desktop, '19:45');
  await assertVisibleText(desktop, '19:45 是敦南店提供的可訂時段');

  // Booking summary is a store-preview card, not the legacy label/meta card.
  const bookingCard = desktop.locator('.recommendation-card.is-store-preview').last();
  await bookingCard.waitFor({ state: 'visible', timeout: 5000 });
  await assertVisibleText(desktop, '敦南店');
  await assertVisibleText(desktop, '4 位');
  await assertVisibleText(desktop, '晚餐聊天');
  const cardSubmit = bookingCard.locator('.recommendation-action', { hasText: '送出' });
  const cardCancel = bookingCard.locator('.recommendation-action', { hasText: '取消' });
  await assert.equal(await cardSubmit.count(), 1, 'booking card should expose a 送出 action');
  await assert.equal(await cardCancel.count(), 1, 'booking card should expose a 取消 action');

  // Submit the booking from the card → pending → confirmation.
  await cardSubmit.click();
  await assertVisibleText(desktop, '正在訂位中');
  await assertVisibleText(desktop, '訂位完成');

  // ── New chat resets the active scenario ────────────────────────
  await desktop.getByRole('button', { name: /新增對話/ }).click();
  await assert.equal(await desktop.getByText('收到，我先用台北幫你縮小範圍').count(), 0);
  await assert.equal(
    await composer.inputValue(),
    '今晚 4 個朋友想吃貳樓，想找可以慢慢聊天的位子。',
  );

  // ── Expand the concierge panel so scenario chips are reachable ──
  // The left panel starts collapsed, which hides the scenario list.
  await desktop.getByRole('button', { name: /展開左側/ }).click();
  await assert.equal(await desktop.locator('.app-shell.is-left-collapsed').count(), 0);

  // ── Scenario switching resets scroll to the top ────────────────
  for (const label of ['菜單導航', '聚餐情境推薦', '新客引導', '外帶打包', '特殊飲食需求', '訂位助理']) {
    await desktop.getByRole('button', { name: new RegExp(label) }).first().click();
    await assert.equal(await desktop.locator('.messages').evaluate((node) => node.scrollTop), 0);
  }

  // ── Left panel collapse / expand ───────────────────────────────
  await desktop.getByRole('button', { name: /收合左側/ }).click();
  await assert.equal(await desktop.locator('.app-shell.is-left-collapsed').count(), 1);
  await desktop.getByRole('button', { name: /展開左側/ }).click();
  await assert.equal(await desktop.locator('.app-shell.is-left-collapsed').count(), 0);
  await assert.equal(await desktop.getByRole('button', { name: /換情境/ }).count(), 0);

  // ── Dish-card image fallback (defensive) ───────────────────────
  // Photos normally load from publicDir (../sf-menu/images). The route
  // above aborts them so we exercise the onError path: a failed photo
  // must degrade to the 2F monogram, never a broken-image icon.
  await desktop.getByRole('button', { name: /菜單導航/ }).first().click();
  await assert.equal(await composer.inputValue(), '今天想吃清爽一點，但不要吃完很空。');
  await desktop.getByRole('button', { name: /送出訊息/ }).click();
  await assertVisibleText(desktop, '清爽但有飽足感');
  await clickFollowUp(desktop, '清爽但有飽足感');
  // party step hides its hint-only follow-up; wait for streaming to settle
  // (composer pre-fills the next draft) before advancing via the composer.
  await desktop.waitForFunction(
    () => document.querySelector('.composer-input')?.value === '3 個人',
    null,
    { timeout: 8000 },
  );
  await desktop.getByRole('button', { name: /送出訊息/ }).click();
  const fallback = desktop.locator('.dc-photo-fallback').last();
  await fallback.waitFor({ state: 'visible', timeout: 5000 });
  await assert.ok(
    (await desktop.locator('.dc-photo-fallback').count()) >= 1,
    'dish cards with missing images should render the fallback placeholder',
  );
  await assertVisibleText(desktop, '2F');
  // No <img.dc-photo> should be left showing a broken (zero-width) image.
  const brokenImages = await desktop.locator('img.dc-photo').evaluateAll(
    (nodes) => nodes.filter((node) => node.complete && node.naturalWidth === 0).length,
  );
  await assert.equal(brokenImages, 0, 'no broken dish-card <img> should remain in the DOM');

  // ── Booking guardrails across the whole document ───────────────
  await assert.equal(await desktop.getByText('窗邊').count(), 0);
  const visibleTimes = (await desktop.locator('body').innerText()).match(/\b\d{1,2}:\d{2}\b/g) ?? [];
  for (const time of visibleTimes) {
    assert.equal(Number(time.split(':')[1]) % 15, 0, `${time} should use 15-minute increments`);
  }

  // ── Phone frame chrome ─────────────────────────────────────────
  const frameBox = await desktop.locator('.phone-frame').boundingBox();
  assert.ok(frameBox, 'phone frame should be rendered');
  assert.ok(
    frameBox.width >= 380 && frameBox.width <= 440,
    `phone frame should keep a phone-width footprint, got ${frameBox.width}`,
  );
  assert.ok(frameBox.height >= 820, `phone frame should keep phone proportions, got ${frameBox.height}`);
  const islandBox = await desktop.locator('.phone-dynamic-island').boundingBox();
  assert.ok(islandBox, 'Dynamic Island should be rendered');

  // ── Mobile viewport smoke test ─────────────────────────────────
  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await mobile.goto(baseUrl);
  await mobile.waitForLoadState('networkidle');
  await mobile.getByRole('button', { name: '開始了解' }).click();
  await assert.equal(await mobile.locator('.intro-screen').count(), 0);
  await assert.equal(await mobile.locator('.composer-input').evaluate((node) => node.tagName), 'TEXTAREA');
  await assert.ok(await mobile.locator('.phone-frame').boundingBox(), 'mobile phone frame should render');
  await mobile.screenshot({ path: '/tmp/second-floor-chatbot-mobile.png', fullPage: true });

  console.log('QA passed: intro, reservation flow, scenario switching, dish-card fallback, guardrails, mobile.');
} finally {
  await browser.close();
}

async function assertVisibleText(page, text) {
  const locator = page.getByText(text, { exact: false }).first();
  await locator.waitFor({ state: 'visible', timeout: 8000 });
  assert.equal(await locator.isVisible(), true, `${text} should be visible`);
}

async function waitForFollowUp(page, label) {
  await page
    .locator('.follow-up-group button', { hasText: label })
    .first()
    .waitFor({ state: 'visible', timeout: 8000 });
}

async function clickFollowUp(page, label) {
  await waitForFollowUp(page, label);
  await page.locator('.follow-up-group button', { hasText: label }).first().click();
}
