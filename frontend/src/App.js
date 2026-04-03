import React, { useState, useEffect, useRef, useCallback } from 'react';
import GameBoard from './components/GameBoard';
import WaitingScreen from './components/WaitingScreen';
import ResultScreen from './components/ResultScreen';
import ConnectionStatus from './components/ConnectionStatus';
import './App.css';

const CABLE_URL = import.meta.env.VITE_CABLE_URL || `ws://${window.location.hostname}/cable`;
const RECONNECT_TIMEOUT_MS = 30000;

function generatePlayerId() {
  const stored = localStorage.getItem('forca_player_id');
  if (stored) return stored;
  const id = 'p-' + Math.random().toString(36).substr(2, 9) + '-' + Date.now();
  localStorage.setItem('forca_player_id', id);
  return id;
}

export default function App() {
  const [playerId] = useState(generatePlayerId);
  const [gameState, setGameState] = useState(null);
  const [connectionStatus, setConnectionStatus] = useState('connecting');
  const [reconnectCountdown, setReconnectCountdown] = useState(null);

  const wsRef = useRef(null);
  const reconnectTimerRef = useRef(null);
  const countdownIntervalRef = useRef(null);
  const reconnectStartRef = useRef(null);
  const intentionalClose = useRef(false);

  const clearTimers = useCallback(() => {
    clearTimeout(reconnectTimerRef.current);
    clearInterval(countdownIntervalRef.current);
  }, []);

  const connect = useCallback(() => {
    intentionalClose.current = false;
    const url = `${CABLE_URL}?player_id=${encodeURIComponent(playerId)}`;
    const ws = new WebSocket(url);
    wsRef.current = ws;
    setConnectionStatus('connecting');

    ws.onopen = () => {
      setConnectionStatus('connected');
      clearTimers();
      setReconnectCountdown(null);
      reconnectStartRef.current = null;

      const subscribeMsg = JSON.stringify({
        command: 'subscribe',
        identifier: JSON.stringify({ channel: 'GameChannel' }),
      });
      ws.send(subscribeMsg);
    };

    ws.onmessage = (event) => {
      const raw = JSON.parse(event.data);
      if (raw.type === 'ping' || raw.type === 'welcome' || raw.type === 'confirm_subscription') return;
      if (raw.message) {
        const msg = raw.message;
        if (msg.type === 'waiting') {
          setGameState({ status: 'waiting', player_id: playerId, message: msg.message });
        } else if (msg.type === 'game_state') {
          setGameState(msg);
        } else if (msg.type === 'error') {
          console.warn('[WS] Error from server:', msg.message);
        }
      }
    };

    ws.onerror = () => {
      setConnectionStatus('error');
    };

    ws.onclose = () => {
      if (intentionalClose.current) return;
      setConnectionStatus('reconnecting');

      if (!reconnectStartRef.current) {
        reconnectStartRef.current = Date.now();
      }

      const elapsed = Date.now() - reconnectStartRef.current;
      const remaining = RECONNECT_TIMEOUT_MS - elapsed;

      if (remaining <= 0) {
        setConnectionStatus('failed');
        setReconnectCountdown(0);
        setGameState(prev => prev ? { ...prev, status: 'abandoned', message: 'Conexão perdida. Adversário venceu automaticamente.' } : prev);
        return;
      }

      let countdown = Math.ceil(remaining / 1000);
      setReconnectCountdown(countdown);

      countdownIntervalRef.current = setInterval(() => {
        countdown -= 1;
        setReconnectCountdown(countdown);
        if (countdown <= 0) clearInterval(countdownIntervalRef.current);
      }, 1000);

      reconnectTimerRef.current = setTimeout(() => {
        clearInterval(countdownIntervalRef.current);
        connect();
      }, Math.min(3000, remaining));
    };
  }, [playerId, clearTimers]);

  useEffect(() => {
    connect();
    return () => {
      intentionalClose.current = true;
      clearTimers();
      wsRef.current?.close();
    };
  }, [connect, clearTimers]);

  const sendGuess = useCallback((letter) => {
    if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return;
    const msg = JSON.stringify({
      command: 'message',
      identifier: JSON.stringify({ channel: 'GameChannel' }),
      data: JSON.stringify({ action: 'guess_letter', letter }),
    });
    wsRef.current.send(msg);
  }, []);

  const resetGame = useCallback(() => {
    intentionalClose.current = true;
    wsRef.current?.close();
    clearTimers();
    setGameState(null);
    reconnectStartRef.current = null;
    setTimeout(() => connect(), 200);
  }, [connect, clearTimers]);

  const isFinished = gameState && ['won', 'lost', 'abandoned'].includes(gameState.status);

  return (
    <div className="app">
      <header className="app-header">
        <h1 className="app-title">
          <span className="title-icon">⚖️</span>
          Forca Distribuída
        </h1>
        <ConnectionStatus status={connectionStatus} countdown={reconnectCountdown} />
      </header>

      <main className="app-main">
        {!gameState && (
          <WaitingScreen message="Conectando ao servidor..." />
        )}
        {gameState?.status === 'waiting' && (
          <WaitingScreen message={gameState.message} playerId={playerId} />
        )}
        {gameState && !isFinished && gameState.status !== 'waiting' && (
          <GameBoard gameState={gameState} onGuess={sendGuess} />
        )}
        {isFinished && (
          <ResultScreen gameState={gameState} onPlayAgain={resetGame} />
        )}
      </main>
    </div>
  );
}
