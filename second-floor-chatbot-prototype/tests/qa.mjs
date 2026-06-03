import { chromium } from 'playwright';
import assert from 'node:assert/strict';

const baseUrl = process.env.QA_BASE_URL ?? 'http://127.0.0.1:5173';

const browser = await chromium.launch({ headless: true });

try {
  const desktop = await browser.newPage({ viewport: { width: 1440, height: 920 } });
  await desktop.goto(baseUrl);
  await desktop.waitForLoadState('networkidle');
  await desktop.screenshot({ path: '/tmp/second-floor-chatbot-desktop.png', fullPage: true });

  await assertVisibleText(desktop, '今天想怎麼吃？');
  await assertVisibleText(desktop, 'Second Floor Assistant');
  await assert.equal(await desktop.title(), 'Second Floor Assistant');
  await assert.equal(await desktop.locator('.phone-label').count(), 0);
  await assert.equal(await desktop.getByText('線上接待員').count(), 0);
  await assert.equal(await desktop.locator('.brand-mark').count(), 0);
  await assert.equal(await desktop.getByText('Second Floor Concierge').count(), 0);
  await assert.equal(await desktop.locator('.quick-replies').count(), 0);
  await assert.equal(await desktop.locator('.conversation-select').count(), 0);
  await assert.equal(await desktop.locator('.context-panel').count(), 0);
  await assert.equal(await desktop.getByText('今日可建議時段').count(), 0);
  await assert.equal(await desktop.getByText('Guardrail', { exact: false }).count(), 0);
  await assert.equal(await desktop.getByText('候位', { exact: false }).count(), 0);
  await assert.equal(await desktop.getByText('GPS').count(), 0);
  await assert.equal(await desktop.getByText('所在城市或附近地標').count(), 0);
  await assert.equal(await desktop.getByText('我在台北').count(), 0);
  await assert.equal(await desktop.getByText('熱門城市', { exact: true }).count(), 0);
  await assert.equal(await desktop.locator('.follow-up-group > strong').count(), 0);
  const composer = desktop.locator('.composer-input');
  await assert.equal(await composer.evaluate((node) => node.tagName), 'TEXTAREA');
  await assert.equal(await desktop.getByRole('button', { name: /送出$/ }).count(), 0);
  await assert.equal(await desktop.getByRole('button', { name: /送出訊息/ }).count(), 1);
  await assert.equal(await desktop.locator('.composer-submit .send-arrow-icon').count(), 1);
  await assert.equal(await composer.inputValue(), '今晚 4 個朋友想吃貳樓，想找可以慢慢聊天的位子。');
  await desktop.getByRole('button', { name: /送出訊息/ }).click();
  await assertVisibleText(desktop, '今晚 4 個朋友想吃貳樓，想找可以慢慢聊天的位子。');
  await assert.equal(await desktop.locator('.message.is-thinking').count(), 1);
  await desktop.locator('.message.is-streaming').first().waitFor({ state: 'visible', timeout: 5000 });
  await assert.ok(await desktop.locator('.message.is-streaming').count() >= 1);
  await assertVisibleText(desktop, '可以。我先用 GPS');
  await assertVisibleText(desktop, '如果沒有開位置權限');
  await assertVisibleText(desktop, '我在台北');
  await assert.equal(await composer.inputValue(), '我在台北');
  await assert.equal(await desktop.locator('.message.is-thinking').count(), 0);
  const initialFollowUpTypography = await desktop.locator('.follow-up-group button').first().evaluate((button) => {
    const arrow = button.querySelector('.follow-up-arrow');
    const prompt = button.querySelector('span:last-child');
    const arrowStyle = window.getComputedStyle(arrow);
    const promptStyle = window.getComputedStyle(prompt);
    const lastButton = document.querySelector('.follow-up-group button:last-child');

    return {
      arrowText: arrow.textContent,
      promptText: prompt.textContent,
      arrowFontSize: arrowStyle.fontSize,
      promptFontSize: promptStyle.fontSize,
      arrowLineHeight: arrowStyle.lineHeight,
      promptLineHeight: promptStyle.lineHeight,
      buttonBorderTopWidth: window.getComputedStyle(button).borderTopWidth,
      buttonBorderBottomWidth: window.getComputedStyle(button).borderBottomWidth,
      lastButtonText: lastButton.textContent,
      lastButtonBorderBottomWidth: window.getComputedStyle(lastButton).borderBottomWidth,
      buttonMinHeight: window.getComputedStyle(button).minHeight,
    };
  });
  assert.deepEqual(initialFollowUpTypography, {
    arrowText: '↳',
    promptText: '我在台北',
    arrowFontSize: '14px',
    promptFontSize: '14px',
    arrowLineHeight: '22.68px',
    promptLineHeight: '22.68px',
    buttonBorderTopWidth: '0px',
    buttonBorderBottomWidth: '1px',
    lastButtonText: '↳我在台中',
    lastButtonBorderBottomWidth: '0px',
    buttonMinHeight: 'auto',
  });
  await assert.equal(await desktop.getByText('微風南山店').count(), 0);
  await assert.equal(await desktop.getByText('敦南店').count(), 0);

  await assert.equal(await desktop.getByRole('button', { name: /情境選單/ }).count(), 1);
  await assert.equal(await desktop.getByRole('button', { name: /新增對話/ }).count(), 1);
  await assert.equal(await desktop.getByRole('button', { name: /更多操作/ }).count(), 1);
  await desktop.getByRole('button', { name: /菜單導航/ }).click();
  await assertVisibleText(desktop, '今天想吃清爽一點');
  await assert.equal(await desktop.locator('.messages').evaluate((node) => node.scrollTop), 0);

  for (const label of ['訂位助理', '聚餐情境推薦', '菜單導航', '新客引導']) {
    await desktop.getByRole('button', { name: new RegExp(label) }).click();
    await assert.equal(await desktop.locator('.messages').evaluate((node) => node.scrollTop), 0);
  }

  await desktop.getByRole('button', { name: /收合左側/ }).click();
  await assert.equal(await desktop.locator('.app-shell.is-left-collapsed').count(), 1);
  await desktop.getByRole('button', { name: /展開左側/ }).click();
  await assert.equal(await desktop.locator('.app-shell.is-left-collapsed').count(), 0);
  await assert.equal(await desktop.getByRole('button', { name: /收合右側/ }).count(), 0);
  await assert.equal(await desktop.locator('.app-shell.is-right-collapsed').count(), 0);
  await assert.equal(await desktop.getByRole('button', { name: /換情境/ }).count(), 0);
  await desktop.getByRole('button', { name: /訂位助理/ }).click();

  await assert.equal(await composer.inputValue(), '今晚 4 個朋友想吃貳樓，想找可以慢慢聊天的位子。');
  await desktop.getByRole('button', { name: /送出訊息/ }).click();
  await assertVisibleText(desktop, '我在台北');
  await desktop.getByRole('button', { name: '我在台北', exact: true }).click();
  await assert.equal(await composer.inputValue(), '我在台北');
  await assert.equal(await desktop.getByText('收到，我先用台北幫你縮小範圍').count(), 0);
  await assert.equal(await desktop.getByText('微風南山店').count(), 0);
  await desktop.getByRole('button', { name: /送出訊息/ }).click();
  await assertVisibleText(desktop, '收到，我先用台北幫你縮小範圍');
  await assert.equal(await desktop.getByText('推薦門店', { exact: true }).count(), 0);
  await assertVisibleText(desktop, '微風南山店');
  await assertVisibleText(desktop, '敦南店');
  await desktop.getByRole('button', { name: '敦南店', exact: true }).click();
  await assert.equal(await composer.inputValue(), '敦南店');
  await assert.equal(await desktop.getByText('門店回傳的可訂時段是 15 分鐘刻度').count(), 0);
  await desktop.getByRole('button', { name: /送出訊息/ }).click();
  await assertVisibleText(desktop, '門店回傳的可訂時段是 15 分鐘刻度');
  await assert.equal(await desktop.locator('.recommendation-card').count(), 0);
  await assert.equal(await desktop.getByText('可訂時段', { exact: true }).count(), 0);
  await assertVisibleText(desktop, '19:45');
  await desktop.getByRole('button', { name: '19:45', exact: true }).click();
  await assert.equal(await composer.inputValue(), '19:45');
  await assert.equal(await desktop.getByText('19:45 是敦南店提供的可訂時段').count(), 0);
  await desktop.getByRole('button', { name: /送出訊息/ }).click();
  await assertVisibleText(desktop, '19:45 是敦南店提供的可訂時段');
  await assert.equal(await desktop.locator('.recommendation-card').count(), 1);
  await assertVisibleText(desktop, '敦南店');
  await assertVisibleText(desktop, '19:45 · 4位');
  await assertVisibleText(desktop, '晚餐聊天');
  await desktop.locator('.follow-up-group button', { hasText: '送出' }).waitFor({ state: 'visible', timeout: 5000 });
  await assert.equal(await desktop.locator('.follow-up-group button', { hasText: '送出' }).count(), 1);
  await assert.equal(await composer.inputValue(), '送出');
  await desktop.getByRole('button', { name: /新增對話/ }).click();
  await assert.equal(await desktop.getByText('收到，我先用台北幫你縮小範圍').count(), 0);
  await assert.equal(await desktop.getByText('門店提供的可訂時段是 15 分鐘刻度').count(), 0);
  await assert.equal(await desktop.getByText('微風南山店').count(), 0);
  await assert.equal(await composer.inputValue(), '今晚 4 個朋友想吃貳樓，想找可以慢慢聊天的位子。');
  await assert.equal(await desktop.getByText('窗邊').count(), 0);
  await assert.equal(await desktop.locator('.messages .avatar').count(), 0);

  const visibleTimes = (await desktop.locator('body').innerText()).match(/\b\d{1,2}:\d{2}\b/g) ?? [];
  for (const time of visibleTimes) {
    assert.equal(Number(time.split(':')[1]) % 15, 0, `${time} should use 15-minute increments`);
  }

  const frameBox = await desktop.locator('.phone-frame').boundingBox();
  assert.ok(frameBox, 'phone frame should be rendered');
  assert.ok(frameBox.width >= 400 && frameBox.width <= 410, `phone frame should be iPhone 17-width, got ${frameBox.width}`);
  assert.ok(frameBox.height >= 860, `phone frame should keep iPhone 17 proportions, got ${frameBox.height}`);
  const dynamicIslandBox = await desktop.locator('.phone-dynamic-island').boundingBox();
  assert.ok(dynamicIslandBox, 'iPhone 17 Dynamic Island should be rendered');
  assert.ok(dynamicIslandBox.width >= 108 && dynamicIslandBox.width <= 120, `Dynamic Island should match iPhone 17 scale, got ${dynamicIslandBox.width}`);
  const headerSafeArea = await desktop.evaluate(() => {
    const island = document.querySelector('.phone-dynamic-island').getBoundingClientRect();
    const title = document.querySelector('.chat-title').getBoundingClientRect();
    return Math.round(title.top - island.bottom);
  });
  assert.ok(headerSafeArea >= 10, `header title should clear Dynamic Island by at least 10px, got ${headerSafeArea}`);
  const framePadding = await desktop.locator('.phone-frame').evaluate((frame) => {
    const style = window.getComputedStyle(frame);
    return {
      paddingTop: style.paddingTop,
      paddingBottom: style.paddingBottom,
    };
  });
  assert.deepEqual(framePadding, {
    paddingTop: '12px',
    paddingBottom: '12px',
  });
  const frameFit = await desktop.evaluate(() => {
    const frame = document.querySelector('.phone-frame').getBoundingClientRect();
    const screen = document.querySelector('.phone-screen').getBoundingClientRect();
    return {
      topDelta: Math.round(screen.top - frame.top),
      bottomDelta: Math.round(frame.bottom - screen.bottom),
    };
  });
  assert.deepEqual(frameFit, {
    topDelta: 12,
    bottomDelta: 12,
  });

  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await mobile.goto(baseUrl);
  await mobile.waitForLoadState('networkidle');
  const mobileFramePadding = await mobile.locator('.phone-frame').evaluate((frame) => {
    const style = window.getComputedStyle(frame);
    return {
      paddingTop: style.paddingTop,
      paddingBottom: style.paddingBottom,
    };
  });
  assert.deepEqual(mobileFramePadding, {
    paddingTop: '10px',
    paddingBottom: '10px',
  });
  await mobile.getByRole('button', { name: /新客引導/ }).click();
  await assertVisibleText(mobile, '第一次吃貳樓');
  await mobile.screenshot({ path: '/tmp/second-floor-chatbot-mobile.png', fullPage: true });
} finally {
  await browser.close();
}

async function assertVisibleText(page, text) {
  const locator = page.getByText(text, { exact: false }).first();
  await locator.waitFor({ state: 'visible', timeout: 5000 });
  assert.equal(await locator.isVisible(), true, `${text} should be visible`);
}
