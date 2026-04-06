import React from 'react';
import './ConnectionStatus.css';

const STATUS_CONFIG = {
  connecting:   { color: '#f39c12', label: 'Conectando...', dot: 'pulse' },
  connected:    { color: '#2ecc71', label: 'Conectado',     dot: 'solid' },
  reconnecting: { color: '#e67e22', label: 'Reconectando',  dot: 'pulse' },
  error:        { color: '#e74c3c', label: 'Erro',          dot: 'solid' },
  failed:       { color: '#e74c3c', label: 'Desconectado',  dot: 'solid' },
};

export default function ConnectionStatus({ status, countdown, latencyMs, connectionHealth }) {
  const cfg = STATUS_CONFIG[status] || STATUS_CONFIG.connecting;

  const healthLabel = {
    boa: 'Boa',
    media: 'Média',
    ruim: 'Ruim',
    instavel: 'Conexão instável',
  }[connectionHealth] || 'Conexão instável';

  return (
    <div className="conn-status">
      <div className="conn-status__main">
        <span
          className={`conn-dot conn-dot--${cfg.dot}`}
          style={{ background: cfg.color }}
        />
        <span className="conn-label" style={{ color: cfg.color }}>
          {cfg.label}
          {status === 'reconnecting' && countdown != null && ` (${countdown}s)`}
        </span>
      </div>

      <div className="conn-metrics">
        <span className="conn-metric">
          Latência: {latencyMs != null ? `${latencyMs} ms` : '...'}
        </span>
        <span className={`conn-metric conn-metric--${connectionHealth || 'instavel'}`}>
          {healthLabel}
        </span>
      </div>
    </div>
  );
}