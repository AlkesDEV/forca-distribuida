import React from 'react';
import HangmanSVG from './HangmanSVG';
import './ResultScreen.css';

export default function ResultScreen({ gameState, onPlayAgain }) {
  const {
    status,
    winner_id,
    player_id,
    revealed_word = [],
    wrong_letters = [],
    wrong_count = 0,
    message = '',
  } = gameState;

  const isWinner = winner_id === player_id;
  const word = revealed_word.join('').toUpperCase();

  const emoji = status === 'abandoned' ? '🏆' : isWinner ? '🎉' : '💀';
  const title = status === 'abandoned'
    ? 'Adversário abandonou!'
    : isWinner
    ? 'Você venceu!'
    : 'Você perdeu!';

  return (
    <div className="result-screen">
      <div className={`result-card result-card--${isWinner || status === 'abandoned' ? 'win' : 'loss'}`}>
        <div className="result-emoji">{emoji}</div>
        <h2 className="result-title">{title}</h2>
        <p className="result-message">{message}</p>

        <div className="result-word-wrap">
          <p className="result-word-label">A palavra era:</p>
          <p className="result-word">{word || '???'}</p>
        </div>

        <div className="result-stats">
          <div className="stat">
            <span className="stat-value">{wrong_count}</span>
            <span className="stat-label">Erros</span>
          </div>
          <div className="stat">
            <span className="stat-value">{6 - wrong_count}</span>
            <span className="stat-label">Vidas restantes</span>
          </div>
          <div className="stat">
            <span className="stat-value">{wrong_letters.length}</span>
            <span className="stat-label">Letras erradas</span>
          </div>
        </div>

        <div className="result-hangman">
          <HangmanSVG wrongCount={wrong_count} />
        </div>

        <button className="play-again-btn" onClick={onPlayAgain}>
          🔄 Jogar Novamente
        </button>
      </div>
    </div>
  );
}
