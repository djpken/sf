import { useEffect, useRef, useState } from 'react';
import logoUrl from './assets/logo-lg.png';

const API_BASE = import.meta.env.VITE_API_BASE ?? '';

// 匿名裝置 session:存 localStorage,無登入,對話/忌口記憶都綁這個 id
function getSessionId() {
  let id = localStorage.getItem('sf_session_id');
  if (!id) {
    id = (crypto.randomUUID?.() ?? `s-${Date.now()}-${Math.random().toString(16).slice(2)}`);
    localStorage.setItem('sf_session_id', id);
  }
  return id;
}

const STARTERS = [
  '今晚 4 個朋友想吃貳樓，想找可以慢慢聊天的位子。',
  '想幫女友慶生，但不要那種很正式的餐廳。',
  '今天想吃清爽一點，但不要吃完很空。',
  '第一次吃貳樓，不知道招牌是什麼，也怕點太多。',
  '想帶兩份主餐回家，一份不要太辣。',
  '我同事不吃豬肉，想幫大家找可以一起點的餐。',
];

function App() {
  const sessionId = useRef(getSessionId()).current;
  const [messages, setMessages] = useState([]);
  const [conversationId, setConversationId] = useState(null);
  const [conversations, setConversations] = useState([]);
  const [draft, setDraft] = useState('');
  const [isBusy, setIsBusy] = useState(false);
  const [error, setError] = useState('');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const messagesRef = useRef(null);
  const abortRef = useRef(null);

  const started = messages.length > 0;

  function scrollToEnd() {
    requestAnimationFrame(() => {
      if (messagesRef.current) messagesRef.current.scrollTop = messagesRef.current.scrollHeight;
    });
  }
  useEffect(() => scrollToEnd(), [messages]);
  useEffect(() => () => abortRef.current?.abort(), []);

  // 開場載入對話列表
  useEffect(() => {
    refreshConversations();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
      setMessages((data.messages ?? []).map((m) => ({ role: m.role, content: m.content })));
      setConversationId(id);
    } catch {
      setError('載入對話失敗');
    }
  }

  async function deleteConversation(id, event) {
    event.stopPropagation();
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

  async function send(text) {
    const content = text.trim();
    if (!content || isBusy) return;

    setError('');
    setDraft('');
    const history = [...messages, { role: 'user', content }];
    setMessages([...history, { role: 'model', content: '', streaming: true }]);
    setIsBusy(true);

    const controller = new AbortController();
    abortRef.current = controller;

    try {
      const res = await fetch(`${API_BASE}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: history, session_id: sessionId, conversation_id: conversationId }),
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
          else if (payload.booking) appendBooking(payload.booking);
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

  function finishStreaming() {
    setMessages((items) =>
      items.map((m) => (m.role === 'model' && m.streaming ? { ...m, streaming: false } : m)),
    );
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

  return (
    <main className={`app-shell${sidebarOpen ? ' is-sidebar-open' : ''}`}>
      {sidebarOpen && (
        <div className="sidebar-backdrop" aria-hidden="true" onClick={() => setSidebarOpen(false)} />
      )}

      <aside className={`app-sidebar${sidebarOpen ? ' is-open' : ''}`} aria-label="對話列表">
        <div className="psb-top">
          <span className="psb-logo" aria-hidden="true"><img className="psb-logo-img" src={logoUrl} alt="" /></span>
          <span className="psb-wordmark">貳樓助理</span>
          <button aria-label="關閉側欄" className="psb-layout-toggle" type="button" onClick={() => setSidebarOpen(false)}>
            <span className="psb-layout-icon" aria-hidden="true" />
          </button>
        </div>

        <div className="psb-new-row">
          <button className="psb-new-btn" type="button" onClick={newChat}>
            <span className="psb-plus" aria-hidden="true">+</span>
            新對話
          </button>
        </div>

        <div className="psb-conversations" aria-label="歷史對話">
          {conversations.length === 0 && <p className="psb-empty">還沒有對話紀錄</p>}
          {conversations.map((conv) => (
            <button
              key={conv.id}
              className={`psb-conv-item${conv.id === conversationId ? ' is-active' : ''}`}
              type="button"
              onClick={() => loadConversation(conv.id)}
            >
              <span className="psb-conv-title">{conv.title || '未命名對話'}</span>
              <span
                role="button"
                tabIndex={0}
                aria-label="刪除對話"
                className="psb-conv-delete"
                onClick={(e) => deleteConversation(conv.id, e)}
              >
                ✕
              </span>
            </button>
          ))}
        </div>
      </aside>

      <section className="chat-panel" aria-label="貳樓助理對話">
        <header className="chat-header">
          <button aria-label="對話選單" className="frame-action frame-action-left" type="button" onClick={() => setSidebarOpen((v) => !v)}>
            <span className="side-menu-icon" aria-hidden="true" />
          </button>
          <span className="eyebrow chat-title">Second Floor Assistant</span>
          <div className="frame-actions-right" aria-label="對話操作">
            <button aria-label="新增對話" className="frame-action" type="button" onClick={newChat}>
              <span className="new-chat-icon" aria-hidden="true" />
            </button>
          </div>
        </header>

        <div className="messages" ref={messagesRef}>
          <div className="messages-inner">
            {!started && (
              <div className="welcome">
                <div className="welcome-mark" aria-hidden="true"><img className="welcome-mark-img" src={logoUrl} alt="" /></div>
                <h1 className="welcome-title">嗨,我是貳樓 AI 助理</h1>
                <p className="welcome-subtitle">
                  幫你看菜單、配餐點、找適合的門市時段。從下面挑一個,或直接打字開始。
                </p>
                <div className="starter-grid">
                  {STARTERS.map((s) => (
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
                return (
                  <article className="message is-bot is-recommendations" key={`booking-${index}`}>
                    <div className="recommendation-bubble">
                      <p>✅ 訂位已送出（測試）· 單號 {b.booking_id}</p>
                      <div className="recommendation-list">
                        <section className="recommendation-card is-store-preview">
                          <div className="sp-header"><strong>{b.store}</strong></div>
                          <div className="sp-fields">
                            <div className="sp-field"><span className="sp-field-label">時段</span><span className="sp-field-value">{b.date} {b.time}</span></div>
                            <div className="sp-field"><span className="sp-field-label">人數</span><span className="sp-field-value">{b.party_size} 位</span></div>
                          </div>
                          {b.note && (
                            <div className="sp-note"><span className="sp-field-label">備註</span><span className="sp-field-value">{b.note}</span></div>
                          )}
                        </section>
                      </div>
                    </div>
                  </article>
                );
              }
              return (
                <article
                  className={['message', m.role === 'user' ? 'is-guest' : 'is-bot', m.streaming ? 'is-streaming' : '']
                    .filter(Boolean).join(' ')}
                  key={`${m.role}-${index}`}
                >
                  <p>{m.content}</p>
                </article>
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

        <form className="chat-composer" onSubmit={onSubmit}>
          <div className="composer-input-card">
            <textarea
              aria-label="對話輸入"
              className="composer-input"
              rows={2}
              value={draft}
              placeholder="輸入訊息,或點上方建議開始…"
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={onKeyDown}
            />
            <div className="composer-toolbar">
              <button aria-label="送出訊息" className="composer-submit" type="submit" disabled={isBusy || !draft.trim()}>
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
