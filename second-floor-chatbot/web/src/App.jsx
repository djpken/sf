import { Fragment, useEffect, useRef, useState } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { getLocale, persistLocale, t, STARTERS } from './i18n';

const API_BASE = import.meta.env.VITE_API_BASE ?? '';
const isDev = import.meta.env.DEV;

function getSessionId() {
  let id = localStorage.getItem('sf_session_id');
  if (!id) {
    id = (crypto.randomUUID?.() ?? `s-${Date.now()}-${Math.random().toString(16).slice(2)}`);
    localStorage.setItem('sf_session_id', id);
  }
  return id;
}

function formatTime(ts, locale) {
  return new Intl.DateTimeFormat(locale, { hour: 'numeric', minute: '2-digit' }).format(new Date(ts));
}

// 門市卡頂端的店面照。實拍照放 sf-menu/images/stores/，由 stores.json 的 image 指定。
// 還沒放照片(或載入失敗)時退回帶店名首字的占位 banner，不破版。
function StorePhoto({ src, name }) {
  const [failed, setFailed] = useState(false);
  if (!src || failed) {
    return (
      <div className="sc-photo sc-photo-fallback" aria-hidden="true">
        <span className="sc-photo-initial">{name?.[0] ?? '店'}</span>
      </div>
    );
  }
  return (
    <img
      className="sc-photo"
      src={src}
      alt={name}
      loading="lazy"
      onError={() => setFailed(true)}
    />
  );
}

