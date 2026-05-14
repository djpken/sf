import React from 'react';

const statusMeta = {
  available: { label: '空桌', tone: 'empty' },
  seated: { label: '入座', tone: 'seated' },
  ordering: { label: '點餐中', tone: 'active' },
  cooking: { label: '製作中', tone: 'warning' },
  served: { label: '已上齊', tone: 'success' },
  waitingVisit: { label: '待訪桌', tone: 'visit' },
  checkout: { label: '結帳中', tone: 'checkout' },
  cleaning: { label: '清潔中', tone: 'cleaning' },
};

function fmtMoney(value) {
  return `NT$ ${value.toLocaleString('en-US')}`;
}

function Pill({ tone = 'muted', children }) {
  return <span className={`pill pill-${tone}`}>{children}</span>;
}

function IconButton({ label, children, onClick, active, disabled }) {
  return (
    <button
      className={`icon-button ${active ? 'is-active' : ''}`}
      type="button"
      onClick={onClick}
      disabled={disabled}
      title={label}
      aria-label={label}
    >
      {children}
    </button>
  );
}

function SegmentControl({ value, options, onChange }) {
  return (
    <div className="segment-control" role="tablist">
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          className={value === option.value ? 'is-active' : ''}
          onClick={() => onChange(option.value)}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}

function Stepper({ value, min = 0, max = 99, onChange }) {
  return (
    <div className="stepper">
      <IconButton label="減少" disabled={value <= min} onClick={() => onChange(Math.max(min, value - 1))}>-</IconButton>
      <strong>{value}</strong>
      <IconButton label="增加" disabled={value >= max} onClick={() => onChange(Math.min(max, value + 1))}>+</IconButton>
    </div>
  );
}

function EmptyState({ title, detail }) {
  return (
    <div className="empty-state">
      <strong>{title}</strong>
      <span>{detail}</span>
    </div>
  );
}

window.POS_UI = {
  statusMeta,
  fmtMoney,
  Pill,
  IconButton,
  SegmentControl,
  Stepper,
  EmptyState,
};
