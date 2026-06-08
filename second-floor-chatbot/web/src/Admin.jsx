import { useEffect, useState } from 'react';

const API_BASE = import.meta.env.VITE_API_BASE ?? '';
const TOKEN_KEY = 'sf_admin_token';

const TYPE_LABELS = { gemini: 'Gemini', openai: 'OpenAI', azure: 'Azure OpenAI' };

const EMPTY_FORM = {
  id: null,
  name: '',
  type: 'gemini',
  model: '',
  api_key: '',
  base_url: '',
  use_custom_url: false,
  api_version: '',
};

function Admin() {
  const [token, setToken] = useState(() => sessionStorage.getItem(TOKEN_KEY) || '');
  const [authed, setAuthed] = useState(false);
  const [loginInput, setLoginInput] = useState('');
  const [loginError, setLoginError] = useState('');

  const [providers, setProviders] = useState([]);
  const [activeId, setActiveId] = useState('');
  const [defaults, setDefaults] = useState({});
  const [form, setForm] = useState(null); // null = 表單關閉
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [testResult, setTestResult] = useState({}); // { [id]: {ok, msg} }

  // 帶 admin token 的 fetch;401 時登出回登入畫面。
  async function api(path, opts = {}) {
    const res = await fetch(`${API_BASE}${path}`, {
      ...opts,
      headers: {
        'Content-Type': 'application/json',
        'X-Admin-Token': token,
        ...(opts.headers || {}),
      },
    });
    if (res.status === 401) {
      sessionStorage.removeItem(TOKEN_KEY);
      setAuthed(false);
      setToken('');
      throw new Error('登入逾時或密碼錯誤,請重新登入');
    }
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.detail || `錯誤 ${res.status}`);
    return data;
  }

  async function refresh() {
    try {
      const data = await api('/api/admin/providers');
      setProviders(data.providers);
      setActiveId(data.active_id);
      setDefaults(data.defaults || {});
      setError('');
    } catch (e) {
      setError(e.message);
    }
  }

  // 進來時若 sessionStorage 已有 token,直接試著載入。
  useEffect(() => {
    if (!token) return;
    (async () => {
      try {
        await api('/api/admin/providers').then((data) => {
          setProviders(data.providers);
          setActiveId(data.active_id);
          setDefaults(data.defaults || {});
          setAuthed(true);
        });
      } catch {
        setAuthed(false);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleLogin(e) {
    e.preventDefault();
    setLoginError('');
    try {
      const res = await fetch(`${API_BASE}/api/admin/auth`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: loginInput }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.detail || '登入失敗');
      sessionStorage.setItem(TOKEN_KEY, loginInput);
      setToken(loginInput);
      setAuthed(true);
      setLoginInput('');
    } catch (err) {
      setLoginError(err.message);
    }
  }

  function logout() {
    sessionStorage.removeItem(TOKEN_KEY);
    setToken('');
    setAuthed(false);
  }

  function openCreate() {
    setForm({ ...EMPTY_FORM });
    setError('');
  }

  function openEdit(p) {
    setForm({
      id: p.id,
      name: p.name,
      type: p.type,
      model: p.model,
      api_key: '', // 留空 = 不變更
      base_url: p.base_url,
      use_custom_url: p.use_custom_url,
      api_version: p.api_version || '',
    });
    setError('');
  }

  async function saveForm(e) {
    e.preventDefault();
    setBusy(true);
    setError('');
    const isAzure = form.type === 'azure';
    const payload = {
      name: form.name.trim() || TYPE_LABELS[form.type],
      type: form.type,
      model: form.model.trim(),
      api_key: form.api_key,
      // Azure 一定用自訂 endpoint;其他類型看是否勾「使用預設網址」。
      base_url: isAzure ? form.base_url.trim() : (form.use_custom_url ? form.base_url.trim() : ''),
      use_custom_url: isAzure ? true : form.use_custom_url,
      api_version: isAzure ? form.api_version.trim() : '',
    };
    try {
      if (form.id) {
        await api(`/api/admin/providers/${form.id}`, {
          method: 'PUT',
          body: JSON.stringify(payload),
        });
      } else {
        await api('/api/admin/providers', {
          method: 'POST',
          body: JSON.stringify(payload),
        });
      }
      setForm(null);
      await refresh();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function activate(id) {
    try {
      await api(`/api/admin/providers/${id}/activate`, { method: 'POST' });
      await refresh();
    } catch (e) {
      setError(e.message);
    }
  }

  async function remove(id) {
    if (!window.confirm('確定刪除這個 provider?')) return;
    try {
      await api(`/api/admin/providers/${id}`, { method: 'DELETE' });
      await refresh();
    } catch (e) {
      setError(e.message);
    }
  }

  async function test(id) {
    setTestResult((r) => ({ ...r, [id]: { loading: true } }));
    try {
      const data = await api(`/api/admin/providers/${id}/test`, { method: 'POST' });
      setTestResult((r) => ({
        ...r,
        [id]: data.ok
          ? { ok: true, msg: `連線正常(${data.model})` }
          : { ok: false, msg: data.error || '測試失敗' },
      }));
    } catch (e) {
      setTestResult((r) => ({ ...r, [id]: { ok: false, msg: e.message } }));
    }
  }

  // ─── 登入畫面 ───────────────────────────────────────────────
  if (!authed) {
    return (
      <div className="admin-login">
        <form className="admin-login-card" onSubmit={handleLogin}>
          <h1>Provider 管理</h1>
          <p className="admin-muted">請輸入管理密碼</p>
          <input
            type="password"
            value={loginInput}
            onChange={(e) => setLoginInput(e.target.value)}
            placeholder="ADMIN_TOKEN"
            autoFocus
          />
          {loginError && <div className="admin-error">{loginError}</div>}
          <button type="submit" className="admin-btn admin-btn-primary">
            登入
          </button>
        </form>
      </div>
    );
  }

  // ─── 主畫面 ─────────────────────────────────────────────────
  const typeDefault = defaults[form?.type] || {};
  const formIsAzure = form?.type === 'azure';

  return (
    <div className="admin">
      <header className="admin-header">
        <div>
          <h1>Provider 管理</h1>
          <p className="admin-muted">設定多組 LLM provider,選擇其一啟用。切換即時生效,不需重啟。</p>
        </div>
        <div className="admin-header-actions">
          <a className="admin-btn" href="/">← 回聊天</a>
          <button className="admin-btn" onClick={logout}>登出</button>
        </div>
      </header>

      {error && <div className="admin-error admin-banner">{error}</div>}

      <div className="admin-toolbar">
        <button className="admin-btn admin-btn-primary" onClick={openCreate}>
          + 新增 provider
        </button>
      </div>

      <div className="admin-list">
        {providers.length === 0 && (
          <div className="admin-empty">還沒有任何 provider,點「新增 provider」開始。</div>
        )}
        {providers.map((p) => {
          const isActive = p.id === activeId;
          const tr = testResult[p.id];
          const isAzure = p.type === 'azure';
          const urlLabel = isAzure
            ? (p.base_url || '(未填 endpoint)')
            : p.use_custom_url
              ? p.base_url || '(未填自訂網址)'
              : `預設${(defaults[p.type]?.base_url) ? `(${defaults[p.type].base_url})` : ''}`;
          return (
            <div key={p.id} className={`admin-card${isActive ? ' is-active' : ''}`}>
              <div className="admin-card-main">
                <div className="admin-card-title">
                  <span className="admin-pill">{TYPE_LABELS[p.type] || p.type}</span>
                  <strong>{p.name}</strong>
                  {isActive && <span className="admin-badge">使用中</span>}
                </div>
                <dl className="admin-meta">
                  <div><dt>{isAzure ? 'Deployment' : 'Model'}</dt><dd>{p.model || '(預設)'}</dd></div>
                  <div><dt>{isAzure ? 'Endpoint' : 'URL'}</dt><dd>{urlLabel}</dd></div>
                  {isAzure && <div><dt>API Version</dt><dd>{p.api_version || '(預設)'}</dd></div>}
                  <div><dt>API Key</dt><dd>{p.has_key ? `••••${p.key_hint}` : '(未設定)'}</dd></div>
                </dl>
                {tr && (
                  <div className={`admin-test ${tr.ok ? 'is-ok' : tr.loading ? '' : 'is-fail'}`}>
                    {tr.loading ? '測試中…' : tr.msg}
                  </div>
                )}
              </div>
              <div className="admin-card-actions">
                {!isActive && (
                  <button className="admin-btn admin-btn-primary" onClick={() => activate(p.id)}>
                    啟用
                  </button>
                )}
                <button className="admin-btn" onClick={() => test(p.id)}>測試</button>
                <button className="admin-btn" onClick={() => openEdit(p)}>編輯</button>
                <button className="admin-btn admin-btn-danger" onClick={() => remove(p.id)}>刪除</button>
              </div>
            </div>
          );
        })}
      </div>

      {/* ─── 新增/編輯表單 ─── */}
      {form && (
        <div className="admin-modal-overlay" onClick={() => !busy && setForm(null)}>
          <form className="admin-modal" onClick={(e) => e.stopPropagation()} onSubmit={saveForm}>
            <h2>{form.id ? '編輯 provider' : '新增 provider'}</h2>

            <label className="admin-field">
              <span>名稱</span>
              <input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder={TYPE_LABELS[form.type]}
              />
            </label>

            <label className="admin-field">
              <span>類型</span>
              <select
                value={form.type}
                onChange={(e) => setForm({ ...form, type: e.target.value })}
              >
                <option value="gemini">Gemini</option>
                <option value="openai">OpenAI</option>
                <option value="azure">Azure OpenAI</option>
              </select>
            </label>

            <label className="admin-field">
              <span>{formIsAzure ? 'Deployment 名稱' : 'Model'}</span>
              <input
                value={form.model}
                onChange={(e) => setForm({ ...form, model: e.target.value })}
                placeholder={formIsAzure ? '如 gpt-4o-mini' : (typeDefault.model || '')}
              />
            </label>

            <label className="admin-field">
              <span>API Key</span>
              <input
                type="password"
                value={form.api_key}
                onChange={(e) => setForm({ ...form, api_key: e.target.value })}
                placeholder={form.id ? '留空 = 不變更' : '貼上 API key'}
              />
            </label>

            {formIsAzure ? (
              <>
                <label className="admin-field">
                  <span>Resource Endpoint</span>
                  <input
                    value={form.base_url}
                    onChange={(e) => setForm({ ...form, base_url: e.target.value })}
                    placeholder="https://xxx.cognitiveservices.azure.com/"
                  />
                </label>
                <label className="admin-field">
                  <span>API Version</span>
                  <input
                    value={form.api_version}
                    onChange={(e) => setForm({ ...form, api_version: e.target.value })}
                    placeholder={typeDefault.api_version || '2024-10-21'}
                  />
                </label>
              </>
            ) : (
              <div className="admin-field">
                <span>API URL</span>
                <div className="admin-url-row">
                  <input
                    value={form.use_custom_url ? form.base_url : (typeDefault.base_url || '(SDK 預設)')}
                    onChange={(e) => setForm({ ...form, base_url: e.target.value })}
                    disabled={!form.use_custom_url}
                    placeholder={typeDefault.base_url || 'https://...'}
                  />
                  <label className="admin-checkbox">
                    <input
                      type="checkbox"
                      checked={!form.use_custom_url}
                      onChange={(e) => setForm({ ...form, use_custom_url: !e.target.checked })}
                    />
                    <span>使用預設網址</span>
                  </label>
                </div>
              </div>
            )}

            {error && <div className="admin-error">{error}</div>}

            <div className="admin-modal-actions">
              <button type="button" className="admin-btn" onClick={() => setForm(null)} disabled={busy}>
                取消
              </button>
              <button type="submit" className="admin-btn admin-btn-primary" disabled={busy}>
                {busy ? '儲存中…' : '儲存'}
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}

export default Admin;