function App() {
  const sessionId = useRef(getSessionId()).current;
  const [locale, setLocaleState] = useState(getLocale);
  const [messages, setMessages] = useState([]);
  const [conversationId, setConversationId] = useState(null);
  const [conversations, setConversations] = useState([]);
  const [draft, setDraft] = useState('');
  const [isBusy, setIsBusy] = useState(false);
  const [error, setError] = useState('');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [copiedIndex, setCopiedIndex] = useState(null);
  const [conversationCopied, setConversationCopied] = useState(false);
  const [contactOpen, setContactOpen] = useState(false);
  const [stores, setStores] = useState([]);
  const [pendingDeleteId, setPendingDeleteId] = useState(null);
  const mainRef = useRef(null);
  const messagesRef = useRef(null);
  const abortRef = useRef(null);
  const locationRef = useRef(null);      // 快取 {lat, lng}，取得失敗為 null
  const locationAskedRef = useRef(false); // 是否已嘗試請求過定位（只跳一次權限）

  const started = messages.length > 0;

  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  function switchLocale() {
    const next = locale === 'zh-TW' ? 'en' : 'zh-TW';
    setLocaleState(next);
    persistLocale(next);
  }

  function scrollToEnd() {
    requestAnimationFrame(() => {
      if (messagesRef.current) messagesRef.current.scrollTop = messagesRef.current.scrollHeight;
    });
  }
  useEffect(() => scrollToEnd(), [messages]);
  useEffect(() => () => abortRef.current?.abort(), []);

  useEffect(() => {
    function onKeyDown(e) {
      if ((e.metaKey || e.ctrlKey) && e.key === 'b') {
        e.preventDefault();
        setSidebarCollapsed((v) => !v);
      }
    }
    document.addEventListener('keydown', onKeyDown);
    return () => document.removeEventListener('keydown', onKeyDown);
  }, []);

  // iOS keyboard fix: 當虛擬鍵盤開關時,visualViewport 會縮小;
  // 直接更新 app-shell 高度,確保 composer 不被鍵盤遮住。
  // (dvh 在 iOS 15.4+ 內建支援;這個 hook 補全更舊版本。)
  useEffect(() => {
    const vv = window.visualViewport;
    const el = mainRef.current;
    if (!vv || !el) return;
    function updateHeight() {
      el.style.height = `${vv.height}px`;
    }
    vv.addEventListener('resize', updateHeight);
    updateHeight();
    return () => vv.removeEventListener('resize', updateHeight);
  }, []);

  useEffect(() => {
    refreshConversations();
    fetch(`${API_BASE}/api/stores`)
      .then((r) => r.json())
      .then((d) => setStores(d.stores ?? []))
      .catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!pendingDeleteId) return;
    const timer = setTimeout(() => setPendingDeleteId(null), 3000);
    function handleOutsideClick() { setPendingDeleteId(null); }
    document.addEventListener('click', handleOutsideClick);
    return () => {
      clearTimeout(timer);
      document.removeEventListener('click', handleOutsideClick);
    };
  }, [pendingDeleteId]);

  async function refreshConversations() {
    try {
      const res = await fetch(`${API_BASE}/api/conversations?session_id=${encodeURIComponent(sessionId)}`);
      const data = await res.json();
      setConversations(data.conversations ?? []);
    } catch { /* 列表非關鍵,失敗就略過 */ }
  }

  async function loadConversation(id) {
    abortRef.current?.abort();
    setSidebarOpen(false);
    setError('');
    try {
      const res = await fetch(`${API_BASE}/api/conversations/${id}?session_id=${encodeURIComponent(sessionId)}`);
      const data = await res.json();
      setMessages((data.messages ?? []).map((m) => {
        const SPECIAL_ROLES = ['booking', 'availability', 'lookup', 'store_card'];
        if (SPECIAL_ROLES.includes(m.role)) {
          try {
            if (m.role === 'booking') return { role: 'booking', booking: JSON.parse(m.content) };
            if (m.role === 'availability') return { role: 'availability', data: JSON.parse(m.content) };
            if (m.role === 'lookup') return { role: 'lookup', data: JSON.parse(m.content) };
            if (m.role === 'store_card') return { role: 'store_card', storeCard: JSON.parse(m.content) };
          } catch {
            return { role: 'model', content: m.content };
          }
        }
        return { role: m.role, content: m.content };
      }));
      setConversationId(id);
    } catch {
      setError(t(locale, 'error.load'));
    }
  }

  function requestDeleteConversation(id, event) {
    event.stopPropagation();
    setPendingDeleteId(id);
  }

  async function confirmDeleteConversation(id, event) {
    event.stopPropagation();
    setPendingDeleteId(null);
    try {
      await fetch(`${API_BASE}/api/conversations/${id}?session_id=${encodeURIComponent(sessionId)}`, { method: 'DELETE' });
      if (id === conversationId) newChat();
      refreshConversations();
    } catch { /* 略過 */ }
  }


  function newChat() {
    abortRef.current?.abort();
    setMessages([]);
    setConversationId(null);
    setDraft('');
    setError('');
    setIsBusy(false);
    setSidebarOpen(false);
  }

  // 首次呼叫時請求一次地理位置；成功存座標、失敗/拒絕/不支援存 null。
  // 之後直接回傳快取，不再跳權限提示。
  function ensureLocation() {
    if (locationAskedRef.current) return Promise.resolve(locationRef.current);
    locationAskedRef.current = true;
    if (!('geolocation' in navigator)) {
      locationRef.current = null;
      return Promise.resolve(null);
    }
    return new Promise((resolve) => {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          locationRef.current = { lat: pos.coords.latitude, lng: pos.coords.longitude, accuracy: pos.coords.accuracy };
          resolve(locationRef.current);
        },
        () => { locationRef.current = null; resolve(null); },
        { enableHighAccuracy: false, timeout: 8000, maximumAge: 600000 },
      );
    });
  }

  async function send(text) {
    const content = text.trim();
    if (!content || isBusy) return;

    setError('');
    setDraft('');
    const userMsg = { role: 'user', content, timestamp: Date.now() };
    const history = [...messages, userMsg];
    const cleared = history.map((m) => (m.suggestions ? { ...m, suggestions: undefined } : m));
    setMessages([...cleared, { role: 'model', content: '', streaming: true }]);
    setIsBusy(true);

    const controller = new AbortController();
    abortRef.current = controller;

    // 首次送訊息時請求定位；取得後隨每次請求附上，供後端推薦最近門市。
    const location = await ensureLocation();

    try {
      const res = await fetch(`${API_BASE}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: history
            .filter((m) => m.role === 'user' || m.role === 'model')
            .map(({ role, content }) => ({ role, content })),
          session_id: sessionId,
          conversation_id: conversationId,
          locale,
          ...(location ? { location } : {}),
        }),
        signal: controller.signal,
      });
      if (!res.ok || !res.body) throw new Error(`伺服器回應 ${res.status}`);

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      // eslint-disable-next-line no-constant-condition
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const events = buffer.split('\n\n');
        buffer = events.pop() ?? '';
        for (const evt of events) {
          const line = evt.split('\n').find((l) => l.startsWith('data:'));
          if (!line) continue;
          const payload = JSON.parse(line.slice(5).trim());
          if (payload.delta) appendDelta(payload.delta);
          else if (payload.menu_context) attachMenuContext(payload.menu_context);
          else if (payload.booking) appendBooking(payload.booking);
          else if (payload.availability) appendCard('availability', payload.availability);
          else if (payload.reservation_lookup) appendCard('lookup', payload.reservation_lookup);
          else if (payload.store_card) appendStoreCard(payload.store_card);
          else if (payload.suggestions?.ask?.length || payload.suggestions?.say?.length) attachSuggestions(payload.suggestions);
          else if (payload.conversation) setConversationId(payload.conversation.id);
          else if (payload.error) throw new Error(payload.error);
        }
      }
      finishStreaming();
      refreshConversations();
    } catch (err) {
      if (err.name === 'AbortError') return;
      setError(err.message || '連線發生問題');
      setMessages((items) => items.filter((m) => !(m.role === 'model' && m.streaming && !m.content)));
    } finally {
      setIsBusy(false);
      abortRef.current = null;
    }
  }

  function appendDelta(delta) {
    setMessages((items) => {
      const next = [...items];
      const last = next[next.length - 1];
      if (last?.role === 'model' && last.streaming) {
        next[next.length - 1] = { ...last, content: last.content + delta };
      }
      return next;
    });
  }

  function appendBooking(booking) {
    setMessages((items) => {
      const next = [...items];
      const insertAt = next.length > 0 && next[next.length - 1].role === 'model' ? next.length - 1 : next.length;
      next.splice(insertAt, 0, { role: 'booking', booking });
      return next;
    });
  }

  function appendStoreCard(storeCard) {
    setMessages((items) => {
      const next = [...items];
      const insertAt = next.length > 0 && next[next.length - 1].role === 'model' ? next.length - 1 : next.length;
      next.splice(insertAt, 0, { role: 'store_card', storeCard });
      return next;
    });
  }

  // 空位查詢卡 / 訂位查詢卡共用:插在串流中的助理訊息之前。
  function appendCard(role, data) {
    setMessages((items) => {
      const next = [...items];
      const insertAt = next.length > 0 && next[next.length - 1].role === 'model' ? next.length - 1 : next.length;
      next.splice(insertAt, 0, { role, data });
      return next;
    });
  }

  function attachSuggestions(suggestions) {
    setMessages((items) => {
      const next = [...items];
      for (let i = next.length - 1; i >= 0; i -= 1) {
        if (next[i].role === 'model') {
          next[i] = { ...next[i], suggestions };
          break;
        }
      }
      return next;
    });
  }

  function attachMenuContext(menuContext) {
    setMessages((items) => {
      const next = [...items];
      for (let i = next.length - 1; i >= 0; i -= 1) {
        if (next[i].role === 'model') {
          next[i] = { ...next[i], menuContext };
          break;
        }
      }
      return next;
    });
  }

  function finishStreaming() {
    setMessages((items) =>
      items.map((m) => (m.role === 'model' && m.streaming ? { ...m, streaming: false, timestamp: Date.now() } : m)),
    );
  }

  function copyMessage(content, index) {
    navigator.clipboard.writeText(content).then(() => {
      setCopiedIndex(index);
      setTimeout(() => setCopiedIndex(null), 1500);
    }).catch(() => {});
  }

  function copyConversation() {
    const text = messages
      .filter((m) => m.role === 'user' || m.role === 'model')
      .map((m) => {
        const role = m.role === 'user' ? 'User' : 'Assistant';
        return `[${role}]: ${m.content}`;
      })
      .join('\n\n');
    navigator.clipboard.writeText(text).then(() => {
      setConversationCopied(true);
      setTimeout(() => setConversationCopied(false), 1500);
    }).catch(() => {});
  }

  function onSubmit(event) {
    event.preventDefault();
    send(draft);
  }
  function onKeyDown(event) {
    if (event.key !== 'Enter' || event.shiftKey || event.nativeEvent.isComposing) return;
    event.preventDefault();
    event.currentTarget.form?.requestSubmit();
  }

  const lastModel = messages[messages.length - 1];
  const showThinking = isBusy && lastModel?.role === 'model' && lastModel.streaming && !lastModel.content;

  function renderMenuContext(items) {
    if (!items?.length) return null;
    return (
      <div className="menu-chips" aria-label={t(locale, 'menu.related')}>
        {items.map((item) => (
          <div key={item.name} className="menu-chip">
            <img
              src={`/images/${encodeURIComponent(item.name)}.webp`}
              alt={item.name}
              className="menu-chip-img"
              onError={(e) => { e.currentTarget.closest('.menu-chip').style.display = 'none'; }}
            />
            <span className="menu-chip-name">{item.name}</span>
          </div>
        ))}
      </div>
    );
  }

  function renderFollowups(s) {
    if (!s) return null;
    const items = [...(s.ask ?? []), ...(s.say ?? [])];
    if (items.length === 0) return null;
    const label = t(locale, 'followups.say');
    return (
      <div className="followups" role="group" aria-label={label}>
        <p className="followups-label">{label}</p>
        <ul className="followups-list">
          {items.map((q) => (
            <li key={q}>
              <button type="button" className="followup-item" disabled={isBusy} onClick={() => send(q)}>
                <span className="followup-icon" aria-hidden="true">▸</span>
                <span className="followup-text">{q}</span>
              </button>
            </li>
          ))}
        </ul>
      </div>
    );
  }

  const starters = STARTERS[locale] ?? STARTERS['zh-TW'];

  return (
    <main ref={mainRef} className={`app-shell${sidebarOpen ? ' is-sidebar-open' : ''}${sidebarCollapsed ? ' is-sidebar-collapsed' : ''}`}>
      <div className={`sidebar-backdrop${sidebarOpen ? ' is-visible' : ''}`} aria-hidden="true" onClick={() => setSidebarOpen(false)} />

      <aside className={`app-sidebar${sidebarOpen ? ' is-open' : ''}`} aria-label={t(locale, 'sidebar.label')}>
        <div className="psb-top">
          <span className="psb-wordmark">{t(locale, 'sidebar.wordmark')}</span>
          <button
            aria-label={t(locale, 'sidebar.close')}
            className="psb-layout-toggle"
            type="button"
            onClick={() => { setSidebarOpen(false); setSidebarCollapsed(true); }}
          >
            <span className="psb-layout-icon" aria-hidden="true" />
          </button>
        </div>

        <div className="psb-new-row">
          <button className="psb-new-btn" type="button" onClick={newChat}>
            <span className="psb-plus" aria-hidden="true">+</span>
            {t(locale, 'sidebar.new')}
          </button>
        </div>

        <div className="psb-conversations" aria-label={t(locale, 'sidebar.history')}>
          <p className="psb-section-label">{t(locale, 'sidebar.history')}</p>
          {conversations.length === 0 && <p className="psb-empty">{t(locale, 'sidebar.empty')}</p>}
          {conversations.map((conv) => (
            <button
              key={conv.id}
              className={`psb-conv-item${conv.id === conversationId ? ' is-active' : ''}`}
              type="button"
              onClick={() => loadConversation(conv.id)}
            >
              <span className="psb-conv-title">{conv.title || t(locale, 'sidebar.untitled')}</span>
              {pendingDeleteId === conv.id ? (
                <span className="psb-conv-delete-confirm" onClick={(e) => e.stopPropagation()}>
                  <span
                    role="button"
                    tabIndex={0}
                    aria-label={t(locale, 'sidebar.deleteConfirm')}
                    className="psb-conv-delete-yes"
                    onClick={(e) => confirmDeleteConversation(conv.id, e)}
                  >
                    {t(locale, 'sidebar.deleteConfirm')}
                  </span>
                </span>
              ) : (
                <span
                  role="button"
                  tabIndex={0}
                  aria-label={t(locale, 'sidebar.delete')}
                  className="psb-conv-delete"
                  onClick={(e) => requestDeleteConversation(conv.id, e)}
                >
                  ✕
                </span>
              )}
            </button>
          ))}
        </div>
      </aside>

      <section className="chat-panel" aria-label={t(locale, 'chat.label')}>
        <header className="chat-header">
          <button
            aria-label={t(locale, 'chat.menu')}
            className="frame-action frame-action-left"
            type="button"
            onClick={() => { setSidebarOpen((v) => !v); setSidebarCollapsed(false); }}
          >
            <span className="side-menu-icon" aria-hidden="true" />
          </button>
          <span className="eyebrow chat-title">{t(locale, 'chat.title')}</span>
          <div className="frame-actions-right">
            {isDev && (
              <button
                type="button"
                className={`frame-action dev-copy-convo${conversationCopied ? ' is-copied' : ''}`}
                aria-label={conversationCopied ? '已複製' : '複製對話'}
                title={conversationCopied ? '已複製' : '複製對話 (debug)'}
                onClick={copyConversation}
              >
                {conversationCopied ? (
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                    <polyline points="20 6 9 17 4 12"/>
                  </svg>
                ) : (
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                    <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
                    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
                  </svg>
                )}
              </button>
            )}
            <button
              type="button"
              className="frame-action contact-toggle"
              aria-label={t(locale, 'contact.label')}
              title={t(locale, 'contact.label')}
              onClick={() => setContactOpen(true)}
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.6 1.3h3a2 2 0 0 1 2 1.72c.127.96.362 1.903.7 2.81a2 2 0 0 1-.45 2.11L7.91 8.96a16 16 0 0 0 6.1 6.1l.96-.96a2 2 0 0 1 2.11-.45c.907.338 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/>
              </svg>
            </button>
            <button
              type="button"
              className="frame-action locale-toggle"
              aria-label={locale === 'zh-TW' ? 'Switch to English' : '切換為中文'}
              onClick={switchLocale}
            >
              {t(locale, 'lang.switch')}
            </button>
          </div>
        </header>

        <div className="messages" ref={messagesRef}>
          <div className="messages-inner">
            {!started && (
              <div className="welcome">
                <h1 className="welcome-title">{t(locale, 'welcome.title')}</h1>
                <p className="welcome-subtitle">{t(locale, 'welcome.subtitle')}</p>
                <div className="starter-grid">
                  {starters.map((s) => (
                    <button key={s} type="button" className="starter-card" onClick={() => send(s)}>
                      <span className="starter-arrow" aria-hidden="true">↳</span>
                      <span>{s}</span>
                    </button>
                  ))}
                </div>
              </div>
            )}

            {messages.map((m, index) => {
              if (m.role === 'model' && m.streaming && !m.content) return null;
              if (m.role === 'booking') {
                const b = m.booking;
                const failed = b.status === 'failed';
                return (
                  <article className="message is-bot is-recommendations" key={`booking-${index}`}>
                    <div className="recommendation-bubble">
                      <p>{failed ? t(locale, 'booking.failed') : t(locale, 'booking.confirmed', { id: b.booking_id })}</p>
                      <div className="recommendation-list">
                        <section className={`recommendation-card is-store-preview${failed ? ' is-failed' : ''}`}>
                          <div className="sp-header">
                            <strong>{b.store}</strong>
                            {failed && <span className="sc-status is-full">{t(locale, 'avail.full')}</span>}
                          </div>
                          <div className="sp-fields">
                            <div className="sp-field">
                              <span className="sp-field-label">{t(locale, 'booking.time')}</span>
                              <span className="sp-field-value">{b.date} {b.time}</span>
                            </div>
                            <div className="sp-field">
                              <span className="sp-field-label">{t(locale, 'booking.party')}</span>
                              <span className="sp-field-value">{b.party_size}{locale === 'zh-TW' ? ' 位' : ''}</span>
                            </div>
                          </div>
                          {b.note && (
                            <div className="sp-note">
                              <span className="sp-field-label">{t(locale, 'booking.note')}</span>
                              <span className="sp-field-value">{b.note}</span>
                            </div>
                          )}
                          {failed && b.alternatives?.length > 0 && (
                            <div className="sp-note">
                              <span className="sp-field-label">{t(locale, 'avail.alts')}</span>
                              <span className="sc-alts">
                                {b.alternatives.map((alt) => (
                                  <button
                                    key={alt}
                                    type="button"
                                    className="sc-alt"
                                    disabled={isBusy}
                                    onClick={() => send(t(locale, 'avail.altSend', { time: alt }))}
                                  >
                                    {alt}
                                  </button>
                                ))}
                              </span>
                            </div>
                          )}
                        </section>
                      </div>
                    </div>
                  </article>
                );
              }
              if (m.role === 'availability') {
                const a = m.data;
                return (
                  <article className="message is-bot is-store-card-msg" key={`avail-${index}`}>
                    <div className="store-card">
                      <div className="sc-header">
                        <span className="sc-pin" aria-hidden="true">🗓️</span>
                        <strong className="sc-name">{a.store}</strong>
                        <span className={`sc-status${a.available ? ' is-ok' : ' is-full'}`}>
                          {t(locale, a.available ? 'avail.available' : 'avail.full')}
                        </span>
                      </div>
                      <div className="sc-body">
                        <div className="sc-row">
                          <span className="sc-label">{t(locale, 'avail.date')}</span>
                          <span className="sc-value">{a.date}</span>
                        </div>
                        <div className="sc-row">
                          <span className="sc-label">{t(locale, 'avail.time')}</span>
                          <span className="sc-value">{a.time}</span>
                        </div>
                        <div className="sc-row">
                          <span className="sc-label">{t(locale, 'avail.party')}</span>
                          <span className="sc-value">{a.party_size}{locale === 'zh-TW' ? ' 位' : ''}</span>
                        </div>
                      </div>
                      {!a.available && a.alternatives?.length > 0 && (
                        <div className="sc-tags">
                          <span className="sc-label sc-alts-label">{t(locale, 'avail.alts')}</span>
                          {a.alternatives.map((alt) => (
                            <button
                              key={alt}
                              type="button"
                              className="sc-alt"
                              disabled={isBusy}
                              onClick={() => send(t(locale, 'avail.altSend', { time: alt }))}
                            >
                              {alt}
                            </button>
                          ))}
                        </div>
                      )}
                    </div>
                  </article>
                );
              }
              if (m.role === 'lookup') {
                const r = m.data;
                return (
                  <article className="message is-bot is-store-card-msg" key={`lookup-${index}`}>
                    <div className={`store-card${r.found ? '' : ' is-empty-lookup'}`}>
                      <div className="sc-header">
                        <span className="sc-pin" aria-hidden="true">{r.found ? '🎫' : '🔍'}</span>
                        <strong className="sc-name">
                          {r.found ? r.store : t(locale, 'lookup.none')}
                        </strong>
                      </div>
                      {r.found ? (
                        <>
                          <div className="sc-body">
                            <div className="sc-row">
                              <span className="sc-label">{t(locale, 'lookup.ref')}</span>
                              <span className="sc-value">{r.booking_id}</span>
                            </div>
                            <div className="sc-row">
                              <span className="sc-label">{t(locale, 'avail.time')}</span>
                              <span className="sc-value">{r.date} {r.time}</span>
                            </div>
                            <div className="sc-row">
                              <span className="sc-label">{t(locale, 'avail.party')}</span>
                              <span className="sc-value">{r.party_size}{locale === 'zh-TW' ? ' 位' : ''}</span>
                            </div>
                            {r.note && (
                              <div className="sc-row">
                                <span className="sc-label">{t(locale, 'booking.note')}</span>
                                <span className="sc-value">{r.note}</span>
                              </div>
                            )}
                          </div>
                          <div className="sc-tags">
                            <span className="sc-status is-ok">{t(locale, 'status.confirmed')}</span>
                          </div>
                        </>
                      ) : (
                        <div className="sc-body">
                          <span className="sc-value sc-muted">{t(locale, 'lookup.noneHint', { id: r.booking_id })}</span>
                        </div>
                      )}
                    </div>
                  </article>
                );
              }
              if (m.role === 'store_card') {
                const s = m.storeCard;
                return (
                  <article className="message is-bot is-store-card-msg" key={`store-card-${index}`}>
                    <div className="store-card">
                      <StorePhoto src={s.image} name={s.store} />
                      <div className="sc-header">
                        <span className="sc-pin" aria-hidden="true">📍</span>
                        <strong className="sc-name">{s.store}</strong>
                      </div>
                      <div className="sc-body">
                        {s.address && (
                          <div className="sc-row">
                            <span className="sc-label">{t(locale, 'store.address')}</span>
                            <span className="sc-value">{s.address}</span>
                          </div>
                        )}
                        {s.phone && (
                          <div className="sc-row">
                            <span className="sc-label">{t(locale, 'store.phone')}</span>
                            <a className="sc-value sc-phone" href={`tel:${s.phone}`}>{s.phone}</a>
                          </div>
                        )}
                        {s.hours && (
                          <div className="sc-row">
                            <span className="sc-label">{t(locale, 'store.hours')}</span>
                            <span className="sc-value">{s.hours}</span>
                          </div>
                        )}
                      </div>
                      {s.tags?.length > 0 && (
                        <div className="sc-tags">
                          {s.tags.map((tag) => (
                            <span key={tag} className="sc-tag">{tag}</span>
                          ))}
                        </div>
                      )}
                    </div>
                  </article>
                );
              }
              return (
                <Fragment key={`${m.role}-${index}`}>
                  <article
                    className={['message', m.role === 'user' ? 'is-guest' : 'is-bot', m.streaming ? 'is-streaming' : '']
                      .filter(Boolean).join(' ')}
                  >
                    {m.role === 'user' ? (
                      <div className="user-msg-body">
                        <p>{m.content}</p>
                        {m.timestamp && (
                          <div className="user-msg-actions">
                            <time className="msg-time">{formatTime(m.timestamp, locale)}</time>
                            {isDev && (
                              <button
                                className={`copy-msg-btn${copiedIndex === index ? ' is-copied' : ''}`}
                                type="button"
                                aria-label={t(locale, copiedIndex === index ? 'copied' : 'copy')}
                                title={t(locale, copiedIndex === index ? 'copied' : 'copy')}
                                onClick={() => copyMessage(m.content, index)}
                              >
                                {copiedIndex === index ? (
                                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                                    <polyline points="20 6 9 17 4 12"/>
                                  </svg>
                                ) : (
                                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                                    <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
                                    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
                                  </svg>
                                )}
                              </button>
                            )}
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="bot-msg-body">
                        <div className="md-content">
                          <ReactMarkdown remarkPlugins={[remarkGfm]}>{m.content}</ReactMarkdown>
                        </div>
                        {!m.streaming && (isDev || m.timestamp) && (
                          <div className="bot-msg-actions">
                            {isDev && (
                              <button
                                className={`copy-msg-btn${copiedIndex === index ? ' is-copied' : ''}`}
                                type="button"
                                aria-label={t(locale, copiedIndex === index ? 'copied' : 'copy')}
                                title={t(locale, copiedIndex === index ? 'copied' : 'copy')}
                                onClick={() => copyMessage(m.content, index)}
                              >
                                {copiedIndex === index ? (
                                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                                    <polyline points="20 6 9 17 4 12"/>
                                  </svg>
                                ) : (
                                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                                    <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
                                    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
                                  </svg>
                                )}
                              </button>
                            )}
                            {m.timestamp && <time className="msg-time">{formatTime(m.timestamp, locale)}</time>}
                          </div>
                        )}
                      </div>
                    )}
                  </article>
                  {m.role === 'model' && !m.streaming && renderMenuContext(m.menuContext)}
                  {m.role === 'model' && !m.streaming && renderFollowups(m.suggestions)}
                </Fragment>
              );
            })}

            {showThinking && (
              <article className="message is-bot is-thinking" aria-label="Assistant thinking">
                <p><span /><span /><span /></p>
              </article>
            )}

            {error && (
              <article className="message is-bot" role="alert">
                <p className="message-error">⚠️ {error}</p>
              </article>
            )}
          </div>
        </div>

        {/* 聯絡人工 bottom sheet */}
        {contactOpen && (
          <div className="contact-sheet-backdrop" onClick={() => setContactOpen(false)} aria-hidden="true" />
        )}
        <div className={`contact-sheet${contactOpen ? ' is-open' : ''}`} role="dialog" aria-modal="true" aria-label={t(locale, 'contact.label')}>
          <div className="contact-sheet-header">
            <span className="contact-sheet-title">{t(locale, 'contact.title')}</span>
            <button type="button" className="contact-sheet-close" aria-label={t(locale, 'sidebar.close')} onClick={() => setContactOpen(false)}>✕</button>
          </div>
          <div className="contact-store-list">
            {stores.map((s) => (
              <div key={s.name} className="contact-store-row">
                <span className="contact-store-name">{s.name}</span>
                <a className="contact-store-phone" href={`tel:${s.phone}`}>{s.phone}</a>
              </div>
            ))}
          </div>
        </div>

        <form className="chat-composer" onSubmit={onSubmit}>
          <div className="composer-input-card">
            <textarea
              aria-label={t(locale, 'composer.placeholder')}
              className="composer-input"
              rows={2}
              value={draft}
              placeholder={t(locale, 'composer.placeholder')}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={onKeyDown}
            />
            <div className="composer-toolbar">
              <button
                aria-label={t(locale, 'send')}
                className="composer-submit"
                type="submit"
                disabled={isBusy || !draft.trim()}
              >
                <span className="send-arrow-icon" aria-hidden="true">↑</span>
              </button>
            </div>
          </div>
        </form>
      </section>
    </main>
  );
}

export default App;
