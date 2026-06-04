import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { scenarios, storeRegions, todayHighlights } from '../src/mockData.js';

test('defines the six core customer scenarios', () => {
  assert.deepEqual(
    scenarios.map((scenario) => scenario.id),
    ['reservation', 'gathering', 'menu', 'firstTime', 'takeout', 'dietary'],
  );

  for (const scenario of scenarios) {
    assert.ok(scenario.title.length > 0);
    assert.ok(Array.isArray(scenario.messages));
    assert.ok(scenario.recommendations.length >= 2);
    assert.ok(scenario.primaryCta.length > 0);
    assert.ok(
      scenario.recommendations.every((item) => item.why.includes('適合')),
      `${scenario.id} recommendations should explain why they fit`,
    );
  }
});

test('keeps the demo grounded in store and time mock data', () => {
  assert.ok(todayHighlights.some((item) => item.store === '信義店'));
  assert.ok(todayHighlights.some((item) => item.store === '南西店'));
  assert.ok(todayHighlights.some((item) => item.store === '台中公益店'));
});

test('does not promise window seats because the current system cannot detect them', () => {
  const serialized = JSON.stringify({ scenarios, todayHighlights });

  assert.equal(serialized.includes('窗邊'), false);
});

test('keeps reservation flow inside supported booking rules', () => {
  const serialized = JSON.stringify({ scenarios, todayHighlights, storeRegions });
  const displayedTimes = serialized.match(/\b\d{1,2}:\d{2}\b/g) ?? [];

  assert.equal(serialized.includes('候位'), false);
  assert.equal(serialized.includes('線上候位'), false);

  for (const time of displayedTimes) {
    const minutes = Number(time.split(':')[1]);
    assert.equal(minutes % 15, 0, `${time} should use 15-minute booking increments`);
  }
});

test('defines store regions for reservation recommendations', () => {
  assert.deepEqual(
    storeRegions.map((region) => region.region),
    ['北區', '中區', '南區'],
  );

  assert.ok(storeRegions.find((region) => region.region === '北區').stores.includes('敦南店'));
  assert.ok(storeRegions.find((region) => region.region === '中區').stores.includes('公益店'));
  assert.ok(storeRegions.find((region) => region.region === '南區').stores.includes('高雄夢時代店'));
});

test('reservation scenario asks for location before recommending stores and exposes follow-ups', () => {
  const reservation = scenarios.find((scenario) => scenario.id === 'reservation');
  const reservationText = JSON.stringify(reservation);

  assert.match(reservationText, /GPS/);
  assert.match(reservationText, /城市/);
  assert.match(reservationText, /地標|位置/);
  assert.deepEqual(
    reservation.steps.map((step) => step.followUps[0].label),
    ['熱門城市', '推薦門店', '可訂時段', '確認訂位'],
  );
  assert.ok(reservation.steps[0].followUps[0].options.includes('我在台北'));
  assert.ok(reservation.steps[1].followUps[0].options.includes('敦南店'));
  assert.ok(reservation.steps[2].followUps[0].options.includes('19:45'));
  assert.deepEqual(reservation.steps[3].followUps[0].options, ['送出']);
});

test('reservation scenario does not preload the guest location answer before submit', () => {
  const reservation = scenarios.find((scenario) => scenario.id === 'reservation');

  assert.deepEqual(
    reservation.messages.map((message) => message.from),
    [],
  );
  assert.equal(reservation.primaryCta, '今晚 4 個朋友想吃貳樓，想找可以慢慢聊天的位子。');
  assert.deepEqual(
    reservation.introMessages.map((message) => message.from),
    ['bot', 'bot'],
  );
  assert.match(reservation.introMessages.at(-1).text, /告訴我所在城市或附近地標/);
  assert.doesNotMatch(JSON.stringify(reservation.messages), /我在台北市信義區/);
  assert.doesNotMatch(JSON.stringify(reservation.messages), /先看離你近的/);
  assert.match(reservation.steps[0].response, /用台北幫你縮小範圍/);
  assert.match(reservation.steps[1].response, /門店回傳的可訂時段/);
  assert.match(reservation.steps[1].response, /15 分鐘刻度/);
  assert.doesNotMatch(reservation.steps[2].response, /門店提供的可訂時段/);
  assert.doesNotMatch(reservation.steps[2].response, /用 15 分鐘為單位找/);
});

