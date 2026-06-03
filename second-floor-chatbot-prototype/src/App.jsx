import { useEffect, useMemo, useRef, useState } from 'react';
import { scenarios } from './mockData.js';

const MOCK_CONVERSATIONS = [
  { id: 'c1', title: '晚上用餐哪裡方便', isActive: true },
  { id: 'c2', title: '二樓還有位子嗎', hasUnread: true },
  { id: 'c3', title: '推薦適合家庭聚餐的餐點' },
  { id: 'c4', title: '週末下午茶有什麼選擇' },
  { id: 'c5', title: '今天的特餐是什麼' },
  { id: 'c6', title: '訂位需要提前多久' },
  { id: 'c7', title: '適合商務餐敘的安排' },
  { id: 'c8', title: '素食餐點有哪些選擇' },
  { id: 'c9', title: '生日聚餐想訂包廂' },
  { id: 'c10', title: '外帶菜單怎麼點' },
];

const THINKING_DELAY_MS = 360;
const STREAM_CHUNK_SIZE = 2;
const STREAM_DELAY_MS = 22;

function getOptionValue(option) {
  return typeof option === 'string' ? option : option.value;
}

function getFirstFollowUpValue(step) {
  const followUp = step?.followUps?.[0];
  if (!followUp?.options?.length) return '';
  if (followUp.default != null) return getOptionValue(followUp.default);
  return getOptionValue(followUp.options[0]);
}

