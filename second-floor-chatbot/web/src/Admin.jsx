import { useEffect, useState } from 'react';

const API_BASE = import.meta.env.VITE_API_BASE ?? '';
const TOKEN_KEY = 'sf_admin_token';

const TYPE_LABELS = { gemini: 'Gemini', openai: 'OpenAI', azure: 'Azure OpenAI' };

const EMPTY_PROVIDER_FORM = {
  id: null, name: '', type: 'gemini', model: '', api_key: '',
  base_url: '', use_custom_url: false, api_version: '',
};

const SPACING_OPTS = ['', '寬敞', '一般', '稍擁擠'];
const NOISE_OPTS   = ['', '安靜', '一般', '熱鬧'];

function Admin() {
  const [token, setToken] = useState(() => sessionStorage.getItem(TOKEN_KEY) || '');
  const [authed, setAuthed] = useState(false);
  const [loginInput, setLoginInput] = useState('');
  const [loginError, setLoginError] = useState('');
  const [activeTab, setActiveTab] = useState('providers');

  // ─── Provider tab state ─────────────────────────────────────
  const [providers, setProviders] = useState([]);
  const [activeId, setActiveId] = useState('');
  const [defaults, setDefaults] = useState({});
  const [form, setForm] = useState(null);
  const [provError, setProvError] = useState('');
  const [busy, setBusy] = useState(false);
  const [testResult, setTestResult] = useState({});

  // ─── Store tab state ────────────────────────────────────────
  const [stores, setStores] = useState([]);
  const [storeForm, setStoreForm] = useState(null);
  const [storeBusy, setStoreBusy] = useState(false);
  const [storeError, setStoreError] = useState('');

  // ─── Menu tab state ─────────────────────────────────────────
  const [menuItems, setMenuItems] = useState([]);
  const [menuForm, setMenuForm] = useState(null);
  const [menuBusy, setMenuBusy] = useState(false);
  const [menuError, setMenuError] = useState('');
  const [menuCategory, setMenuCategory] = useState('');

  // ─── Contact tab state ───────────────────────────────────────
  const [contactPhone, setContactPhone] = useState('');
  const [contactNote, setContactNote] = useState('');
  const [contactBusy, setContactBusy] = useState(false);
  const [contactError, setContactError] = useState('');
  const [contactSaved, setContactSaved] = useState(false);

  // ─── api helper ─────────────────────────────────────────────
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

  // ─── provider helpers ────────────────────────────────────────
  async function refreshProviders() {
    try {
      const data = await api('/api/admin/providers');
      setProviders(data.providers);
      setActiveId(data.active_id);
      setDefaults(data.defaults || {});
      setProvError('');
    } catch (e) {
      setProvError(e.message);
    }
  }

  useEffect(() => {
    if (!token) return;
    (async () => {
      try {
        const data = await api('/api/admin/providers');
        setProviders(data.providers);
        setActiveId(data.active_id);
        setDefaults(data.defaults || {});
        setAuthed(true);
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
    setForm({ ...EMPTY_PROVIDER_FORM });
    setProvError('');
  }

  function openEdit(p) {
    setForm({
      id: p.id, name: p.name, type: p.type, model: p.model,
      api_key: '', base_url: p.base_url,
      use_custom_url: p.use_custom_url, api_version: p.api_version || '',
    });
    setProvError('');
  }

  async function saveForm(e) {
    e.preventDefault();
    setBusy(true);
    setProvError('');
    const isAzure = form.type === 'azure';
    const payload = {
      name: form.name.trim() || TYPE_LABELS[form.type],
      type: form.type,
      model: form.model.trim(),
      api_key: form.api_key,
      base_url: isAzure ? form.base_url.trim() : (form.use_custom_url ? form.base_url.trim() : ''),
      use_custom_url: isAzure ? true : form.use_custom_url,
      api_version: isAzure ? form.api_version.trim() : '',
    };
    try {
      if (form.id) {
        await api(`/api/admin/providers/${form.id}`, { method: 'PUT', body: JSON.stringify(payload) });
      } else {
        await api('/api/admin/providers', { method: 'POST', body: JSON.stringify(payload) });
      }
      setForm(null);
      await refreshProviders();
    } catch (err) {
      setProvError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function activate(id) {
    try {
      await api(`/api/admin/providers/${id}/activate`, { method: 'POST' });
      await refreshProviders();
    } catch (e) {
      setProvError(e.message);
    }
  }

  async function remove(id) {
    if (!window.confirm('確定刪除這個 provider?')) return;
    try {
      await api(`/api/admin/providers/${id}`, { method: 'DELETE' });
      await refreshProviders();
    } catch (e) {
      setProvError(e.message);
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

  // ─── store helpers ───────────────────────────────────────────
  async function loadStores() {
    try {
      const data = await api('/api/admin/stores');
      setStores(data.stores || []);
      setStoreError('');
    } catch (e) {
      setStoreError(e.message);
    }
  }

  function openStoreCreate() {
    setStoreForm({ _isNew: true, name: '', address: '', phone: '', hours: '' });
    setStoreError('');
  }

  function openStoreEdit(s) {
    const sn = s.notes || {};
    setStoreForm({
      _isNew: false,
      name: s.name,
      seating_capacity: sn.seating_capacity ?? 80,
      table_spacing: sn.table_spacing || '一般',
      has_private_room: sn.has_private_room ?? false,
      has_outdoor: sn.has_outdoor ?? false,
      noise_level: sn.noise_level || '一般',
      notes: sn.notes ?? '',
    });
    setStoreError('');
  }

  async function saveStore(e) {
    e.preventDefault();
    setStoreBusy(true);
    setStoreError('');
    try {
      if (storeForm._isNew) {
        await api('/api/admin/stores', {
          method: 'POST',
          body: JSON.stringify({
            name: storeForm.name.trim(),
            address: storeForm.address.trim(),
            phone: storeForm.phone.trim(),
            hours: storeForm.hours.trim(),
          }),
        });
      } else {
        const cap = storeForm.seating_capacity;
        await api(`/api/admin/stores/${encodeURIComponent(storeForm.name)}`, {
          method: 'PUT',
          body: JSON.stringify({
            seating_capacity: cap !== '' && cap !== null ? parseInt(cap, 10) : null,
            table_spacing: storeForm.table_spacing,
            has_private_room: storeForm.has_private_room,
            has_outdoor: storeForm.has_outdoor,
            noise_level: storeForm.noise_level,
            notes: storeForm.notes,
          }),
        });
      }
      setStoreForm(null);
      await loadStores();
    } catch (e) {
      setStoreError(e.message);
    } finally {
      setStoreBusy(false);
    }
  }

  // ─── menu helpers ────────────────────────────────────────────
  async function loadMenu() {
    try {
      const data = await api('/api/admin/menu');
      setMenuItems(data.items || []);
      setMenuError('');
    } catch (e) {
      setMenuError(e.message);
    }
  }

  function openMenuEdit(item) {
    setMenuForm({
      name: item.name,
      category: item.category,
      price: item.price,
      spice_adjustable: item.notes?.spice_adjustable ?? false,
      notes: item.notes?.notes ?? '',
    });
    setMenuError('');
  }

  async function saveMenu(e) {
    e.preventDefault();
    setMenuBusy(true);
    setMenuError('');
    try {
      await api(`/api/admin/menu/${encodeURIComponent(menuForm.name)}`, {
        method: 'PUT',
        body: JSON.stringify({
          spice_adjustable: menuForm.spice_adjustable,
          notes: menuForm.notes,
        }),
      });
      setMenuForm(null);
      await loadMenu();
    } catch (e) {
      setMenuError(e.message);
    } finally {
      setMenuBusy(false);
    }
  }

  // ─── contact helpers ─────────────────────────────────────────
  async function loadContact() {
    try {
      const data = await api('/api/settings/contact');
      setContactPhone(data.phone || '');
      setContactNote(data.note || '');
      setContactError('');
    } catch (e) {
      setContactError(e.message);
    }
  }

  async function saveContact(e) {
    e.preventDefault();
    setContactBusy(true);
    setContactError('');
    setContactSaved(false);
    try {
      await api('/api/admin/settings/contact', {
        method: 'PUT',
        body: JSON.stringify({ phone: contactPhone, note: contactNote }),
      });
      setContactSaved(true);
      setTimeout(() => setContactSaved(false), 3000);
    } catch (e) {
      setContactError(e.message);
    } finally {
      setContactBusy(false);
    }
  }

  // ─── Load data on tab switch ─────────────────────────────────
  useEffect(() => {
    if (!authed) return;
    if (activeTab === 'stores') loadStores();
    if (activeTab === 'menu') loadMenu();
    if (activeTab === 'contact') loadContact();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTab, authed]);

  // ─── 登入畫面 ─────────────────────────────────────────────────
  if (!authed) {
    return (
      <div className="admin-login">
        <form className="admin-login-card" onSubmit={handleLogin}>
          <h1>管理後台</h1>
          <p className="admin-muted">請輸入管理密碼</p>
          <input
            type="password"
            value={loginInput}
            onChange={(e) => setLoginInput(e.target.value)}
            placeholder="ADMIN_TOKEN"
            autoFocus
          />
          {loginError && <div className="admin-error">{loginError}</div>}
          <button type="submit" className="admin-btn admin-btn-primary">登入</button>
        </form>
      </div>
    );
  }

  // ─── 主畫面 ───────────────────────────────────────────────────
  const typeDefault = defaults[form?.type] || {};
  const formIsAzure = form?.type === 'azure';
  const menuCategories = [...new Set(menuItems.map((i) => i.category))];
  const filteredMenu = menuCategory ? menuItems.filter((i) => i.category === menuCategory) : menuItems;

  return (
    <div className="admin">
      <header className="admin-header">
        <div>
          <h1>管理後台</h1>
          <p className="admin-muted">管理 LLM provider、分店特色、菜單備注。</p>
        </div>
        <div className="admin-header-actions">
          <a className="admin-btn" href="/">← 回聊天</a>
          <button className="admin-btn" onClick={logout}>登出</button>
        </div>
      </header>

      {/* ─── Tab 導覽 ─── */}
      <div className="admin-tabs">
        {[
          { key: 'providers', label: 'Provider 設定' },
          { key: 'stores',    label: '分店資訊' },
          { key: 'menu',      label: '菜單備注' },
          { key: 'contact',   label: '聯絡方式' },
        ].map(({ key, label }) => (
          <button
            key={key}
            className={`admin-tab${activeTab === key ? ' is-active' : ''}`}
            onClick={() => setActiveTab(key)}
          >
            {label}
          </button>
        ))}
      </div>

      {/* ══ Provider Tab ══ */}
      {activeTab === 'providers' && (
        <div className="admin-tab-content">
          <p className="admin-muted" style={{ marginBottom: '16px' }}>
            設定多組 LLM provider，選擇其一啟用。切換即時生效，不需重啟。
          </p>
          {provError && <div className="admin-error admin-banner">{provError}</div>}
          <div className="admin-toolbar">
            <button className="admin-btn admin-btn-primary" onClick={openCreate}>+ 新增 provider</button>
          </div>
          <div className="admin-list">
            {providers.length === 0 && (
              <div className="admin-empty">還沒有任何 provider，點「新增 provider」開始。</div>
            )}
            {providers.map((p) => {
              const isActive = p.id === activeId;
              const tr = testResult[p.id];
              const isAzure = p.type === 'azure';
              const urlLabel = isAzure
                ? (p.base_url || '(未填 endpoint)')
                : p.use_custom_url
                  ? p.base_url || '(未填自訂網址)'
                  : `預設${defaults[p.type]?.base_url ? `(${defaults[p.type].base_url})` : ''}`;
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
                      <button className="admin-btn admin-btn-primary" onClick={() => activate(p.id)}>啟用</button>
                    )}
                    <button className="admin-btn" onClick={() => test(p.id)}>測試</button>
                    <button className="admin-btn" onClick={() => openEdit(p)}>編輯</button>
                    <button className="admin-btn admin-btn-danger" onClick={() => remove(p.id)}>刪除</button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* ══ Stores Tab ══ */}
      {activeTab === 'stores' && (
        <div className="admin-tab-content">
          <p className="admin-muted" style={{ marginBottom: '16px' }}>
            設定每家分店的座位數、桌距、包廂等資訊，幫助 AI 回答客人的環境問題。
          </p>
          {storeError && <div className="admin-error admin-banner">{storeError}</div>}
          <div className="admin-toolbar">
            <button className="admin-btn admin-btn-primary" onClick={openStoreCreate}>+ 新增分店</button>
          </div>
          <div className="admin-list">
            {stores.length === 0 && (
              <div className="admin-empty">載入中…</div>
            )}
            {stores.map((s) => {
              const sn = s.notes || {};
              const hasMeta = sn.seating_capacity || sn.table_spacing || sn.has_private_room
                || sn.has_outdoor || sn.noise_level || sn.notes;
              return (
                <div key={s.name} className="admin-card">
                  <div className="admin-card-main">
                    <div className="admin-card-title">
                      <strong>{s.name}</strong>
                      {hasMeta && <span className="admin-badge admin-badge-set">已設定</span>}
                    </div>
                    <p className="admin-muted" style={{ fontSize: 13, margin: '2px 0 6px' }}>{s.address}</p>
                    {hasMeta && (
                      <dl className="admin-meta">
                        {sn.seating_capacity && <div><dt>座位</dt><dd>{sn.seating_capacity} 席</dd></div>}
                        {sn.table_spacing && <div><dt>桌距</dt><dd>{sn.table_spacing}</dd></div>}
                        {sn.has_private_room && <div><dt>包廂</dt><dd>有</dd></div>}
                        {sn.has_outdoor && <div><dt>戶外</dt><dd>有</dd></div>}
                        {sn.noise_level && <div><dt>環境</dt><dd>{sn.noise_level}</dd></div>}
                        {sn.notes && <div><dt>備注</dt><dd>{sn.notes}</dd></div>}
                      </dl>
                    )}
                  </div>
                  <div className="admin-card-actions">
                    <button className="admin-btn" onClick={() => openStoreEdit(s)}>編輯</button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* ══ Menu Tab ══ */}
      {activeTab === 'menu' && (
        <div className="admin-tab-content">
          <p className="admin-muted" style={{ marginBottom: '12px' }}>
            設定每道菜是否可調辣度，以及需要讓 AI 知道的客製化備注（如可去花生、可選配菜）。
          </p>
          {menuError && <div className="admin-error admin-banner">{menuError}</div>}
          <div className="admin-toolbar" style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <select
              className="admin-select"
              value={menuCategory}
              onChange={(e) => setMenuCategory(e.target.value)}
            >
              <option value="">所有分類</option>
              {menuCategories.map((c) => <option key={c} value={c}>{c}</option>)}
            </select>
            <span className="admin-muted" style={{ fontSize: 13 }}>
              {filteredMenu.length} 道 / 共 {menuItems.length} 道
            </span>
          </div>
          <div className="admin-menu-list">
            {filteredMenu.map((item) => {
              const mn = item.notes || {};
              const hasMeta = mn.spice_adjustable || mn.notes;
              return (
                <div key={item.name} className="admin-menu-row">
                  <div className="admin-menu-main">
                    <span className="admin-menu-name">{item.name}</span>
                    <span className="admin-pill">{item.category}</span>
                    {item.price != null && (
                      <span className="admin-muted" style={{ fontSize: 13 }}>${item.price}</span>
                    )}
                    {mn.spice_adjustable && <span className="admin-tag">可調辣</span>}
                    {mn.notes && (
                      <span className="admin-muted" style={{ fontSize: 13 }}>📝 {mn.notes}</span>
                    )}
                  </div>
                  <button className="admin-btn admin-btn-sm" onClick={() => openMenuEdit(item)}>
                    {hasMeta ? '編輯' : '設定'}
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* ─── Provider 表單 modal ─── */}
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
              <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
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

            {provError && <div className="admin-error">{provError}</div>}

            <div className="admin-modal-actions">
              <button type="button" className="admin-btn" onClick={() => setForm(null)} disabled={busy}>取消</button>
              <button type="submit" className="admin-btn admin-btn-primary" disabled={busy}>
                {busy ? '儲存中…' : '儲存'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* ─── 分店 modal ─── */}
      {storeForm && (
        <div className="admin-modal-overlay" onClick={() => !storeBusy && setStoreForm(null)}>
          <form className="admin-modal" onClick={(e) => e.stopPropagation()} onSubmit={saveStore}>
            <h2>{storeForm._isNew ? '新增分店' : storeForm.name}</h2>

            {storeForm._isNew ? (
              <>
                <p className="admin-muted" style={{ marginBottom: '16px', fontSize: 13 }}>
                  新分店建立後可再編輯座位、環境等資訊。
                </p>
                <label className="admin-field">
                  <span>分店名稱 *</span>
                  <input
                    required
                    value={storeForm.name}
                    onChange={(e) => setStoreForm({ ...storeForm, name: e.target.value })}
                    placeholder="如：信義店"
                    autoFocus
                  />
                </label>
                <label className="admin-field">
                  <span>地址</span>
                  <input
                    value={storeForm.address}
                    onChange={(e) => setStoreForm({ ...storeForm, address: e.target.value })}
                    placeholder="如：台北市信義區松高路 12 號"
                  />
                </label>
                <label className="admin-field">
                  <span>電話</span>
                  <input
                    value={storeForm.phone}
                    onChange={(e) => setStoreForm({ ...storeForm, phone: e.target.value })}
                    placeholder="如：02-2345-6789"
                  />
                </label>
                <label className="admin-field">
                  <span>營業時間</span>
                  <input
                    value={storeForm.hours}
                    onChange={(e) => setStoreForm({ ...storeForm, hours: e.target.value })}
                    placeholder="如：每日 11:30–22:00"
                  />
                </label>
              </>
            ) : (
              <>
                <p className="admin-muted" style={{ marginBottom: '16px', fontSize: 13 }}>
                  這些資訊會提供給 AI，讓它能回答客人關於環境和座位的問題。
                </p>
                <label className="admin-field">
                  <span>座位數</span>
                  <input
                    type="text"
                    inputMode="numeric"
                    value={storeForm.seating_capacity}
                    onChange={(e) => {
                      const v = e.target.value.replace(/[^0-9]/g, '');
                      setStoreForm({ ...storeForm, seating_capacity: v });
                    }}
                    placeholder="如：80"
                  />
                </label>
                <label className="admin-field">
                  <span>桌距感受</span>
                  <select
                    value={storeForm.table_spacing}
                    onChange={(e) => setStoreForm({ ...storeForm, table_spacing: e.target.value })}
                  >
                    {SPACING_OPTS.map((o) => <option key={o} value={o}>{o || '（未設定）'}</option>)}
                  </select>
                </label>
                <label className="admin-field">
                  <span>環境氛圍</span>
                  <select
                    value={storeForm.noise_level}
                    onChange={(e) => setStoreForm({ ...storeForm, noise_level: e.target.value })}
                  >
                    {NOISE_OPTS.map((o) => <option key={o} value={o}>{o || '（未設定）'}</option>)}
                  </select>
                </label>
                <div className="admin-field">
                  <span>特色設施</span>
                  <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
                    <label className="admin-checkbox">
                      <input
                        type="checkbox"
                        checked={storeForm.has_private_room}
                        onChange={(e) => setStoreForm({ ...storeForm, has_private_room: e.target.checked })}
                      />
                      <span>有包廂</span>
                    </label>
                    <label className="admin-checkbox">
                      <input
                        type="checkbox"
                        checked={storeForm.has_outdoor}
                        onChange={(e) => setStoreForm({ ...storeForm, has_outdoor: e.target.checked })}
                      />
                      <span>有戶外區</span>
                    </label>
                  </div>
                </div>
                <label className="admin-field">
                  <span>敘述</span>
                  <textarea
                    value={storeForm.notes}
                    onChange={(e) => setStoreForm({ ...storeForm, notes: e.target.value })}
                    placeholder="如：靠近電梯、停車場在 B2、適合包場派對…"
                    rows={3}
                  />
                </label>
              </>
            )}

            {storeError && <div className="admin-error">{storeError}</div>}

            <div className="admin-modal-actions">
              <button type="button" className="admin-btn" onClick={() => setStoreForm(null)} disabled={storeBusy}>取消</button>
              <button type="submit" className="admin-btn admin-btn-primary" disabled={storeBusy}>
                {storeBusy ? '儲存中…' : (storeForm._isNew ? '建立' : '儲存')}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* ─── 菜單備注 modal ─── */}
      {menuForm && (
        <div className="admin-modal-overlay" onClick={() => !menuBusy && setMenuForm(null)}>
          <form className="admin-modal" onClick={(e) => e.stopPropagation()} onSubmit={saveMenu}>
            <h2>{menuForm.name}</h2>
            <p className="admin-muted" style={{ marginBottom: '16px', fontSize: 13 }}>
              {menuForm.category}
              {menuForm.price != null && `　$${menuForm.price}`}
            </p>

            <div className="admin-field">
              <span>辣度調整</span>
              <label className="admin-checkbox">
                <input
                  type="checkbox"
                  checked={menuForm.spice_adjustable}
                  onChange={(e) => setMenuForm({ ...menuForm, spice_adjustable: e.target.checked })}
                />
                <span>客人可要求調整辣度</span>
              </label>
            </div>

            <label className="admin-field">
              <span>客製化備注</span>
              <textarea
                value={menuForm.notes}
                onChange={(e) => setMenuForm({ ...menuForm, notes: e.target.value })}
                placeholder="如：可要求去花生、可選擇配菜種類、可素食版…"
                rows={3}
              />
            </label>

            {menuError && <div className="admin-error">{menuError}</div>}

            <div className="admin-modal-actions">
              <button type="button" className="admin-btn" onClick={() => setMenuForm(null)} disabled={menuBusy}>取消</button>
              <button type="submit" className="admin-btn admin-btn-primary" disabled={menuBusy}>
                {menuBusy ? '儲存中…' : '儲存'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* ══ Contact Tab ══ */}
      {activeTab === 'contact' && (
        <div className="admin-tab-content">
          <p className="admin-muted" style={{ marginBottom: '16px' }}>
            顯示在聊天介面底部的客服聯絡資訊。
          </p>
          <form className="admin-contact-form" onSubmit={saveContact}>
            <div className="admin-field">
              <label>客服電話</label>
              <input
                type="tel"
                value={contactPhone}
                onChange={(e) => { setContactPhone(e.target.value); setContactSaved(false); }}
                placeholder="02-xxxx-xxxx"
              />
            </div>
            <div className="admin-field">
              <label>備注說明</label>
              <input
                type="text"
                value={contactNote}
                onChange={(e) => { setContactNote(e.target.value); setContactSaved(false); }}
                placeholder="例：週一至週五 9:00–18:00"
              />
            </div>
            {contactError && <div className="admin-error">{contactError}</div>}
            {contactSaved && <div className="admin-success">已儲存</div>}
            <div style={{ marginTop: '12px' }}>
              <button type="submit" className="admin-btn admin-btn-primary" disabled={contactBusy}>
                {contactBusy ? '儲存中…' : '儲存'}
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}

export default Admin;
