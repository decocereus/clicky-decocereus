interface ClickyCursorMarkProps {
  className?: string;
  size?: number;
}

export function ClickyCursorMark({ className = '', size = 44 }: ClickyCursorMarkProps) {
  return (
    <svg
      aria-hidden="true"
      className={className}
      fill="none"
      height={size}
      viewBox="0 0 44 44"
      width={size}
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <linearGradient id="clicky-cursor-fill" x1="9" x2="36" y1="5" y2="38">
          <stop offset="0" stopColor="#4FE7EE" />
          <stop offset="0.48" stopColor="#3478F6" />
          <stop offset="1" stopColor="#FFB9CF" />
        </linearGradient>
        <filter
          colorInterpolationFilters="sRGB"
          filterUnits="userSpaceOnUse"
          height="44"
          id="clicky-cursor-glow"
          width="44"
          x="0"
          y="0"
        >
          <feDropShadow dx="0" dy="8" floodColor="#3478F6" floodOpacity="0.18" stdDeviation="6" />
          <feDropShadow dx="0" dy="2" floodColor="#4FE7EE" floodOpacity="0.16" stdDeviation="2" />
        </filter>
      </defs>
      <path
        d="M14.28 6.92C12.06 5.65 9.3 6.98 8.73 9.47c-2.73 11.84-1.84 23.34.25 29.09.84 2.32 3.76 3.06 5.61 1.42l7.16-6.34a8.8 8.8 0 0 1 6.12-2.22l8.22.34c3.58.15 5.27-4.36 2.53-6.67L14.28 6.92Z"
        fill="url(#clicky-cursor-fill)"
        filter="url(#clicky-cursor-glow)"
        opacity="0.96"
        stroke="rgba(255,255,255,0.86)"
        strokeLinejoin="round"
        strokeWidth="2.2"
      />
      <path
        d="M15.7 11.3c-1.1 5.63-1.1 12.2-.16 18.36"
        opacity="0.36"
        stroke="white"
        strokeLinecap="round"
        strokeWidth="2"
      />
    </svg>
  );
}

export default ClickyCursorMark;