function App() {
  const [showIntro, setShowIntro] = useState(true);
  const [showEndPage, setShowEndPage] = useState(false);
  const [activeId, setActiveId] = useState(scenarios[0].id);
  const [leftCollapsed, setLeftCollapsed] = useState(true);
  const [mobileSidebarOpen, setMobileSidebarOpen] = useState(false);
  const [stepIndex, setStepIndex] = useState(0);
  const [interactions, setInteractions] = useState([]);
  const [introComplete, setIntroComplete] = useState(!scenarios[0].introMessages?.length);
  const [isBotBusy, setIsBotBusy] = useState(false);
  const [pendingMessage, setPendingMessage] = useState(null);
  const messagesRef = useRef(null);
  const composerInputRef = useRef(null);
  const timersRef = useRef([]);
  const streamTokenRef = useRef(0);
  const scenarioStateCache = useRef(new Map());
  const scrollIntentRef = useRef('start');
  const activeScenario = useMemo(
    () => scenarios.find((scenario) => scenario.id === activeId) ?? scenarios[0],
    [activeId],
  );
  const activeStep = activeScenario.steps?.[stepIndex];
  const [draft, setDraft] = useState(activeScenario.primaryCta);

  function scrollMessagesToStart() {
    window.requestAnimationFrame(() => {
      if (messagesRef.current) {
        messagesRef.current.scrollTop = 0;
      }
    });
  }

  function scrollMessagesToEnd() {
    window.requestAnimationFrame(() => {
      if (messagesRef.current) {
        messagesRef.current.scrollTop = messagesRef.current.scrollHeight;
      }
    });
  }

  function clearStreamTimers() {
    timersRef.current.forEach((timer) => window.clearTimeout(timer));
    timersRef.current = [];
    streamTokenRef.current += 1;
    setIsBotBusy(false);
    setPendingMessage(null);
  }

  function waitForStream(ms) {
    return new Promise((resolve) => {
      const timer = window.setTimeout(resolve, ms);
      timersRef.current.push(timer);
    });
  }

  async function streamBotMessages(messages, token) {
    setIsBotBusy(true);
    await waitForStream(THINKING_DELAY_MS);
    if (token !== streamTokenRef.current) return;

    for (const message of messages) {
      const fullText = message.text;
      const botItem = {
        id: `${token}-${fullText}`,
        from: 'bot',
        text: '',
        recommendations: message.recommendations ?? [],
        isStreaming: true,
      };

      setInteractions((items) => [...items, botItem]);

      for (let length = STREAM_CHUNK_SIZE; length < fullText.length; length += STREAM_CHUNK_SIZE) {
        await waitForStream(STREAM_DELAY_MS);
        if (token !== streamTokenRef.current) return;
        setInteractions((items) => items.map((item, index) => (
          index === items.length - 1 ? { ...item, text: fullText.slice(0, length) } : item
        )));
      }

      await waitForStream(STREAM_DELAY_MS);
      if (token !== streamTokenRef.current) return;
      setInteractions((items) => items.map((item, index) => (
        index === items.length - 1 ? { ...item, text: fullText, isStreaming: false } : item
      )));
    }

    setIsBotBusy(false);
  }

  function selectScenario(id) {
    if (id === activeId) return;
    const nextScenario = scenarios.find((scenario) => scenario.id === id) ?? scenarios[0];
    clearStreamTimers();

    scenarioStateCache.current.set(activeId, { stepIndex, interactions, introComplete, draft });

    const cached = scenarioStateCache.current.get(id);
    if (cached) {
      setStepIndex(cached.stepIndex);
      setInteractions(cached.interactions);
      setIntroComplete(cached.introComplete);
      setDraft(cached.draft);
      scrollIntentRef.current = 'end';
    } else {
      setStepIndex(0);
      setInteractions([]);
      setIntroComplete(!nextScenario.introMessages?.length);
      setDraft(nextScenario.primaryCta);
      scrollIntentRef.current = 'start';
    }
    setActiveId(nextScenario.id);
    setShowEndPage(false);
  }

  function resetScenario() {
    clearStreamTimers();
    scenarioStateCache.current.delete(activeId);
    setDraft(activeScenario.primaryCta);
    setStepIndex(0);
    setInteractions([]);
    setIntroComplete(!activeScenario.introMessages?.length);
    scrollMessagesToStart();
  }

  async function advanceConversation(value) {
    const trimmedValue = value.trim();
    if (!trimmedValue || isBotBusy) return;

    setDraft('');
    const streamToken = streamTokenRef.current;

    setInteractions((items) => [
      ...items,
      {
        id: `${streamToken}-guest-${items.length}`,
        from: 'guest',
        text: trimmedValue,
      },
    ]);

    if (!introComplete && activeScenario.introMessages?.length) {
      setDraft('');
      scrollMessagesToEnd();
      await streamBotMessages(activeScenario.introMessages, streamToken);
      if (streamToken !== streamTokenRef.current) return;
      setIntroComplete(true);
      setDraft(getFirstFollowUpValue(activeStep) || trimmedValue);
      scrollMessagesToEnd();
      return;
    }

    if (!activeStep) return;
    const nextIndex = stepIndex + 1;
    const nextStep = activeScenario.steps?.[nextIndex];

    if (activeStep.pendingDelay) {
      setIsBotBusy(true);
      setPendingMessage(activeStep.pendingMessage ?? null);
      scrollMessagesToEnd();
      await waitForStream(activeStep.pendingDelay);
      if (streamToken !== streamTokenRef.current) return;
      setPendingMessage(null);
    }

    await streamBotMessages([
      {
        from: 'bot',
        text: activeStep.response,
        recommendations: activeStep.recommendations ?? [],
      },
    ], streamToken);
    if (streamToken !== streamTokenRef.current) return;
    setStepIndex(nextIndex);
    setDraft(nextStep ? (getFirstFollowUpValue(nextStep) || trimmedValue) : '');
    scrollMessagesToEnd();
  }

  function submitDraft(event) {
    event.preventDefault();
    advanceConversation(draft);
  }

  function handleComposerKeyDown(event) {
    if (event.key !== 'Enter' || event.shiftKey || event.nativeEvent.isComposing) return;

    event.preventDefault();
    event.currentTarget.form?.requestSubmit();
  }

  useEffect(() => {
    if (scrollIntentRef.current === 'end') {
      scrollMessagesToEnd();
    } else {
      scrollMessagesToStart();
    }
  }, [activeId]);

  useEffect(() => () => clearStreamTimers(), []);

  const lastBotRecMessage = [...interactions].reverse().find(
    (i) => i.from === 'bot' && i.recommendations?.length > 0,
  );
  const lastCardHasActions = lastBotRecMessage?.recommendations?.some(
    (r) => r.actions?.length > 0,
  ) ?? false;
  const visibleFollowUpGroups = activeStep?.followUps?.filter((g) => !g.hintOnly) ?? [];
  const showFollowUps = introComplete && !isBotBusy && visibleFollowUpGroups.length > 0 && !lastCardHasActions;

  const activeScenarioIndex = scenarios.findIndex((s) => s.id === activeId);
  const nextScenario = scenarios[activeScenarioIndex + 1] ?? null;
  const isLastScenario = activeScenarioIndex === scenarios.length - 1;
  const scenarioDone = introComplete && !isBotBusy && !activeStep;
  const showNextScenarioPrompt = scenarioDone && !isLastScenario;
  const showEndPrompt = scenarioDone && isLastScenario;

  return (
    <>
      {showIntro && (
        <div className="intro-screen" role="dialog" aria-modal="true" aria-label="貳樓助理介紹">
          <div className="intro-card">
            <h1 className="intro-title">貳樓助理</h1>
            <p className="intro-subtitle">展示 AI 應對 6 種場景</p>
            <ul className="intro-features">
              {scenarios.map((scenario) => (
                <li key={scenario.id}>
                  <span className="intro-feature-name">{scenario.title}</span>
                  {scenario.subtitle}
                </li>
              ))}
            </ul>
            <button className="intro-cta" type="button" onClick={() => setShowIntro(false)}>
              開始了解
            </button>
            <span className="intro-meta">Proof of Concept · v0.1 · 6 個場景</span>
          </div>
        </div>
      )}
      <main
        className={[
          'app-shell',
          leftCollapsed ? 'is-left-collapsed' : '',
        ].join(' ')}
      >
      <aside className="side-panel concierge-panel" aria-label="情境選擇">
        <button
          aria-label={leftCollapsed ? '展開左側' : '收合左側'}
          className="panel-toggle toggle-left"
          type="button"
          onClick={() => setLeftCollapsed((value) => !value)}
        >
          {leftCollapsed ? <span className="concierge-icon" aria-hidden="true" /> : '‹'}
        </button>

        <div className="panel-body">
          <section className="scenario-header" aria-label="場景選擇說明">
            <div className="scenario-header-top">
              <span className="poc-badge">POC</span>
              <span className="poc-version">v0.1</span>
            </div>
            <h2 className="scenario-header-title">場景選擇</h2>
            <p className="scenario-header-desc">選擇情境，預覽 AI 助理在不同對話脈絡下的表現。</p>
          </section>

          <nav className="scenario-list" aria-label="情境選擇">
            {scenarios.map((scenario) => (
              <button
                className={scenario.id === activeScenario.id ? 'scenario-chip is-active' : 'scenario-chip'}
                key={scenario.id}
                type="button"
                onClick={() => selectScenario(scenario.id)}
              >
                <span>{scenario.title}</span>
                <small>{scenario.subtitle}</small>
              </button>
            ))}
          </nav>

          <button className="reset-button" type="button" onClick={resetScenario}>
            重置對話
          </button>
        </div>
      </aside>

      <section className="phone-stage" aria-label="手機預覽">
        <div className="phone-frame">
          <div className="phone-dynamic-island" />

          <section className="chat-panel phone-screen" aria-label={`${activeScenario.title}對話`}>
            {mobileSidebarOpen && (
              <div
                className="phone-sidebar-backdrop"
                aria-hidden="true"
                onClick={() => setMobileSidebarOpen(false)}
              />
            )}

            <div className={`phone-sidebar${mobileSidebarOpen ? ' is-open' : ''}`} aria-label="對話列表">
              <div className="psb-top">
                <span className="psb-logo" aria-label="Second Floor">2F</span>
                <button
                  aria-label="關閉側欄"
                  className="psb-layout-toggle"
                  type="button"
                  onClick={() => setMobileSidebarOpen(false)}
                >
                  <span className="psb-layout-icon" aria-hidden="true" />
                </button>
              </div>

              <div className="psb-new-row">
                <button
                  className="psb-new-btn"
                  type="button"
                  onClick={() => { resetScenario(); setMobileSidebarOpen(false); }}
                >
                  <span className="psb-plus" aria-hidden="true">+</span>
                  新建
                </button>
                <span className="psb-shortcut" aria-hidden="true">⌘K</span>
              </div>

              <nav className="psb-nav" aria-label="功能導覽">
                <button className="psb-nav-item" type="button">
                  <span className="psb-icon psb-icon-search" aria-hidden="true" />
                  搜尋對話
                </button>
                <button className="psb-nav-item" type="button">
                  <span className="psb-icon psb-icon-history" aria-hidden="true" />
                  歷史紀錄
                </button>
              </nav>

              <div className="psb-conversations" aria-label="最近對話">
                {MOCK_CONVERSATIONS.map((conv) => (
                  <button
                    key={conv.id}
                    className={`psb-conv-item${conv.isActive ? ' is-active' : ''}`}
                    type="button"
                    onClick={() => setMobileSidebarOpen(false)}
                  >
                    <span className="psb-conv-title">{conv.title}</span>
                    {conv.hasUnread && <span className="psb-unread-dot" aria-label="未讀" />}
                  </button>
                ))}
              </div>
            </div>

            <header className="chat-header">
              <button
                aria-label="情境選單"
                className="frame-action frame-action-left"
                type="button"
                onClick={() => setMobileSidebarOpen((v) => !v)}
              >
                <span className="side-menu-icon" aria-hidden="true" />
              </button>

              <span className="eyebrow chat-title">Second Floor Assistant</span>

              <div className="frame-actions-right" aria-label="對話操作">
                <button aria-label="新增對話" className="frame-action" type="button" onClick={resetScenario}>
                  <span className="new-chat-icon" aria-hidden="true" />
                </button>
                <button
                  aria-label="更多操作"
                  className="frame-action"
                  type="button"
                >
                  <span className="more-actions-icon" aria-hidden="true" />
                </button>
              </div>
            </header>

            <div className="messages" ref={messagesRef}>
              {activeScenario.messages.map((message, index) => (
                <article className={`message is-${message.from}`} key={`${message.from}-${index}`}>
                  <p>{message.text}</p>
                </article>
              ))}

              {interactions.map((item, index) => (
                <article
                  className={[
                    'message',
                    `is-${item.from}`,
                    item.recommendations?.length ? 'is-recommendations' : '',
                    item.isStreaming ? 'is-streaming' : '',
                  ].filter(Boolean).join(' ')}
                  key={item.id ?? `${item.from}-${index}`}
                >
                  {item.recommendations?.length ? (
                    <div className="recommendation-bubble">
                      <p>{item.text}</p>
                      <div className="recommendation-list">
                        {item.recommendations.map((recommendation) => {
                          const hasActions = (recommendation.actions?.length ?? 0) > 0;

                          if (recommendation.type === 'store-preview') {
                            const spHasActions = (recommendation.actions?.length ?? 0) > 0;
                            return (
                              <section className="recommendation-card is-store-preview" key={recommendation.label}>
                                <div className="sp-header">
                                  <strong>{recommendation.store}</strong>
                                </div>
                                <div className="sp-fields">
                                  <div className="sp-field">
                                    <span className="sp-field-label">時段</span>
                                    <span className="sp-field-value">{recommendation.time}</span>
                                  </div>
                                  <div className="sp-field">
                                    <span className="sp-field-label">人數</span>
                                    <span className="sp-field-value">{recommendation.party}</span>
                                  </div>
                                </div>
                                {recommendation.note && (
                                  <div className="sp-note">
                                    <span className="sp-field-label">備註</span>
                                    <span className="sp-field-value">{recommendation.note}</span>
                                  </div>
                                )}
                                {spHasActions && (
                                  <div className="recommendation-actions">
                                    {recommendation.actions.map((action, actionIndex) => (
                                      <button
                                        key={action}
                                        type="button"
                                        disabled={isBotBusy}
                                        className={[
                                          'recommendation-action',
                                          actionIndex === recommendation.actions.length - 1
                                            ? 'is-primary'
                                            : 'is-secondary',
                                        ].join(' ')}
                                        onClick={() => advanceConversation(action)}
                                      >
                                        {action}
                                      </button>
                                    ))}
                                  </div>
                                )}
                              </section>
                            );
                          }

                          if (recommendation.type === 'dish-card') {
                            return (
                              <section className="recommendation-card is-dish-card" key={recommendation.label}>
                                <img
                                  className="dc-photo"
                                  src={`/images/${recommendation.label}.webp`}
                                  alt={recommendation.label}
                                />
                                <div className="dc-content">
                                  <div>
                                    <strong>{recommendation.label}</strong>
                                    <span>{recommendation.meta}</span>
                                  </div>
                                  <p>{recommendation.detail}</p>
                                </div>
                              </section>
                            );
                          }

                          return (
                            <section
                              className={['recommendation-card', hasActions ? 'has-actions' : ''].filter(Boolean).join(' ')}
                              key={recommendation.label}
                            >
                              <div>
                                <strong>{recommendation.label}</strong>
                                <span>{recommendation.meta}</span>
                              </div>
                              <p>{recommendation.detail}</p>
                              {hasActions && (
                                <div className="recommendation-actions">
                                  {recommendation.actions.map((action, actionIndex) => (
                                    <button
                                      key={action}
                                      type="button"
                                      disabled={isBotBusy}
                                      className={[
                                        'recommendation-action',
                                        actionIndex === recommendation.actions.length - 1
                                          ? 'is-primary'
                                          : 'is-secondary',
                                      ].join(' ')}
                                      onClick={() => advanceConversation(action)}
                                    >
                                      {action}
                                    </button>
                                  ))}
                                </div>
                              )}
                            </section>
                          );
                        })}
                      </div>
                    </div>
                  ) : (
                    <p>{item.text}</p>
                  )}
                </article>
              ))}

              {isBotBusy && (
                <article className="message is-bot is-thinking" aria-label="Assistant thinking">
                  {pendingMessage ? (
                    <p className="is-pending">
                      <strong className="pending-label">{pendingMessage}</strong>
                      <span />
                      <span />
                      <span />
                    </p>
                  ) : (
                    <p>
                      <span />
                      <span />
                      <span />
                    </p>
                  )}
                </article>
              )}

              {showFollowUps && (
                <article className="message is-bot is-follow-ups">
                  <div className="follow-up-groups">
                    {visibleFollowUpGroups.map((group) => (
                      <section className="follow-up-group" key={group.label}>
                        <div>
                          {group.options.map((option) => (
                            <button
                              key={getOptionValue(option)}
                              type="button"
                              onClick={() => advanceConversation(getOptionValue(option))}
                            >
                              <span className="follow-up-arrow" aria-hidden="true">↳</span>
                              <span>{getOptionValue(option)}</span>
                            </button>
                          ))}
                        </div>
                      </section>
                    ))}
                  </div>
                </article>
              )}

              {showNextScenarioPrompt && nextScenario && (
                <article className="next-scenario-prompt">
                  <p className="nsp-label">場景完成</p>
                  <button
                    className="nsp-btn"
                    type="button"
                    onClick={() => selectScenario(nextScenario.id)}
                  >
                    <span className="nsp-btn-content">
                      <span>
                        <span className="nsp-count">{activeScenarioIndex + 2} / {scenarios.length}</span>
                        {nextScenario.title}
                      </span>
                      <span className="nsp-arrow">→</span>
                    </span>
                  </button>
                </article>
              )}

              {showEndPrompt && (
                <article className="next-scenario-prompt">
                  <p className="nsp-label">6 個場景全部完成</p>
                  <button
                    className="nsp-btn nsp-btn-end"
                    type="button"
                    onClick={() => setShowEndPage(true)}
                  >
                    <span className="nsp-btn-content">
                      <span>查看實作總結</span>
                      <span className="nsp-arrow">→</span>
                    </span>
                  </button>
                </article>
              )}
            </div>

            <form className="chat-composer" onSubmit={submitDraft}>
              <div className="composer-input-card">
                <textarea
                  aria-label="對話輸入"
                  className="composer-input"
                  ref={composerInputRef}
                  rows={2}
                  value={draft}
                  onChange={(event) => setDraft(event.target.value)}
                  onKeyDown={handleComposerKeyDown}
                />
                <div className="composer-toolbar">
                  <button aria-label="送出訊息" className="composer-submit" type="submit">
                    <span className="send-arrow-icon" aria-hidden="true">↑</span>
                  </button>
                </div>
              </div>
            </form>
          </section>
        </div>
      </section>

    </main>

      {showEndPage && (
        <div className="end-screen" role="dialog" aria-modal="true" aria-label="場景展示完畢">
          <div className="end-card">
            <span className="end-badge">6 / 6 完成</span>
            <h1 className="end-title">場景展示完畢</h1>
            <p className="end-subtitle">這份Demo跑了 6 個對話場景，為了滿足對話場景還需要實作以下功能：</p>
            <ul className="end-impl-list">
              <li>
                <strong>菜單資料結構化</strong>
                <span>菜單資料透過資料結構化，讓AI理解菜單內容</span>
              </li>
              <li>
                <strong>訂位系統Inline串接</strong>
                <span>對話內直接送出訂位，後台寫入紀錄並透過 Line / SMS 發送確認通知</span>
              </li>
              <li>
                <strong>意圖識別模型</strong>
                <span>分類輸入意圖（訂位、推薦、外帶、忌口篩選等）</span>
              </li>
              <li>
                <strong>對話狀態管理</strong>
                <span>多輪 context 追蹤、跨裝置會話同步</span>
              </li>
              <li>
                <strong>個人化資料層</strong>
                <span>儲存忌口設定、歷史訂單偏好、會員等級</span>
              </li>
            </ul>
            <div className="end-back-section">
              <p className="end-back-label">回顧場景</p>
              <div className="end-scenario-grid">
                {scenarios.map((scenario, i) => (
                  <button
                    key={scenario.id}
                    className="end-scenario-btn"
                    type="button"
                    onClick={() => selectScenario(scenario.id)}
                  >
                    <span className="end-scenario-num">{i + 1}</span>
                    <span>{scenario.title}</span>
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

export default App;
