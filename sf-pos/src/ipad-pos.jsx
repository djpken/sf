import React from 'react';

const { zones, tables: initialTables, menu, modifiers } = window.POS_DATA;
const { statusMeta, fmtMoney, Pill, IconButton, SegmentControl, Stepper, EmptyState } = window.POS_UI;

const NAV_ICONS = {
  overview: ['M4 5h7v7H4z', 'M13 5h7v4h-7z', 'M13 11h7v8h-7z', 'M4 14h7v5H4z'],
  zone: ['M4 11l8-7 8 7', 'M6 10v9h12v-9', 'M10 19v-5h4v5'],
  kitchen: ['M8 14c-1.2-1.4-1.1-3.2.3-4.6', 'M12 15c2-1.8 2.4-4 .8-6', 'M16 14c1.3-1.5 1.2-3.3-.2-4.8', 'M6 18h12', 'M7 21h10'],
  visits: ['M5 5h14v11H8l-3 3z', 'M8 9h8', 'M8 12h5'],
  checkout: ['M6 4h12v16H6z', 'M9 8h6', 'M9 12h6', 'M9 16h3'],
};

const DEVICE_PRESETS = {
  ipadPro11: { label: 'iPad Pro 11"', width: 1194, height: 834, detail: 'Landscape · 11-inch logical viewport' },
  ipadPro129: { label: 'iPad Pro 12.9"', width: 1366, height: 1024, detail: 'Landscape · 12.9-inch logical viewport' },
  ipadMini: { label: 'iPad mini', width: 1133, height: 744, detail: 'Landscape · mini logical viewport' },
  fit: { label: 'Fit to screen', width: 1194, height: 834, detail: 'Scaled preview for small Mac windows' },
};