test('reservation scenario waits for a selected time before showing the booking card', () => {
  const reservation = scenarios.find((scenario) => scenario.id === 'reservation');
  const [, storeStep, timeStep, confirmStep] = reservation.steps;

  assert.equal(storeStep.id, 'store');
  assert.equal(storeStep.recommendations?.length ?? 0, 0);
  assert.match(storeStep.response, /19:45、20:00 和 20:15/);

  assert.equal(timeStep.id, 'time');
  assert.deepEqual(timeStep.followUps[0].options, ['19:45', '20:00', '20:15']);
  assert.deepEqual(
    timeStep.recommendations.map((recommendation) => ({
      type: recommendation.type,
      store: recommendation.store,
      time: recommendation.time,
      party: recommendation.party,
    })),
    [
      {
        type: 'store-preview',
        store: '敦南店',
        time: '19:45',
        party: '4 位',
      },
    ],
  );

  assert.equal(confirmStep.id, 'confirm');
  assert.deepEqual(confirmStep.followUps[0].options, ['送出']);
});

test('all scenarios define staged follow-up flows instead of preloading conclusions', () => {
  for (const scenario of scenarios) {
    assert.ok(Array.isArray(scenario.steps), `${scenario.id} should define staged steps`);
    assert.ok(scenario.steps.length >= 2, `${scenario.id} should have at least two steps`);

    for (const step of scenario.steps) {
      assert.ok(step.response.length > 0, `${scenario.id}:${step.id} should have a response`);
      assert.ok(Array.isArray(step.followUps), `${scenario.id}:${step.id} should define a followUps array`);
      // Terminal / card-action-driven steps may legitimately expose no follow-ups,
      // but any group that IS present must offer at least one option.
      assert.ok(step.followUps.every((group) => group.options.length > 0));
    }

    // Every scenario must still expose at least one follow-up group somewhere,
    // so the guest is never dead-ended without a scripted way to advance.
    assert.ok(
      scenario.steps.some((step) => step.followUps.length > 0),
      `${scenario.id} should expose follow-ups on at least one step`,
    );
  }
});

