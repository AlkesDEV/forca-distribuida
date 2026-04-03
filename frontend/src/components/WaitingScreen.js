import React from 'react';
import './WaitingScreen.css';

export default function WaitingScreen({ message, playerId }) {
  return (
    <div className="waiting-screen">
      <div className="waiting-card">
        <div className="waiting-animation">
          <div className="spinner-ring" />
          <span className="waiting-icon">⏳</span>
        </div>
        <h2 className="waiting-title">Jogo da Forca</h2>
        <p className="waiting-message">{message || 'Carregando...'}</p>
        {playerId && (
          <div className="player-badge">
            <span className="badge-label">Seu ID</span>
            <code className="badge-value">{playerId.slice(0, 16)}…</code>
          </div>
        )}
        <div className="waiting-dots">
          <span /><span /><span />
        </div>
      </div>
    </div>
  );
}
