const path = require('path');
const { chromium } = require('playwright');

async function mustBeVisible(locator, label) {
  await locator.waitFor({ state: 'visible', timeout: 8000 }).catch((error) => {
    throw new Error(`Expected visible: ${label}\n${error.message}`);
  });
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });

  await page.goto('http://127.0.0.1:5173/index.html', { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('networkidle', { timeout: 8000 }).catch(() => {});

  const viewportFit = await page.evaluate(() => {
    const frame = document.querySelector('.ipad-frame').getBoundingClientRect();
    return {
      frameWidth: Math.round(frame.width),
      frameHeight: Math.round(frame.height),
      hasOuterScroll: document.documentElement.scrollHeight > window.innerHeight ||
        document.documentElement.scrollWidth > window.innerWidth ||
        document.body.scrollHeight > window.innerHeight ||
        document.body.scrollWidth > window.innerWidth,
    };
  });
  if (viewportFit.frameWidth !== 1194 || viewportFit.frameHeight !== 834 || !viewportFit.hasOuterScroll) {
    throw new Error(`Expected native iPad frame with outer scroll on 1280x800 viewport, got ${JSON.stringify(viewportFit)}.`);
  }

  await page.locator('.device-options button').filter({ hasText: 'iPad Pro 12.9"' }).click();
  const pro129 = await frameMetrics(page);
  if (pro129.frameWidth !== 1366 || pro129.frameHeight !== 1024) {
    throw new Error(`Expected iPad Pro 12.9 frame at 1366x1024, got ${JSON.stringify(pro129)}.`);
  }

  await page.locator('.device-options button').filter({ hasText: 'iPad mini' }).click();
  const mini = await frameMetrics(page);
  if (mini.frameWidth !== 1133 || mini.frameHeight !== 744) {
    throw new Error(`Expected iPad mini frame at 1133x744, got ${JSON.stringify(mini)}.`);
  }

  await page.locator('.device-options button').filter({ hasText: 'Fit to screen' }).click();
  await page.locator('.device-shell.is-fit').waitFor({ state: 'visible', timeout: 2000 });
  const fit = await frameMetrics(page);
  if (fit.frameWidth >= 1194 || fit.frameHeight >= 834 || fit.hasOuterScroll) {
    throw new Error(`Expected fit mode to scale iPad into 1280x800 viewport without outer scroll, got ${JSON.stringify(fit)}.`);
  }

  await page.locator('.device-options button').filter({ hasText: 'iPad Pro 11"' }).click();

  const title = await page.title();
  if (title !== '餐廳 iPad POS') {
    throw new Error(`Expected document title to be "餐廳 iPad POS", got "${title}".`);
  }
  await mustBeVisible(page.getByText('Wi-Fi　100%'), 'status Wi-Fi label');
  if (await page.getByText(/廚房 Wi-Fi|BLUE OX/).count()) {
    throw new Error('Expected kitchen Wi-Fi wording and BLUE OX title to be removed.');
  }
  if (await page.locator('.brand-lockup').count()) {
    throw new Error('Expected brand lockup to be removed from the side navigation.');
  }

  await mustBeVisible(page.getByText('全餐廳狀況'), 'overview title');
  await mustBeVisible(page.getByText('01 桌'), 'selected table operation panel');

  const panelBefore = await page.evaluate(() => Math.round(document.querySelector('.operation-panel').getBoundingClientRect().width));
  const handleBox = await page.locator('.panel-resize-handle').boundingBox();
  await page.mouse.move(handleBox.x + handleBox.width / 2, handleBox.y + 120);
  await page.mouse.down();
  await page.mouse.move(handleBox.x + handleBox.width / 2 + 120, handleBox.y + 120);
  await page.mouse.up();
  const panelAfter = await page.evaluate(() => {
    const panel = document.querySelector('.operation-panel').getBoundingClientRect();
    const board = document.querySelector('.floor-board').getBoundingClientRect();
    return {
      panelWidth: Math.round(panel.width),
      boardWidth: Math.round(board.width),
    };
  });
  if (panelAfter.panelWidth >= panelBefore || panelAfter.panelWidth > 300 || panelAfter.boardWidth < 780) {
    throw new Error(`Expected resizable sheet to shrink and reveal more board, got before=${panelBefore}, after=${JSON.stringify(panelAfter)}.`);
  }

  await page.locator('.floor-table').filter({ hasText: /^01/ }).click();
  await page.locator('.operation-panel').waitFor({ state: 'hidden', timeout: 2000 });
  await page.locator('.floor-table').filter({ hasText: /^03/ }).click();
  await mustBeVisible(page.getByText('03 桌'), 'operation panel reopened for selected table');
  await page.locator('.floor-table').filter({ hasText: /^03/ }).click();
  await page.locator('.operation-panel').waitFor({ state: 'hidden', timeout: 2000 });
  await page.locator('.floor-table').filter({ hasText: /^04/ }).click();
  await mustBeVisible(page.getByText('04 桌'), 'operation panel switched to newly selected table');

  await page.locator('.side-nav button').filter({ hasText: '出菜追蹤' }).click();
  await mustBeVisible(page.getByText('出菜追蹤看板'), 'kitchen page title');

  await page.locator('.side-nav button').filter({ hasText: '訪桌紀錄' }).click();
  await mustBeVisible(page.getByRole('heading', { name: '訪桌紀錄' }), 'visit page title');

  await page.locator('.side-nav button').filter({ hasText: '結帳' }).click();
  await mustBeVisible(page.getByText('結帳佇列'), 'checkout page title');

  await page.locator('.side-nav button').filter({ hasText: '我的分區' }).click();
  await mustBeVisible(page.getByRole('heading', { name: '我的分區' }), 'my zone page title');

  await page.getByRole('button', { name: /貳樓經典早午餐/ }).click();
  await mustBeVisible(page.getByText('貳樓經典早午餐').first(), 'added menu item');

  await page.getByRole('button', { name: '送單到廚房' }).click();
  await mustBeVisible(page.getByRole('button', { name: '全部上餐' }), 'kitchen workflow');

  await page.getByRole('button', { name: '全部上餐' }).click();
  await mustBeVisible(page.getByText('應收金額'), 'checkout amount');

  await page.getByRole('button', { name: '信用卡' }).click();
  await page.getByRole('button', { name: '完成結帳並清桌' }).click();
  await mustBeVisible(page.getByText('尚無品項'), 'cleared ticket');

  await page.screenshot({ path: path.join('screenshots', 'smoke-ipad-pos.png'), fullPage: true });
  await browser.close();

  if (errors.length) {
    throw new Error(`Browser errors:\n${errors.join('\n')}`);
  }
}

async function frameMetrics(page) {
  return page.evaluate(() => {
    const frame = document.querySelector('.ipad-frame').getBoundingClientRect();
    return {
      frameWidth: Math.round(frame.width),
      frameHeight: Math.round(frame.height),
      hasOuterScroll: document.documentElement.scrollHeight > window.innerHeight ||
        document.documentElement.scrollWidth > window.innerWidth ||
        document.body.scrollHeight > window.innerHeight ||
        document.body.scrollWidth > window.innerWidth,
    };
  });
}

main().catch(async (error) => {
  console.error(error);
  process.exit(1);
});