test('renders the first-screen chatbot prompt and scenario controls', async () => {
  const app = await readFile(new URL('../src/App.jsx', import.meta.url), 'utf8');
  const styles = await readFile(new URL('../src/styles.css', import.meta.url), 'utf8');

  assert.match(app, /scenario-header/);
  assert.doesNotMatch(app, />\s*換情境\s*</);
  assert.match(app, /重置對話/);
  assert.match(app, /resetScenario/);
  assert.match(app, /selectScenario\(scenario\.id\)/);
  assert.doesNotMatch(app, /conversation-select/);
  assert.doesNotMatch(app, /handleConversationSelect/);
  assert.match(app, /frame-action/);
  assert.match(app, /side-menu-icon/);
  assert.match(app, /new-chat-icon/);
  assert.match(app, /more-actions-icon/);
  assert.match(app, /messagesRef/);
  assert.match(app, /scrollMessagesToEnd/);
  assert.match(app, /scrollTop = messagesRef\.current\.scrollHeight/);
  assert.doesNotMatch(app, /quick-replies/);
  assert.doesNotMatch(app, /<h2>{activeScenario\.title}<\/h2>/);
  assert.doesNotMatch(app, /<p>{activeScenario\.prompt}<\/p>/);
  assert.doesNotMatch(app, /Second Floor Concierge/);
  assert.match(app, /Second Floor Assistant/);
  assert.match(app, /phone-frame/);
  assert.doesNotMatch(app, /phone-label/);
  assert.match(styles, /--phone-width:\s*402px/);
  assert.match(styles, /--phone-height:\s*874px/);
  assert.match(app, /phone-dynamic-island/);
  assert.doesNotMatch(app, /phone-speaker/);
  assert.match(styles, /\.phone-frame\s*\{[^}]*padding:\s*12px;/s);
  assert.match(styles, /@media \(max-width: 520px\)[\s\S]*\.phone-frame\s*\{[^}]*padding:\s*10px;/s);
  assert.match(styles, /\.phone-dynamic-island\s*\{[^}]*position:\s*absolute;/s);
  assert.match(styles, /\.phone-screen\s*\{[^}]*height:\s*100%;/s);
  assert.doesNotMatch(styles, /\.phone-screen\s*\{[^}]*height:\s*calc\(100% - 14px\);/s);
  assert.doesNotMatch(styles, /\.phone-label/);
  assert.match(app, /toggle-left/);
  assert.doesNotMatch(app, /toggle-right/);
  assert.doesNotMatch(app, /context-panel/);
  assert.doesNotMatch(app, /todayHighlights/);
  assert.doesNotMatch(app, /Guardrail/);
  assert.doesNotMatch(styles, /\.context-panel/);
  assert.doesNotMatch(styles, /\.today-card/);
  assert.doesNotMatch(styles, /\.guardrail-card/);
  assert.doesNotMatch(app, /recommendation-panel/);
  assert.doesNotMatch(app, /<em>{item\.why}<\/em>/);
  assert.match(app, /chat-composer/);
  assert.match(app, /<textarea/);
  assert.match(app, /rows=\{2\}/);
  assert.match(app, /composer-submit/);
  assert.match(app, /aria-label="送出訊息"/);
  assert.match(app, /send-arrow-icon/);
  assert.doesNotMatch(app, /<input/);
  assert.doesNotMatch(app, />\s*送出\s*<\/button>/);
  assert.match(app, /stepIndex/);
  assert.match(app, /interactions/);
  assert.match(app, /streamBotMessages/);
  assert.match(app, /is-thinking/);
  assert.match(app, /is-streaming/);
  assert.match(app, /advanceConversation/);
  assert.match(app, /follow-up-groups/);
  assert.match(app, /advanceConversation\(getOptionValue\(option\)\)/);
  assert.doesNotMatch(app, /<strong>\{group\.label\}<\/strong>/);
  assert.doesNotMatch(app, /onClick=\{\(\) => advanceConversation\(option\)\}/);
  assert.doesNotMatch(app, /getOptionDescription/);
  assert.doesNotMatch(app, /<small>{getOptionDescription\(option\)}<\/small>/);
  assert.match(styles, /\.follow-up-arrow/);
  assert.doesNotMatch(styles, /\.follow-up-group strong/);
  assert.match(styles, /\.follow-up-arrow\s*\{[^}]*font-size:\s*14px;[^}]*font-weight:\s*850;[^}]*line-height:\s*1\.62;/s);
  assert.match(styles, /\.follow-up-group button span:last-child\s*\{[^}]*font-size:\s*14px;[^}]*font-weight:\s*850;[^}]*line-height:\s*1\.62;/s);
  assert.match(styles, /button, input, textarea \{ font: inherit; \}/);
  assert.match(styles, /\.composer-input\s*\{[^}]*resize:\s*none;/s);
  assert.match(styles, /\.composer-submit\s*\{[^}]*width:\s*36px;[^}]*height:\s*36px;[^}]*aspect-ratio:\s*1;/s);
  assert.doesNotMatch(styles, /\.follow-up-group button\s*\{[^}]*border-bottom:/s);
  assert.match(styles, /\.follow-up-group button:not\(:last-child\)\s*\{[^}]*border-bottom: 1px solid/s);
  assert.doesNotMatch(styles, /\.follow-up-group button:last-child\s*\{[^}]*border-bottom:/s);
  assert.doesNotMatch(styles, /\.follow-up-group button:first-child/);
  assert.doesNotMatch(styles, /\.follow-up-group button\s*\{[^}]*min-height:/s);
  assert.doesNotMatch(styles, /\.follow-up-group button small/);
});

test('reservation time step booking card exposes send and decline actions', () => {
  const reservation = scenarios.find((scenario) => scenario.id === 'reservation');
  const timeStep = reservation.steps.find((step) => step.id === 'time');
  const bookingCard = timeStep.recommendations[0];

  assert.ok(Array.isArray(bookingCard.actions), 'booking card should have an actions array');
  assert.ok(bookingCard.actions.includes('送出'), 'card actions should include 送出');
  assert.ok(bookingCard.actions.includes('取消'), 'card actions should include 取消');
  assert.ok(bookingCard.actions.length >= 2, 'card should have at least two actions');
});

