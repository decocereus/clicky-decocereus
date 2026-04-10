import { useRef, useLayoutEffect } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

interface FeatureSectionProps {
  id: string;
  headline: string;
  headlineItalic?: string;
  bubbleText: string;
  imageSrc: string;
  imageAlt: string;
  mascotPosition: 'top-right' | 'top-left' | 'bottom-right' | 'bottom-left';
  zIndex: number;
  entranceDirection?: 'bottom' | 'top' | 'left' | 'right';
  exitDirection?: 'left' | 'right' | 'top' | 'bottom';
  bgColor?: 'warm' | 'sage' | 'lavender' | 'rose';
}

export function FeatureSection({
  id,
  headline,
  headlineItalic,
  bubbleText,
  imageSrc,
  imageAlt,
  mascotPosition,
  zIndex,
  entranceDirection = 'bottom',
  exitDirection = 'left',
  bgColor = 'warm',
}: FeatureSectionProps) {
  const sectionRef = useRef<HTMLDivElement>(null);
  const headlineRef = useRef<HTMLDivElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);
  const mascotRef = useRef<HTMLDivElement>(null);
  const bubbleRef = useRef<HTMLDivElement>(null);

  const getBgClass = () => {
    switch (bgColor) {
      case 'sage':
        return 'bg-sage';
      case 'lavender':
        return 'bg-lavender';
      case 'rose':
        return 'bg-rose';
      default:
        return 'bg-warm';
    }
  };

  const getMascotPosition = () => {
    switch (mascotPosition) {
      case 'top-right':
        return { left: '76%', top: '20%' };
      case 'top-left':
        return { left: '12%', top: '20%' };
      case 'bottom-right':
        return { left: '78%', top: '72%' };
      case 'bottom-left':
        return { left: '14%', top: '60%' };
      default:
        return { left: '76%', top: '20%' };
    }
  };

  const getBubblePosition = () => {
    switch (mascotPosition) {
      case 'top-right':
        return { left: '80%', top: '12%' };
      case 'top-left':
        return { left: '16%', top: '12%' };
      case 'bottom-right':
        return { left: '82%', top: '60%' };
      case 'bottom-left':
        return { left: '18%', top: '48%' };
      default:
        return { left: '80%', top: '12%' };
    }
  };

  const getEntranceTransform = () => {
    switch (entranceDirection) {
      case 'bottom':
        return { y: '100vh', x: 0 };
      case 'top':
        return { y: '-100vh', x: 0 };
      case 'left':
        return { x: '-70vw', y: 0 };
      case 'right':
        return { x: '70vw', y: 0 };
      default:
        return { y: '100vh', x: 0 };
    }
  };

  const getExitTransform = () => {
    switch (exitDirection) {
      case 'left':
        return { x: '-60vw', rotate: -4 };
      case 'right':
        return { x: '60vw', rotate: 4 };
      case 'top':
        return { y: '-60vh' };
      case 'bottom':
        return { y: '60vh' };
      default:
        return { x: '-60vw', rotate: -4 };
    }
  };

  useLayoutEffect(() => {
    const section = sectionRef.current;
    if (!section) return;

    const ctx = gsap.context(() => {
      const scrollTl = gsap.timeline({
        scrollTrigger: {
          trigger: section,
          start: 'top top',
          end: '+=130%',
          pin: true,
          scrub: 0.6,
        },
      });

      const entrance = getEntranceTransform();
      const exit = getExitTransform();

      // Card entrance (0-25%)
      scrollTl.fromTo(
        cardRef.current,
        { ...entrance, opacity: 0, scale: 0.92 },
        { x: 0, y: 0, opacity: 1, scale: 1, ease: 'power3.out' },
        0
      );

      // Headline entrance (5-22%)
      scrollTl.fromTo(
        headlineRef.current,
        { y: '-40vh', opacity: 0 },
        { y: 0, opacity: 1, ease: 'power2.out' },
        0.05
      );

      // Mascot entrance (12-28%)
      scrollTl.fromTo(
        mascotRef.current,
        { x: mascotPosition.includes('right') ? '55vw' : '-55vw', opacity: 0, scale: 0.8 },
        { x: 0, opacity: 1, scale: 1, ease: 'power2.out' },
        0.12
      );

      // Bubble entrance (18-30%)
      scrollTl.fromTo(
        bubbleRef.current,
        { opacity: 0, y: -10 },
        { opacity: 1, y: 0, ease: 'power2.out' },
        0.18
      );

      // Exit (70-100%)
      scrollTl.to(
        cardRef.current,
        { ...exit, opacity: 0, ease: 'power2.in' },
        0.7
      );

      scrollTl.to(
        headlineRef.current,
        { y: '-14vh', opacity: 0, ease: 'power2.in' },
        0.7
      );

      scrollTl.to(
        mascotRef.current,
        {
          x: exitDirection === 'right' ? '50vw' : exitDirection === 'left' ? '-50vw' : 0,
          y: exitDirection === 'bottom' ? '35vh' : exitDirection === 'top' ? '-35vh' : 0,
          opacity: 0,
          ease: 'power2.in',
        },
        0.75
      );

      scrollTl.to(
        bubbleRef.current,
        { opacity: 0, ease: 'power2.in' },
        0.7
      );
    }, section);

    return () => ctx.revert();
  }, [entranceDirection, exitDirection, mascotPosition]);

  return (
    <section
      ref={sectionRef}
      id={id}
      className={`relative w-full h-screen ${getBgClass()} overflow-hidden`}
      style={{ zIndex }}
    >
      {/* Headline */}
      <div
        ref={headlineRef}
        className="absolute text-center w-full"
        style={{
          left: '50%',
          top: '52%',
          transform: 'translate(-50%, -50%)',
        }}
      >
        <h2
          className="text-charcoal"
          style={{
            fontSize: 'clamp(40px, 5vw, 72px)',
            lineHeight: 1.1,
          }}
        >
          {headlineItalic ? (
            <>
              <span className="font-semibold">{headline}</span>{' '}
              <span className="font-serif-italic text-lavender">{headlineItalic}</span>
            </>
          ) : (
            headline
          )}
        </h2>
      </div>

      {/* Screenshot Card */}
      <div
        ref={cardRef}
        className="absolute rounded-3xl shadow-elegant overflow-hidden bg-white"
        style={{
          left: '50%',
          top: '54%',
          width: '72vw',
          height: '54vh',
          transform: 'translate(-50%, -50%)',
        }}
      >
        <img
          src={imageSrc}
          alt={imageAlt}
          className="w-full h-full object-cover"
        />
      </div>

      {/* Mascot */}
      <div
        ref={mascotRef}
        className="absolute"
        style={getMascotPosition()}
      >
        <svg viewBox="0 0 52 52" width="44" height="44" className="drop-shadow-md">
          <path
            d="M26 4C26 4 8 18 8 32C8 41.941 16.059 50 26 50C35.941 50 44 41.941 44 32C44 18 26 4 26 4Z"
            fill="#7A9BC4"
          />
          <ellipse cx="20" cy="26" rx="5" ry="7" fill="white" opacity="0.9" />
          <circle cx="18" cy="23" r="2" fill="white" opacity="0.6" />
        </svg>
      </div>

      {/* Speech Bubble */}
      <div
        ref={bubbleRef}
        className="absolute"
        style={getBubblePosition()}
      >
        <div className="bg-white rounded-2xl px-4 py-2.5 shadow-elegant whitespace-nowrap">
          <p className="text-sm text-charcoal">{bubbleText}</p>
          <div
            className="absolute w-0 h-0"
            style={{
              top: '100%',
              left: '20px',
              borderLeft: '8px solid transparent',
              borderRight: '8px solid transparent',
              borderTop: '10px solid white',
            }}
          />
        </div>
      </div>
    </section>
  );
}

export default FeatureSection;