function IPadPosApp() {
  const [devicePresetKey, setDevicePresetKey] = React.useState('ipadPro11');
  const [panelWidth, setPanelWidth] = React.useState(340);
  const [isPanelOpen, setIsPanelOpen] = React.useState(true);
  const [tables, setTables] = React.useState(initialTables);
  const [selectedTableId, setSelectedTableId] = React.useState('01');
  const [activeView, setActiveView] = React.useState('overview');
  const [workflow, setWorkflow] = React.useState('order');
  const [activeCategory, setActiveCategory] = React.useState('套餐');
  const [partyDraft, setPartyDraft] = React.useState(2);
  const [selectedModifiers, setSelectedModifiers] = React.useState({ doneness: '五分', note: '' });
  const [discount, setDiscount] = React.useState(0);
  const [paymentMethod, setPaymentMethod] = React.useState('信用卡');
  const [orders, setOrders] = React.useState(() => ({
    '01': [createLine(menu[0], { doneness: '五分', note: '醬汁另放', sent: true, served: true }), createLine(menu[6], { sent: true, served: true })],
    '03': [createLine(menu[1], { doneness: '五分', sent: true })],
    '04': [createLine(menu[2], { doneness: '七分', sent: true })],
    '10': [createLine(menu[0], { doneness: '五分', sent: true, served: true }), createLine(menu[4], { sent: true, served: true })],
    '13': [createLine(menu[3], { sent: true, served: true }), createLine(menu[8], { note: '生日牌', sent: true, served: true })],
    '30': [createLine(menu[2], { doneness: '五分', sent: true })],
  }));

  const selectedTable = tables.find((table) => table.id === selectedTableId) || tables[0];
  const currentLines = orders[selectedTable.id] || [];
  const categories = Array.from(new Set(menu.map((item) => item.category)));
  const subtotal = currentLines.reduce((sum, line) => sum + line.price * line.qty, 0);
  const serviceFee = Math.round(subtotal * 0.1);
  const total = Math.max(0, subtotal + serviceFee - discount);
  const stats = getStats(tables);
  const devicePreset = DEVICE_PRESETS[devicePresetKey];
  const deviceStyle = {
    '--ipad-width': `${devicePreset.width}px`,
    '--ipad-height': `${devicePreset.height}px`,
    '--ipad-ratio': `${devicePreset.width} / ${devicePreset.height}`,
    '--ipad-scale-ratio': String(Number((devicePreset.width / devicePreset.height).toFixed(4))),
    '--operation-panel-width': `${panelWidth}px`,
  };

  function selectTable(id, nextWorkflow = 'order', options = {}) {
    const next = tables.find((table) => table.id === id);
    setIsPanelOpen((wasOpen) => options.forceOpen || id !== selectedTableId || !wasOpen);
    setSelectedTableId(id);
    setPartyDraft(next?.party || 2);
    setWorkflow(nextWorkflow);
  }

  function patchTable(tableId, patch) {
    setTables((prev) => prev.map((table) => table.id === tableId ? { ...table, ...patch } : table));
  }

  function startTable() {
    patchTable(selectedTable.id, { status: 'ordering', party: partyDraft, elapsed: 1, overdue: 0 });
    setWorkflow('order');
  }

  function addItem(item) {
    const line = createLine(item, {
      doneness: item.tags.includes('可選熟度') ? selectedModifiers.doneness : '',
      note: selectedModifiers.note,
    });
    setOrders((prev) => ({ ...prev, [selectedTable.id]: [...(prev[selectedTable.id] || []), line] }));
    patchTable(selectedTable.id, { status: 'ordering', party: selectedTable.party || partyDraft, elapsed: selectedTable.elapsed || 1 });
  }

  function updateLine(lineId, patch) {
    setOrders((prev) => ({
      ...prev,
      [selectedTable.id]: currentLines.map((line) => line.id === lineId ? { ...line, ...patch } : line),
    }));
  }

  function removeLine(lineId) {
    setOrders((prev) => ({
      ...prev,
      [selectedTable.id]: currentLines.filter((line) => line.id !== lineId),
    }));
  }

  function sendToKitchen() {
    if (!currentLines.length) return;
    setOrders((prev) => ({
      ...prev,
      [selectedTable.id]: currentLines.map((line) => ({ ...line, sent: true })),
    }));
    patchTable(selectedTable.id, { status: 'cooking', elapsed: Math.max(selectedTable.elapsed, 8) });
    setIsPanelOpen(true);
    setWorkflow('kitchen');
    setActiveView('kitchen');
  }

  function markAllServed() {
    setOrders((prev) => ({
      ...prev,
      [selectedTable.id]: currentLines.map((line) => ({ ...line, sent: true, served: true })),
    }));
    patchTable(selectedTable.id, { status: 'served', elapsed: Math.max(selectedTable.elapsed, 35), overdue: 0 });
    setIsPanelOpen(true);
    setWorkflow('checkout');
  }

  function closeCheck() {
    setOrders((prev) => ({ ...prev, [selectedTable.id]: [] }));
    patchTable(selectedTable.id, { status: 'cleaning', party: 0, elapsed: 0, overdue: 0 });
    window.setTimeout(() => patchTable(selectedTable.id, { status: 'available' }), 900);
    setDiscount(0);
  }

  function openView(view) {
    setActiveView(view);
    if (view === 'kitchen') {
      const next = tables.find((table) => table.status === 'cooking') || selectedTable;
      selectTable(next.id, 'kitchen', { forceOpen: true });
    }
    if (view === 'checkout') {
      const next = tables.find((table) => table.status === 'checkout' || table.status === 'served') || selectedTable;
      selectTable(next.id, 'checkout', { forceOpen: true });
    }
    if (view === 'visits') {
      const next = tables.find((table) => table.status === 'waitingVisit') || selectedTable;
      selectTable(next.id, 'kitchen', { forceOpen: true });
    }
    if (view === 'overview' || view === 'my-zone') {
      setWorkflow('order');
    }
  }

  return (
    <div className={`device-shell ${devicePresetKey === 'fit' ? 'is-fit' : ''}`} style={deviceStyle}>
      <DeviceToolbar selected={devicePresetKey} onSelect={setDevicePresetKey} preset={devicePreset} />
      <div className="ipad-frame">
        <div className="ipad-status">
          <span>9:24 週六</span>
          <span>Wi-Fi　100%</span>
        </div>
        <div className={`pos-screen ${isPanelOpen ? 'has-operation-panel' : 'is-operation-panel-closed'}`}>
          <SideNav activeView={activeView} setActiveView={openView} stats={stats} />
          <main className="floor-board">
            <TopBar stats={stats} />
            <BoardContent activeView={activeView} tables={tables} stats={stats} selectedTableId={selectedTable.id} onSelect={selectTable} />
          </main>
          {isPanelOpen && (
            <OperationPanel
              table={selectedTable}
              lines={currentLines}
              workflow={workflow}
              setWorkflow={setWorkflow}
              categories={categories}
              activeCategory={activeCategory}
              setActiveCategory={setActiveCategory}
              selectedModifiers={selectedModifiers}
              setSelectedModifiers={setSelectedModifiers}
              partyDraft={partyDraft}
              setPartyDraft={setPartyDraft}
              subtotal={subtotal}
              serviceFee={serviceFee}
              total={total}
              discount={discount}
              setDiscount={setDiscount}
              paymentMethod={paymentMethod}
              setPaymentMethod={setPaymentMethod}
              onStart={startTable}
              onAddItem={addItem}
              onQty={(line, qty) => updateLine(line.id, { qty })}
              onRemove={removeLine}
              onSend={sendToKitchen}
              onServe={(id) => updateLine(id, { served: true })}
              onServeAll={markAllServed}
              onCloseCheck={closeCheck}
              onResize={setPanelWidth}
              panelWidth={panelWidth}
            />
          )}
        </div>
      </div>
    </div>
  );
}

