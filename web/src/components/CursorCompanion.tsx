import { useEffect, useRef, useState, useCallback } from 'react';
import { createPortal } from 'react-dom';

interface Message {
  text: string;
  duration: number;
}

const MESSAGES: Message[] = [
  { text: "Hi, I'm Clicky! 👋", duration: 3000 },
  { text: "I'm attached to your cursor ✨", duration: 3500 },
  { text: "I see what you see 👀", duration: 3000 },
  { text: "Let's explore together! 🚀", duration: 4000 },
];

export function CursorCompanion() {
  const companionRef = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState({ x: -100, y: -100 });
  const [isVisible, setIsVisible] = useState(false);
  const [showGlow, setShowGlow] = useState(false);
  const [currentMessageIndex, setCurrentMessageIndex] = useState(0);
  const [showBubble, setShowBubble] = useState(false);
  const [mounted, setMounted] = useState(false);
  const mousePos = useRef({ x: 0, y: 0 });
  const currentPos = useRef({ x: -100, y: -100 });
  const rafRef = useRef<number | undefined>(undefined);

  // Mount
  useEffect(() => {
    setMounted(true);
    return () => setMounted(false);
  }, []);

  // Smooth follow - minimal spring, more direct
  const updatePosition = useCallback(() => {
    // Very soft interpolation - smooth but not springy
    const t = 0.12;
    
    const targetX = mousePos.current.x + 24;
    const targetY = mousePos.current.y + 24;
    
    currentPos.current.x += (targetX - currentPos.current.x) * t;
    currentPos.current.y += (targetY - currentPos.current.y) * t;

    setPosition({
      x: currentPos.current.x,
      y: currentPos.current.y,
    });

    rafRef.current = requestAnimationFrame(updatePosition);
  }, []);

  // Initialize
  useEffect(() => {
    if (!mounted) return;

    const timer = setTimeout(() => {
      // Start tracking
      rafRef.current = requestAnimationFrame(updatePosition);
      
      // Fade in companion
      setIsVisible(true);
      
      // Show glow effect
      setTimeout(() => setShowGlow(true), 300);
      
      // Start messages
      setTimeout(() => {
        setShowBubble(true);
        startMessageCycle();
      }, 800);
    }, 600);

    return () => {
      clearTimeout(timer);
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [mounted, updatePosition]);

  // Track mouse
  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      mousePos.current = { x: e.clientX, y: e.clientY };
    };
    window.addEventListener('mousemove', handleMouseMove, { passive: true });
    return () => window.removeEventListener('mousemove', handleMouseMove);
  }, []);

  // Message cycle
  const startMessageCycle = useCallback(() => {
    let index = 0;
    
    const showNextMessage = () => {
      setCurrentMessageIndex(index);
      setShowBubble(true);
      
      setTimeout(() => {
        setShowBubble(false);
        
        // Wait before next message
        setTimeout(() => {
          index = (index + 1) % MESSAGES.length;
          showNextMessage();
        }, 1500);
      }, MESSAGES[index].duration);
    };
    
    showNextMessage();
  }, []);

  // Don't render on touch
  if (typeof window === 'undefined' || 'ontouchstart' in window) {
    return null;
  }
  if (!mounted) return null;

  const currentMessage = MESSAGES[currentMessageIndex];

  return createPortal(
    <div
      ref={companionRef}
      className="fixed pointer-events-none z-[9999]"
      style={{
        left: position.x,
        top: position.y,
        transform: 'translate(-50%, -50%)',
        opacity: isVisible ? 1 : 0,
        transition: 'opacity 0.8s ease-out',
      }}
    >
      {/* Text Bubble - positioned UNDER the companion */}
      <div
        className="absolute top-full left-1/2 mt-3 transition-all duration-500 ease-out"
        style={{ 
          minWidth: 'max-content',
          opacity: showBubble ? 1 : 0,
          transform: showBubble 
            ? 'translateX(-50%) translateY(0)' 
            : 'translateX(-50%) translateY(-12px)',
        }}
      >
        <div className="bg-white rounded-xl px-4 py-2 shadow-xl border border-gray-100">
          <p className="text-sm font-semibold text-charcoal whitespace-nowrap">
            {currentMessage?.text}
          </p>
          <div
            className="absolute bottom-full left-1/2 -translate-x-1/2 w-0 h-0"
            style={{
              borderLeft: '6px solid transparent',
              borderRight: '6px solid transparent',
              borderBottom: '7px solid white',
            }}
          />
        </div>
      </div>

      {/* Companion with glow */}
      <div className="relative">
        {/* Animated glow ring */}
        <div 
          className="absolute inset-0 rounded-full transition-all duration-700"
          style={{
            background: 'radial-gradient(circle, rgba(122, 155, 196, 0.6) 0%, transparent 70%)',
            transform: 'scale(3)',
            opacity: showGlow ? 0.6 : 0,
            filter: 'blur(4px)',
          }}
        />
        
        {/* Pulsing inner glow */}
        <div 
          className="absolute inset-0 rounded-full animate-pulse"
          style={{
            background: 'radial-gradient(circle, rgba(122, 155, 196, 0.4) 0%, transparent 60%)',
            transform: 'scale(2)',
            opacity: showGlow ? 0.8 : 0,
          }}
        />
        
        {/* Sparkles */}
        {showGlow && (
          <>
            <div 
              className="absolute -top-2 -right-2 w-1.5 h-1.5 bg-white rounded-full animate-ping"
              style={{ animationDuration: '2s' }}
            />
            <div 
              className="absolute -bottom-1 -left-3 w-1 h-1 bg-lavender rounded-full animate-ping"
              style={{ animationDuration: '2.5s', animationDelay: '0.5s' }}
            />
            <div 
              className="absolute top-0 -left-2 w-0.5 h-0.5 bg-white rounded-full animate-ping"
              style={{ animationDuration: '3s', animationDelay: '1s' }}
            />
          </>
        )}
        
        {/* Triangle cursor */}
        <div
          style={{
            filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.15))',
          }}
        >
          <svg
            viewBox="0 0 24 24"
            width="20"
            height="20"
            style={{ transform: 'rotate(-45deg)' }}
          >
            <path
              d="M12 2L22 20H2L12 2Z"
              fill="#7A9BC4"
            />
          </svg>
        </div>
      </div>
    </div>,
    document.body
  );
}

export default CursorCompanion;