test('takeout scenario uses real menu names and stages spice before confirmation', () => {
  const takeout = scenarios.find((scenario) => scenario.id === 'takeout');

  assert.ok(takeout, 'takeout scenario should exist');
  assert.equal(takeout.steps.length, 3);

  const [countStep, spiceStep, confirmStep] = takeout.steps;

  assert.equal(countStep.id, 'count');
  assert.ok(countStep.response.includes('飯類'));

  assert.equal(spiceStep.id, 'spice');
  const spiceText = JSON.stringify(spiceStep);
  assert.match(spiceText, /焗厚切豬排奶油飯/);
  assert.match(spiceText, /香爆椒麻唐揚雞麵/);
  assert.match(spiceText, /\$460/);
  assert.match(spiceText, /\$430/);
  assert.match(spiceText, /舊金山蒜香薯條/);
  assert.ok(spiceStep.recommendations.length >= 2, 'spice step should show at least two options');

  assert.equal(confirmStep.id, 'confirm');
  assert.ok(
    confirmStep.followUps[0].options.includes('加薯條'),
    'confirm step should offer the side-dish upsell',
  );
});

test('dietary scenario filters pork-free and no-spice options using real menu names', () => {
  const dietary = scenarios.find((scenario) => scenario.id === 'dietary');

  assert.ok(dietary, 'dietary scenario should exist');
  assert.equal(dietary.steps.length, 3);

  const [restrictionStep, spiceStep, confirmStep] = dietary.steps;

  assert.equal(restrictionStep.id, 'restriction');
  assert.ok(
    restrictionStep.followUps[0].options.includes('不吃豬肉'),
    'restriction step should offer pork-free option',
  );
  assert.ok(
    restrictionStep.followUps[0].options.includes('吃素（蛋奶素）'),
    'restriction step should offer vegetarian option',
  );

  assert.equal(spiceStep.id, 'spice');
  assert.ok(
    spiceStep.followUps[0].options.includes('不要辣（完全去辣）'),
    'spice step should offer no-spice option',
  );
  assert.ok(
    spiceStep.followUps[0].options.includes('想要夠辣'),
    'spice step should offer extra-spicy option',
  );

  assert.equal(confirmStep.id, 'confirm');
  const confirmText = JSON.stringify(confirmStep);
  assert.match(confirmText, /曙光汁鮮蝦雞肉麵/);
  assert.match(confirmText, /舒肥雞藜麥花椰飯/);
  assert.match(confirmText, /巴薩米克蕈菇麵/);
  assert.ok(confirmStep.recommendations.length >= 1, 'confirm step should feature at least one pork-free no-spice dish');
  assert.ok(
    confirmStep.followUps[0].options.length >= 2,
    'confirm step should offer alternative pork-free no-spice choices',
  );

  const dietaryText = JSON.stringify(dietary);
  assert.doesNotMatch(dietaryText, /豬排/, 'dietary scenario should not recommend pork-heavy dishes as primary');
});

test('menu scenario references real menu items from sf-menu data', () => {
  const menu = scenarios.find((scenario) => scenario.id === 'menu');
  const menuText = JSON.stringify(menu);

  assert.match(menuText, /貳樓金牌鹽水雞沙拉/, 'menu scenario should use real dish names');
  assert.match(menuText, /舒肥雞藜麥花椰飯/, 'menu scenario should use real dish names');
  assert.match(menuText, /松露薯條/, 'menu scenario should reference real sharing plates');
  assert.match(menuText, /\$370|\$400|\$260/, 'menu scenario should show real prices');
  assert.doesNotMatch(menuText, /清爽早午餐組合/, 'menu scenario should not use placeholder dish names');
  assert.doesNotMatch(menuText, /三人分享節奏/, 'menu scenario should not use placeholder dish names');
});

test('removes decorative brand marks and assistant avatars from chat', async () => {
  const app = await readFile(new URL('../src/App.jsx', import.meta.url), 'utf8');
  const styles = await readFile(new URL('../src/styles.css', import.meta.url), 'utf8');
  const html = await readFile(new URL('../index.html', import.meta.url), 'utf8');

  assert.doesNotMatch(app, /brand-mark/);
  assert.doesNotMatch(app, /<span>貳<\/span>/);
  assert.doesNotMatch(app, /線上接待員/);
  assert.doesNotMatch(app, /className="avatar"/);
  assert.doesNotMatch(app, /message\.from === 'bot' &&/);
  assert.doesNotMatch(styles, /\.brand-mark/);
  assert.doesNotMatch(styles, /\.conversation-select/);
  assert.doesNotMatch(styles, /\.avatar/);
  assert.match(html, /<title>Second Floor Assistant<\/title>/);
});