function DeviceToolbar({ selected, onSelect, preset }) {
  return (
    <div className="device-toolbar">
      <div>
        <span className="eyebrow">Device Preview</span>
        <strong>{preset.label}</strong>
        <small>{preset.width} × {preset.height} · {preset.detail}</small>
      </div>
      <div className="device-options">
        {Object.entries(DEVICE_PRESETS).map(([key, option]) => (
          <button key={key} type="button" className={selected === key ? 'is-active' : ''} onClick={() => onSelect(key)}>
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function SideNav({ activeView, setActiveView, stats }) {
  const items = [
    { id: 'overview', label: '總覽', icon: 'overview' },
    { id: 'my-zone', label: '我的分區', icon: 'zone' },
    { id: 'kitchen', label: '出菜追蹤', icon: 'kitchen', badge: stats.overdue },
    { id: 'visits', label: '訪桌紀錄', icon: 'visits', badge: stats.waitingVisit },
    { id: 'checkout', label: '結帳', icon: 'checkout' },
  ];

  return (
    <aside className="side-nav">
      <nav>
        {items.map((item) => (
          <button key={item.id} type="button" className={activeView === item.id ? 'is-active' : ''} onClick={() => setActiveView(item.id)}>
            <span className="nav-icon"><SvgIcon name={item.icon} /></span>
            {Boolean(item.badge) && <em>{item.badge}</em>}
            <strong>{item.label}</strong>
          </button>
        ))}
      </nav>
      <div className="staff-chip">
        <div>林</div>
        <span>值班<br />林佳瑩</span>
      </div>
    </aside>
  );
}

function SvgIcon({ name }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      {NAV_ICONS[name].map((path) => (
        <path key={path} d={path} />
      ))}
    </svg>
  );
}

function TopBar({ stats }) {
  return (
    <header className="top-bar">
      <div>
        <span className="eyebrow">Dinner Shift</span>
        <p>05/11（週一） · 22:25</p>
      </div>
      <div className="device-health">
        <Pill tone="success">● 收據機 正常</Pill>
        <Pill tone="success">● 錢箱 已鎖定</Pill>
        <Pill tone={stats.overdue ? 'warning' : 'success'}>● 同步 需確認</Pill>
      </div>
      <div className="shift-metrics">
        <Metric label="班別營收" value="NT$ 212,020" />
        <Metric label="使用中" value={`${stats.active} 桌`} />
        <Metric label="超時" value={`${stats.overdue} 桌`} tone="danger" />
      </div>
    </header>
  );
}

function Kpi({ label, value, detail, warn }) {
  return (
    <div className="kpi-card">
      <span>{label}</span>
      <strong className={warn ? 'warn' : ''}>{value}</strong>
      <small>{detail}</small>
    </div>
  );
}

function BoardContent({ activeView, tables, stats, selectedTableId, onSelect }) {
  if (activeView === 'kitchen') {
    return <KitchenBoard tables={tables} onSelect={(id) => onSelect(id, 'kitchen')} />;
  }
  if (activeView === 'visits') {
    return <VisitBoard tables={tables} onSelect={(id) => onSelect(id, 'kitchen')} />;
  }
  if (activeView === 'checkout') {
    return <CheckoutBoard tables={tables} onSelect={(id) => onSelect(id, 'checkout')} />;
  }

  const visibleZones = activeView === 'my-zone' ? zones.filter((zone) => zone.id === 'main') : zones;
  const title = activeView === 'my-zone' ? '我的分區' : '全餐廳狀況';
  const subtitle = activeView === 'my-zone' ? '主廳 · 服務員視角' : '下午10:25 · 晚餐時段';

  return (
    <div className="board-scroll">
      <section className="overview-panel">
        <div className="manager-copy">
          <span className="eyebrow">{activeView === 'my-zone' ? 'Server · 分區工作台' : 'Manager · 值班總覽'}</span>
          <h1>{title}</h1>
          <p>{subtitle}</p>
        </div>
        <div className="kpi-grid">
          <Kpi label="入座率" value={`${stats.occupancy}%`} detail={`${stats.active}/${tables.length} 桌`} />
          <Kpi label="製作中" value={stats.cooking} detail={`${stats.cookingLines} 道菜`} />
          <Kpi label="待訪桌" value={stats.waitingVisit} detail="需關心" warn />
          <Kpi label="今日營收" value="61K" detail="NT$ 61,420" />
        </div>
      </section>
      <AlertPanel tables={tables} onSelect={(id) => onSelect(id, 'kitchen')} />
      {visibleZones.map((zone) => (
        <ZoneSection key={zone.id} zone={zone} tables={tables.filter((table) => table.zone === zone.id)} selectedTableId={selectedTableId} onSelect={onSelect} />
      ))}
    </div>
  );
}

function KitchenBoard({ tables, onSelect }) {
  const cookingTables = tables.filter((table) => table.status === 'cooking');

  return (
    <div className="focus-board">
      <BoardHero eyebrow="Kitchen · 出餐節奏" title="出菜追蹤看板" detail="依超時、桌號與品項狀態排序，點擊任一桌會同步右側出餐操作。" />
      <div className="queue-grid">
        {cookingTables.map((table) => (
          <button key={table.id} type="button" className={`queue-card ${table.overdue ? 'is-danger' : ''}`} onClick={() => onSelect(table.id)}>
            <div><strong>{table.id}</strong><Pill tone={table.overdue ? 'danger' : 'warning'}>{table.overdue ? `超時 ${table.overdue} 分` : '製作中'}</Pill></div>
            <span>{zoneName(table.zone)} · {table.party}/{table.seats} 位 · 已等 {table.elapsed} 分</span>
            <em>{table.overdue ? '優先催單與補償確認' : '廚房排程正常'}</em>
          </button>
        ))}
      </div>
    </div>
  );
}

function VisitBoard({ tables, onSelect }) {
  const visitTables = tables.filter((table) => table.status === 'waitingVisit');

  return (
    <div className="focus-board">
      <BoardHero eyebrow="Hospitality · 桌邊服務" title="訪桌紀錄" detail="已上餐後需要回訪的桌次，追蹤口味、客訴、生日或加點機會。" />
      <div className="queue-grid">
        {visitTables.map((table) => (
          <button key={table.id} type="button" className="queue-card is-visit" onClick={() => onSelect(table.id)}>
            <div><strong>{table.id}</strong><Pill tone="visit">待訪桌</Pill></div>
            <span>{zoneName(table.zone)} · 上餐後 {table.elapsed} 分</span>
            <em>確認餐點溫度、熟度與是否需要追加飲品</em>
          </button>
        ))}
      </div>
    </div>
  );
}

function CheckoutBoard({ tables, onSelect }) {
  const checkoutTables = tables.filter((table) => table.status === 'checkout' || table.status === 'served');

  return (
    <div className="focus-board">
      <BoardHero eyebrow="Payment · 收銀流程" title="結帳佇列" detail="結帳中與已上齊桌次集中處理，右側支援信用卡、分帳與清桌流程。" />
      <div className="queue-grid">
        {checkoutTables.map((table) => (
          <button key={table.id} type="button" className="queue-card is-checkout" onClick={() => onSelect(table.id)}>
            <div><strong>{table.id}</strong><Pill tone={table.status === 'checkout' ? 'checkout' : 'success'}>{statusMeta[table.status].label}</Pill></div>
            <span>{zoneName(table.zone)} · {table.party}/{table.seats} 位 · {fmtMoney(estimateTotal(table.id))}</span>
            <em>套用折扣、確認服務費、完成收款並清桌</em>
          </button>
        ))}
      </div>
    </div>
  );
}

function BoardHero({ eyebrow, title, detail }) {
  return (
    <section className="board-hero">
      <span className="eyebrow">{eyebrow}</span>
      <h1>{title}</h1>
      <p>{detail}</p>
    </section>
  );
}

function AlertPanel({ tables, onSelect }) {
  const overdueTables = tables.filter((table) => table.overdue);

  return (
    <section className="alert-panel">
      <div className="alert-title">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4l9 16H3z" /><path d="M12 9v5" /><path d="M12 17h.01" /></svg>
        出菜警示 · 上限 25 分鐘
      </div>
      {overdueTables.map((table) => (
        <button key={table.id} type="button" onClick={() => onSelect(table.id)}>
          <strong>{table.id}</strong>
          <span>{zoneName(table.zone)}　1 道未上</span>
          <em>已超時 {table.overdue} 分</em>
        </button>
      ))}
    </section>
  );
}

function ZoneSection({ zone, tables, selectedTableId, onSelect }) {
  const active = tables.filter((table) => table.status !== 'available').length;
  const cooking = tables.filter((table) => table.status === 'cooking').length;
  const overdue = tables.filter((table) => table.overdue).length;

  return (
    <section className="zone-section">
      <div className="zone-header">
        <div><span>{zone.mark}</span><strong>{zone.label}</strong><small>{active}/{tables.length} 使用中</small></div>
        <div><Pill tone="warning">{cooking} 製作中</Pill><Pill tone="danger">{overdue} 超時</Pill></div>
      </div>
      <div className="table-grid">
        {tables.map((table) => <TableCard key={table.id} table={table} selected={selectedTableId === table.id} onClick={() => onSelect(table.id)} />)}
      </div>
    </section>
  );
}

function TableCard({ table, selected, onClick }) {
  const meta = statusMeta[table.status];
  const total = table.status === 'available' ? 0 : estimateTotal(table.id);

  return (
    <button type="button" className={`floor-table ${meta.tone} ${selected ? 'is-selected' : ''}`} onClick={onClick}>
      <div className="table-card-head">
        <strong>{table.id}</strong>
        <span>{table.party ? `${table.party}/${table.seats}` : `${table.seats}席`}</span>
      </div>
      <Pill tone={meta.tone}>{meta.label}</Pill>
      {table.status !== 'available' && (
        <div className="table-card-detail">
          {table.overdue ? <em>逾時 +{String(table.overdue).padStart(2, '0')}:00</em> : <span>{table.elapsed}:00</span>}
          {total > 0 && <strong>{fmtMoney(total)}</strong>}
        </div>
      )}
    </button>
  );
}

function OperationPanel(props) {
  const { table, lines, workflow, setWorkflow, subtotal, serviceFee, total } = props;
  const meta = statusMeta[table.status];
  const nextAction = getNextAction(table, lines);
  const sentCount = lines.filter((line) => line.sent).length;
  const servedCount = lines.filter((line) => line.served).length;

  function startResize(event) {
    event.preventDefault();
    const startX = event.clientX;
    const startWidth = props.panelWidth;

    function movePanel(moveEvent) {
      const nextWidth = Math.min(460, Math.max(280, startWidth + startX - moveEvent.clientX));
      props.onResize(nextWidth);
    }

    function stopResize() {
      window.removeEventListener('pointermove', movePanel);
      window.removeEventListener('pointerup', stopResize);
    }

    window.addEventListener('pointermove', movePanel);
    window.addEventListener('pointerup', stopResize, { once: true });
  }

  return (
    <aside className="operation-panel">
      <button className="panel-resize-handle" type="button" aria-label="調整操作面板寬度" onPointerDown={startResize} />
      <div className="operation-head">
        <div>
        <span className="eyebrow">iPad POS Flow · 低消 NT$200</span>
          <h2>{table.id} 桌</h2>
        </div>
        <Pill tone={meta.tone}>{meta.label}</Pill>
      </div>
      <div className={`next-action ${nextAction.tone}`}>
        <span>下一步建議</span>
        <strong>{nextAction.label}</strong>
      </div>
      <div className="table-snapshot" aria-label="桌況摘要">
        <span>{lines.length} 品項</span>
        <span>{sentCount} 已送廚</span>
        <span>{servedCount} 已上餐</span>
      </div>
      <div className="guest-row">
        <span>{zoneName(table.zone)} · {table.seats} 席 · {table.party || props.partyDraft} 位</span>
        <Stepper value={props.partyDraft} min={1} max={table.seats} onChange={props.setPartyDraft} />
        <button className="primary-button" type="button" disabled={table.status !== 'available' && table.status !== 'seated'} onClick={props.onStart}>開桌</button>
      </div>
      <SegmentControl
        value={workflow}
        onChange={setWorkflow}
        options={[
          { value: 'order', label: '點餐' },
          { value: 'kitchen', label: '出餐' },
          { value: 'checkout', label: '結帳' },
        ]}
      />
      {workflow === 'order' && <OrderPane {...props} />}
      {workflow === 'kitchen' && <KitchenPane lines={lines} onServe={props.onServe} onServeAll={props.onServeAll} />}
      {workflow === 'checkout' && <CheckoutPane {...props} />}
      <Ticket lines={lines} workflow={workflow} subtotal={subtotal} serviceFee={serviceFee} total={total} onQty={props.onQty} onRemove={props.onRemove} onSend={props.onSend} setWorkflow={setWorkflow} />
    </aside>
  );
}

function OrderPane({ categories, activeCategory, setActiveCategory, selectedModifiers, setSelectedModifiers, onAddItem }) {
  const visibleMenu = menu.filter((item) => item.category === activeCategory);

  return (
    <section className="flow-pane">
      <div className="category-strip">
        {categories.map((category) => <button key={category} type="button" className={category === activeCategory ? 'is-active' : ''} onClick={() => setActiveCategory(category)}>{category}</button>)}
      </div>
      <div className="choice-row">
        {modifiers.doneness.map((value) => <button key={value} type="button" className={selectedModifiers.doneness === value ? 'is-active' : ''} onClick={() => setSelectedModifiers((prev) => ({ ...prev, doneness: value }))}>{value}</button>)}
      </div>
      <div className="choice-row">
        {modifiers.notes.map((value) => <button key={value} type="button" className={selectedModifiers.note === value ? 'is-active' : ''} onClick={() => setSelectedModifiers((prev) => ({ ...prev, note: prev.note === value ? '' : value }))}>{value}</button>)}
      </div>
      <div className="menu-list">
        {visibleMenu.map((item) => (
          <button key={item.id} type="button" onClick={() => onAddItem(item)}>
            <strong>{item.name}</strong>
            <span>{item.subtitle}</span>
            <em>{fmtMoney(item.price)}</em>
          </button>
        ))}
      </div>
    </section>
  );
}

function KitchenPane({ lines, onServe, onServeAll }) {
  const sentLines = lines.filter((line) => line.sent);
  if (!sentLines.length) return <EmptyState title="尚未送廚房" detail="點餐完成後送單，這裡會顯示出餐進度。" />;
  return (
    <section className="flow-pane kitchen-pane">
      <button className="primary-button" type="button" onClick={onServeAll}>全部上餐</button>
      {sentLines.map((line) => (
        <div key={line.id} className="kitchen-item">
          <div><strong>{line.name}</strong><span>{line.qty} 份 · {line.doneness || '一般'} {line.note}</span></div>
          <button className="secondary-button" type="button" disabled={line.served} onClick={() => onServe(line.id)}>{line.served ? '已上餐' : '標記上餐'}</button>
        </div>
      ))}
    </section>
  );
}

function CheckoutPane({ subtotal, serviceFee, discount, setDiscount, total, paymentMethod, setPaymentMethod, onCloseCheck }) {
  return (
    <section className="flow-pane checkout-pane">
      <SummaryRow label="餐點小計" value={fmtMoney(subtotal)} />
      <SummaryRow label="服務費 10%" value={fmtMoney(serviceFee)} />
      <label className="discount-field"><span>折扣</span><input value={discount} inputMode="numeric" onChange={(event) => setDiscount(Number(event.target.value || 0))} /></label>
      <div className="total-row"><span>應收金額</span><strong>{fmtMoney(total)}</strong></div>
      <p className="checkout-note">收款後列印明細，必要時拆分付款或開立載具。</p>
      <div className="payment-grid">
        {['信用卡', '現金', 'LINE Pay', '分帳'].map((label) => (
          <button key={label} type="button" className={paymentMethod === label ? 'is-active' : ''} onClick={() => setPaymentMethod(label)}>{label}</button>
        ))}
      </div>
      <button className="pay-button" type="button" onClick={onCloseCheck}>完成結帳並清桌</button>
    </section>
  );
}

function Ticket({ lines, workflow, subtotal, serviceFee, total, onQty, onRemove, onSend, setWorkflow }) {
  const showActions = workflow !== 'checkout';
  const showTotals = workflow !== 'checkout';

  return (
    <section className="ticket">
      <div className="ticket-title"><strong>目前桌單</strong><span>{lines.length} 項</span></div>
      <div className="ticket-lines">
        {!lines.length && <EmptyState title="尚無品項" detail="選擇菜色後會加入桌單。" />}
        {lines.map((line) => (
          <div key={line.id} className="ticket-line">
            <div><strong>{line.name}</strong><span>{line.doneness || '一般'} {line.note ? `· ${line.note}` : ''}</span></div>
            <Pill tone={line.served ? 'success' : line.sent ? 'warning' : 'active'}>{lineStatusLabel(line)}</Pill>
            <Stepper value={line.qty} min={1} onChange={(qty) => onQty(line, qty)} />
            <strong>{fmtMoney(line.price * line.qty)}</strong>
            <IconButton label="移除品項" onClick={() => onRemove(line.id)}>×</IconButton>
          </div>
        ))}
      </div>
      {showTotals && (
        <div className="ticket-total">
          <SummaryRow label="小計" value={fmtMoney(subtotal)} />
          <SummaryRow label="服務費" value={fmtMoney(serviceFee)} />
          <SummaryRow label="合計" value={fmtMoney(total)} strong />
        </div>
      )}
      {showActions && (
        <div className="ticket-actions">
          <button className="secondary-button" type="button" disabled={!lines.length} onClick={onSend}>送單到廚房</button>
          <button className="primary-button" type="button" disabled={!lines.length} onClick={() => setWorkflow('checkout')}>前往結帳</button>
        </div>
      )}
    </section>
  );
}

function Metric({ label, value, tone = '' }) {
  return <div className={`metric ${tone}`}><span>{label}</span><strong>{value}</strong></div>;
}

function SummaryRow({ label, value, strong }) {
  return <div className={`summary-row ${strong ? 'is-strong' : ''}`}><span>{label}</span><strong>{value}</strong></div>;
}

function getStats(tables) {
  const active = tables.filter((table) => table.status !== 'available').length;
  const cooking = tables.filter((table) => table.status === 'cooking').length;
  const overdue = tables.filter((table) => table.overdue).length;
  const waitingVisit = tables.filter((table) => table.status === 'waitingVisit').length;
  return {
    active,
    cooking,
    overdue,
    waitingVisit,
    cookingLines: cooking + 4,
    occupancy: Math.round((active / tables.length) * 100),
  };
}

function createLine(item, options = {}) {
  return {
    id: `${item.id}-${Math.random().toString(16).slice(2)}`,
    menuId: item.id,
    name: item.name,
    price: item.price,
    qty: 1,
    doneness: options.doneness || '',
    note: options.note || '',
    sent: Boolean(options.sent),
    served: Boolean(options.served),
  };
}

function getNextAction(table, lines) {
  const hasUnsent = lines.some((line) => !line.sent);
  const hasCooking = lines.some((line) => line.sent && !line.served);
  if (table.status === 'available') return { label: '確認人數後開桌', tone: 'neutral' };
  if (hasUnsent || table.status === 'ordering') return { label: '確認備註並送單', tone: 'order' };
  if (hasCooking || table.status === 'cooking') return { label: table.overdue ? '優先催單並回報客人' : '追蹤出餐進度', tone: table.overdue ? 'danger' : 'kitchen' };
  if (table.status === 'served' || table.status === 'waitingVisit') return { label: '追蹤回訪或帶往結帳', tone: 'serve' };
  if (table.status === 'checkout') return { label: '確認付款與發票', tone: 'checkout' };
  if (table.status === 'cleaning') return { label: '完成清潔後釋出桌位', tone: 'neutral' };
  return { label: '查看桌況並安排下一步', tone: 'neutral' };
}

function lineStatusLabel(line) {
  if (line.served) return '已上餐';
  if (line.sent) return '製作中';
  return '未送廚';
}

function estimateTotal(id) {
  return (Number(id) % 5 + 1) * 740;
}

function zoneName(zoneId) {
  return zones.find((zone) => zone.id === zoneId)?.label || zoneId;
}

window.IPadPosApp = IPadPosApp;
