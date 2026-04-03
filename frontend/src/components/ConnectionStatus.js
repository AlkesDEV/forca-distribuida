import React from 'react';
import './ConnectionStatus.css';

const STATUS_CONFIG = {
  connecting:   { color: '#f39c12', label: 'Conectando...', dot: 'pulse' },
  connected:    { color: '#2ecc71', label: 'Conectado',     dot: 'solid' },
  reconnecting: { color: '#e67e22', label: 'Reconectando',  dot: 'pulse' },
  error:        { color: '#e74c3c', label: 'Erro',          dot: 'solid' },
  failed:       { color: '#e74c3c', label: 'Desconectado',  dot: 'solid' },
};

export default function ConnectionStatus({ status, countdown }) {
  const cfg = STATUS_CONFIG[status] || STATUS_CONFIG.connecting;

  return (
    <div className="conn-status">
      <span
        className={`conn-dot conn-dot--${cfg.dot}`}
        style={{ background: cfg.color }}
      />
      <span className="conn-label" style={{ color: cfg.color }}>
        {cfg.label}
        {status === 'reconnecting' && countdown != null && ` (${countdown}s)`}
      </span>
    </div>
  );
}
