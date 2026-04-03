import React, { useMemo, useEffect, useCallback } from 'react';
import HangmanSVG from './HangmanSVG';
import './GameBoard.css';

const ALPHABET = 'abcdefghijklmnopqrstuvwxyz'.split('');

export default function GameBoard({ gameState, onGuess }) {
  const {
    revealed_word = [],
    guessed_letters = [],
    wrong_letters = [],
    wrong_count = 0,
    max_errors = 6,
    is_my_turn = false,
    message = '',
    opponent_id,
  } = gameState;

  const allTried = useMemo(
    () => new Set([...guessed_letters, ...wrong_letters]),
    [guessed_letters, wrong_letters]
  );

  const handleGuess = useCallback((letter) => {
    if (!is_my_turn) return;
    if (allTried.has(letter)) return;
    onGuess(letter);
  }, [is_my_turn, allTried, onGuess]);

  useEffect(() => {
    const handler = (e) => {
      const key = e.key.toLowerCase();
      if (/^[a-z]$/.test(key)) handleGuess(key);
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [handleGuess]);

  const errorsLeft = max_errors - wrong_count;
  const progressPct = (wrong_count / max_errors) * 100;

  return (
    <div className="game-board">
      {/* Status banner */}
      <div className={`status-banner ${is_my_turn ? 'status-banner--myturn' : 'status-banner--wait'}`}>
        <span className="status-icon">{is_my_turn ? '🎯' : '⏳'}</span>
        <span>{message}</span>
      </div>

      <div className="game-grid">
        {/* Left: Hangman */}
        <div className="game-panel game-panel--left">
          <div className="hangman-wrap">
            <HangmanSVG wrongCount={wrong_count} />
          </div>
          <div className="error-tracker">
            <div className="error-bar-wrap">
              <div
                className="error-bar"
                style={{ width: `${progressPct}%`, background: progressPct > 66 ? '#e74c3c' : progressPct > 33 ? '#f39c12' : '#2ecc71' }}
              />
            </div>
            <p className="error-label">
              {wrong_count} / {max_errors} erros &nbsp;·&nbsp; {errorsLeft} restante{errorsLeft !== 1 ? 's' : ''}
            </p>
          </div>
          {opponent_id && (
            <div className="opponent-info">
              <span className="opp-label">Adversário</span>
              <code className="opp-id">{opponent_id.slice(0, 14)}…</code>
            </div>
          )}
        </div>

        {/* Right: Word + Keyboard */}
        <div className="game-panel game-panel--right">
          {/* Word display */}
          <div className="word-display">
            {revealed_word.map((char, i) => (
              <span
                key={i}
                className={`letter-tile ${char !== '_' ? 'letter-tile--revealed' : ''}`}
              >
                {char !== '_' ? char.toUpperCase() : ''}
              </span>
            ))}
          </div>

          <p className="word-hint">{revealed_word.length} letras</p>

          {/* Wrong letters */}
          {wrong_letters.length > 0 && (
            <div className="wrong-letters">
              <span className="wrong-title">Erradas:</span>
              {wrong_letters.map(l => (
                <span key={l} className="wrong-chip">{l.toUpperCase()}</span>
              ))}
            </div>
          )}

          {/* Keyboard */}
          <div className="keyboard">
            {ALPHABET.map(letter => {
              const isCorrect = guessed_letters.includes(letter);
              const isWrong = wrong_letters.includes(letter);
              const disabled = !is_my_turn || isCorrect || isWrong;

              return (
                <button
                  key={letter}
                  className={`key-btn ${isCorrect ? 'key-btn--correct' : ''} ${isWrong ? 'key-btn--wrong' : ''} ${!is_my_turn ? 'key-btn--disabled' : ''}`}
                  onClick={() => handleGuess(letter)}
                  disabled={disabled}
                  title={letter.toUpperCase()}
                >
                  {letter.toUpperCase()}
                </button>
              );
            })}
          </div>
          <p className="keyboard-hint">Você pode usar o teclado físico</p>
        </div>
      </div>
    </div>
  );
}
