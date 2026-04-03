import React from 'react';

export default function HangmanSVG({ wrongCount }) {
  const stroke = '#e94560';
  const strokeW = 3;
  const gallows = '#a0a0b0';
  const gallowsW = 4;

  return (
    <svg
      viewBox="0 0 200 220"
      xmlns="http://www.w3.org/2000/svg"
      style={{ width: '100%', maxWidth: 220, display: 'block', margin: '0 auto' }}
    >
      {/* Gallows */}
      <line x1="20" y1="210" x2="180" y2="210" stroke={gallows} strokeWidth={gallowsW} strokeLinecap="round" />
      <line x1="60" y1="210" x2="60" y2="20"  stroke={gallows} strokeWidth={gallowsW} strokeLinecap="round" />
      <line x1="60" y1="20"  x2="130" y2="20"  stroke={gallows} strokeWidth={gallowsW} strokeLinecap="round" />
      <line x1="130" y1="20" x2="130" y2="45"  stroke={gallows} strokeWidth={gallowsW} strokeLinecap="round" />

      {/* Head */}
      {wrongCount >= 1 && (
        <circle cx="130" cy="60" r="15" stroke={stroke} strokeWidth={strokeW} fill="none" />
      )}

      {/* Torso */}
      {wrongCount >= 2 && (
        <line x1="130" y1="75" x2="130" y2="130" stroke={stroke} strokeWidth={strokeW} strokeLinecap="round" />
      )}

      {/* Left arm */}
      {wrongCount >= 3 && (
        <line x1="130" y1="90" x2="105" y2="115" stroke={stroke} strokeWidth={strokeW} strokeLinecap="round" />
      )}

      {/* Right arm */}
      {wrongCount >= 4 && (
        <line x1="130" y1="90" x2="155" y2="115" stroke={stroke} strokeWidth={strokeW} strokeLinecap="round" />
      )}

      {/* Left leg */}
      {wrongCount >= 5 && (
        <line x1="130" y1="130" x2="105" y2="165" stroke={stroke} strokeWidth={strokeW} strokeLinecap="round" />
      )}

      {/* Right leg */}
      {wrongCount >= 6 && (
        <line x1="130" y1="130" x2="155" y2="165" stroke={stroke} strokeWidth={strokeW} strokeLinecap="round" />
      )}
    </svg>
  );
}
