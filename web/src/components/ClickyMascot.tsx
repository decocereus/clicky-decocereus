import { useEffect, useRef, useState } from 'react';
import { gsap } from 'gsap';

interface ClickyMascotProps {
  className?: string;
  size?: number;
  bubbleText?: string | null;
  bubblePosition?: 'top' | 'bottom' | 'left' | 'right';
  followCursor?: boolean;
  followDelay?: number;
  staticPosition?: { x: string; y: string };
}

export function ClickyMascot({
  className = '',
  size = 52,
  bubbleText = null,
  bubblePosition = 'top',
  followCursor = true,
  followDelay = 0.08,
  staticPosition,
}: ClickyMascotProps) {
  const mascotRef = useRef<HTMLDivElement>(null);
  const bubbleRef = useRef<HTMLDivElement>(null);
  const mousePos = useRef({ x: 0, y: 0 });
  const currentPos = useRef({ x: 0, y: 0 });
  const [isVisible, setIsVisible] = useState(true);

  useEffect(() => {
    if (!followCursor || staticPosition) return;

    const handleMouseMove = (e: MouseEvent) => {
      mousePos.current = { x: e.clientX, y: e.clientY };
    };

    const handleMouseLeave = () => {
      setIsVisible(false);
    };

    const handleMouseEnter = () => {
      setIsVisible(true);
    };

    window.addEventListener('mousemove', handleMouseMove, { passive: true });
    document.body.addEventListener('mouseleave', handleMouseLeave);
    document.body.addEventListener('mouseenter', handleMouseEnter);

    let rafId: number;
    const animate = () => {
      if (mascotRef.current && isVisible) {
        currentPos.current.x += (mousePos.current.x - currentPos.current.x) * followDelay;
        currentPos.current.y += (mousePos.current.y - currentPos.current.y) * followDelay;

        const offsetX = size / 2;
        const offsetY = size / 2 + 20;

        gsap.set(mascotRef.current, {
          x: currentPos.current.x - offsetX,
          y: currentPos.current.y - offsetY,
        });
      }
      rafId = requestAnimationFrame(animate);
    };

    animate();

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      document.body.removeEventListener('mouseleave', handleMouseLeave);
      document.body.removeEventListener('mouseenter', handleMouseEnter);
      cancelAnimationFrame(rafId);
    };
  }, [followCursor, followDelay, size, isVisible, staticPosition]);

  useEffect(() => {
    if (bubbleRef.current && bubbleText) {
      gsap.fromTo(
        bubbleRef.current,
        { opacity: 0, y: 10, scale: 0.95 },
        { opacity: 1, y: 0, scale: 1, duration: 0.3, ease: 'power2.out' }
      );
    }
  }, [bubbleText]);

  const getBubblePositionClasses = () => {
    switch (bubblePosition) {
      case 'top':
        return 'bottom-full left-1/2 -translate-x-1/2 mb-3';
      case 'bottom':
        return 'top-full left-1/2 -translate-x-1/2 mt-3';
      case 'left':
        return 'right-full top-1/2 -translate-y-1/2 mr-3';
      case 'right':
        return 'left-full top-1/2 -translate-y-1/2 ml-3';
      default:
        return 'bottom-full left-1/2 -translate-x-1/2 mb-3';
    }
  };

  const getBubbleTailClasses = () => {
    switch (bubblePosition) {
      case 'top':
        return 'after:top-full after:left-1/2 after:-translate-x-1/2 after:border-t-white after:border-b-transparent after:border-l-transparent after:border-r-transparent';
      case 'bottom':
        return 'after:bottom-full after:left-1/2 after:-translate-x-1/2 after:border-b-white after:border-t-transparent after:border-l-transparent after:border-r-transparent';
      case 'left':
        return 'after:left-full after:top-1/2 after:-translate-y-1/2 after:border-l-white after:border-r-transparent after:border-t-transparent after:border-b-transparent';
      case 'right':
        return 'after:right-full after:top-1/2 after:-translate-y-1/2 after:border-r-white after:border-l-transparent after:border-t-transparent after:border-b-transparent';
      default:
        return 'after:top-full after:left-1/2 after:-translate-x-1/2 after:border-t-white after:border-b-transparent after:border-l-transparent after:border-r-transparent';
    }
  };

  return (
    <div
      ref={mascotRef}
      className={`fixed z-50 pointer-events-none ${className}`}
      style={{
        width: size,
        height: size,
        left: staticPosition?.x,
        top: staticPosition?.y,
        opacity: isVisible ? 1 : 0,
        transition: 'opacity 0.2s ease',
      }}
    >
      {/* Speech Bubble */}
      {bubbleText && (
        <div
          ref={bubbleRef}
          className={`absolute whitespace-nowrap ${getBubblePositionClasses()}`}
        >
          <div
            className={`bg-white rounded-2xl px-4 py-2.5 shadow-lg ${getBubbleTailClasses()}`}
            style={{
              filter: 'drop-shadow(0 4px 20px rgba(0,0,0,0.15))',
            }}
          >
            <p className="text-sm font-medium text-ink">{bubbleText}</p>
          </div>
        </div>
      )}

      {/* Clicky SVG */}
      <svg
        viewBox="0 0 52 52"
        width={size}
        height={size}
        className="drop-shadow-lg"
      >
        {/* Main body - teardrop shape */}
        <path
          d="M26 4C26 4 8 18 8 32C8 41.941 16.059 50 26 50C35.941 50 44 41.941 44 32C44 18 26 4 26 4Z"
          fill="#3B82F6"
        />
        {/* Highlight/eye */}
        <ellipse
          cx="20"
          cy="26"
          rx="5"
          ry="7"
          fill="white"
          opacity="0.9"
        />
        {/* Small shine */}
        <circle
          cx="18"
          cy="23"
          r="2"
          fill="white"
          opacity="0.6"
        />
      </svg>
    </div>
  );
}

export default ClickyMascot;
