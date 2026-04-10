import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { PlayCircle, Sparkles } from 'lucide-react';
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
  description?: string;
  showSteps?: boolean;
  showDemoReel?: boolean;
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
  description,
  showSteps = false,
  showDemoReel = false,
}: FeatureSectionProps) {
  const sectionRef = useRef<HTMLDivElement>(null);
  const headlineRef = useRef<HTMLDivElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);
  const mascotRef = useRef<HTMLDivElement>(null);
  const bubbleRef = useRef<HTMLDivElement>(null);
  const descRef = useRef<HTMLParagraphElement>(null);
  const stepsRef = useRef<HTMLDivElement>(null);
  const [demoFrameIndex, setDemoFrameIndex] = useState(0);

  const demoFrames = [
    {
      caption: 'Clicky spots the active canvas and responds with context-aware help.',
      src: '/screen_design_tool.jpg',
      title: 'Screen-aware guidance',
    },
    {
      caption: 'The companion points toward the right control instead of forcing you to search.',
      src: '/screen_settings_panel.jpg',
      title: 'Visual pointing',
    },
    {
      caption: 'Clicky adapts to whatever app you are in, not just one workflow.',
      src: '/screen_creative_app.jpg',
      title: 'App-aware help',
    },
    {
      caption: 'Once a pattern is clear, Clicky can help repeat it on demand.',
      src: '/screen_workflow_builder.jpg',
      title: 'Repeatable workflows',
    },
  ];

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
          end: '+=120%',
          pin: true,
          scrub: 0.3,
        },
      });

      const entrance = getEntranceTransform();
      const exit = getExitTransform();

      // FASTER ENTRANCE PHASE (0-20%) - Quick build up for fast scrollers
      // Card entrance - comes in quickly
      scrollTl.fromTo(
        cardRef.current,
        { ...entrance, opacity: 0, scale: 0.85 },
        { x: 0, y: 0, opacity: 1, scale: 1, ease: 'power2.out', duration: 0.2 },
        0
      );

      // Headline entrance - synchronized with card but from opposite direction
      scrollTl.fromTo(
        headlineRef.current,
        { y: '-30vh', opacity: 0 },
        { y: 0, opacity: 1, ease: 'power2.out', duration: 0.18 },
        0.02
      );

      // Mascot entrance
      scrollTl.fromTo(
        mascotRef.current,
        { x: mascotPosition.includes('right') ? '50vw' : '-50vw', opacity: 0, scale: 0.7 },
        { x: 0, opacity: 1, scale: 1, ease: 'power2.out', duration: 0.15 },
        0.08
      );

      // Bubble entrance
      scrollTl.fromTo(
        bubbleRef.current,
        { opacity: 0, y: -15, scale: 0.85 },
        { opacity: 1, y: 0, scale: 1, ease: 'power2.out', duration: 0.1 },
        0.12
      );

      // Description entrance
      if (descRef.current) {
        scrollTl.fromTo(
          descRef.current,
          { y: 20, opacity: 0 },
          { y: 0, opacity: 1, ease: 'power2.out', duration: 0.1 },
          0.1
        );
      }

      // Steps entrance
      if (stepsRef.current) {
        const stepItems = stepsRef.current.children;
        scrollTl.fromTo(
          stepItems,
          { x: -20, opacity: 0 },
          { x: 0, opacity: 1, stagger: 0.02, ease: 'power2.out', duration: 0.08 },
          0.14
        );
      }

      // EXTENDED SETTLE PHASE (20-75%) - Elements stay clearly visible
      // No animations - maximum viewing time

      // EXIT PHASE (75-100%) - Headline exits FIRST, then card
      // Headline exits early (at 75%) so it's not hidden behind card
      scrollTl.to(
        headlineRef.current,
        { y: '-15vh', opacity: 0, ease: 'power2.in', duration: 0.15 },
        0.75
      );

      // Description exits with headline
      if (descRef.current) {
        scrollTl.to(
          descRef.current,
          { y: 15, opacity: 0, ease: 'power2.in', duration: 0.12 },
          0.78
        );
      }

      // Card exits after headline (starts at 82%)
      scrollTl.to(
        cardRef.current,
        { ...exit, opacity: 0, ease: 'power2.in', duration: 0.18 },
        0.82
      );

      // Steps exit
      if (stepsRef.current) {
        const stepItems = stepsRef.current.children;
        scrollTl.to(
          stepItems,
          { x: 20, opacity: 0, stagger: 0.01, ease: 'power2.in', duration: 0.1 },
          0.85
        );
      }

      // Mascot and bubble exit last
      scrollTl.to(
        mascotRef.current,
        {
          x: exitDirection === 'right' ? '45vw' : exitDirection === 'left' ? '-45vw' : 0,
          y: exitDirection === 'bottom' ? '30vh' : exitDirection === 'top' ? '-30vh' : 0,
          opacity: 0,
          ease: 'power2.in',
          duration: 0.15,
        },
        0.85
      );

      scrollTl.to(
        bubbleRef.current,
        { opacity: 0, y: -10, ease: 'power2.in', duration: 0.1 },
        0.88
      );
    }, section);

    return () => ctx.revert();
  }, [entranceDirection, exitDirection, mascotPosition, description, showSteps]);

  useEffect(() => {
    if (!showDemoReel) {
      setDemoFrameIndex(0);
      return undefined;
    }

    const intervalId = window.setInterval(() => {
      setDemoFrameIndex((currentIndex) => (currentIndex + 1) % demoFrames.length);
    }, 2200);

    return () => {
      window.clearInterval(intervalId);
    };
  }, [showDemoReel]);

  return (
    <section
      ref={sectionRef}
      id={id}
      className={`relative w-full h-screen ${getBgClass()} overflow-hidden`}
      style={{ zIndex }}
    >
      {/* Headline - elevated z-index to stay above card during exit */}
      <div
        ref={headlineRef}
        className="absolute text-center w-full z-20"
        style={{
          left: '50%',
          top: description ? '38%' : '46%',
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
        
        {/* Description text */}
        {description && (
          <p
            ref={descRef}
            className="text-muted-elegant mt-4 max-w-lg mx-auto px-6 text-base leading-relaxed"
          >
            {description}
          </p>
        )}
      </div>

      {/* Screenshot Card */}
      <div
        ref={cardRef}
        className="absolute rounded-3xl shadow-elegant overflow-hidden bg-white"
        style={{
          left: showSteps ? '35%' : '50%',
          top: '54%',
          width: showSteps ? '55vw' : '72vw',
          height: '50vh',
          transform: 'translate(-50%, -50%)',
        }}
      >
        {/* macOS-style window chrome + content */}
        <div className="w-full h-full flex flex-col">
          {/* Window title bar */}
          <div className="flex items-center gap-2 px-4 py-3 bg-gradient-to-b from-gray-50 to-gray-100 border-b border-gray-200/50 flex-shrink-0">
            <div className="w-3 h-3 rounded-full bg-red-400/80" />
            <div className="w-3 h-3 rounded-full bg-yellow-400/80" />
            <div className="w-3 h-3 rounded-full bg-green-400/80" />
            <div className="flex-1 text-center">
              <span className="text-xs text-gray-400 font-medium">{imageAlt}</span>
            </div>
          </div>
          {/* Content - either image or UI mockup */}
          <div className="flex-1 relative overflow-hidden">
            {showDemoReel ? (
              <>
                {demoFrames.map((frame, frameIndex) => (
                  <img
                    key={frame.src}
                    src={frame.src}
                    alt={frame.title}
                    className="absolute inset-0 h-full w-full object-cover transition-opacity duration-700"
                    style={{
                      opacity: frameIndex === demoFrameIndex ? 0.94 : 0,
                    }}
                  />
                ))}

                <div className="absolute inset-x-0 top-0 flex items-center justify-between px-5 py-4">
                  <div className="inline-flex items-center gap-2 rounded-full border border-white/70 bg-white/92 px-3 py-1.5 text-xs font-medium text-charcoal shadow-sm backdrop-blur-sm">
                    <PlayCircle size={14} className="text-lavender" />
                    Permission-free demo
                  </div>
                  <div className="inline-flex items-center gap-2 rounded-full border border-white/70 bg-white/92 px-3 py-1.5 text-xs font-medium text-charcoal shadow-sm backdrop-blur-sm">
                    <Sparkles size={14} className="text-lavender" />
                    Scroll for the story
                  </div>
                </div>

                <div className="absolute inset-x-0 bottom-0 space-y-3 bg-gradient-to-t from-black/65 via-black/20 to-transparent px-5 pb-5 pt-16 text-white">
                  <div className="flex gap-1.5">
                    {demoFrames.map((frame, frameIndex) => (
                      <span
                        key={frame.src}
                        className="h-1.5 flex-1 rounded-full transition-all duration-500"
                        style={{
                          backgroundColor:
                            frameIndex === demoFrameIndex
                              ? 'rgba(255,255,255,0.96)'
                              : 'rgba(255,255,255,0.28)',
                        }}
                      />
                    ))}
                  </div>
                  <p className="text-sm font-semibold tracking-[0.02em]">
                    {demoFrames[demoFrameIndex]?.title}
                  </p>
                  <p className="max-w-xl text-sm leading-6 text-white/88">
                    {demoFrames[demoFrameIndex]?.caption}
                  </p>
                  <p className="text-xs uppercase tracking-[0.18em] text-white/70">
                    Enable mic + screen anytime for the live version
                  </p>
                </div>
              </>
            ) : (
              <img
                src={imageSrc}
                alt={imageAlt}
                className="w-full h-full object-cover opacity-90"
              />
            )}
            {/* Subtle gradient overlay for depth */}
            <div className="absolute inset-0 bg-gradient-to-t from-black/5 to-transparent pointer-events-none" />
          </div>
        </div>
        
        {/* Steps overlay for video section */}
        {showSteps && (
          <div 
            ref={stepsRef}
            className="absolute right-0 top-1/2 -translate-y-1/2 translate-x-[calc(100%+1.5rem)] w-48 space-y-3"
          >
            <div className="flex items-start gap-3 p-3 bg-white/95 backdrop-blur-sm rounded-xl shadow-elegant border border-gray-100">
              <div className="w-6 h-6 rounded-full bg-blue-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-xs font-medium text-blue-600">1</span>
              </div>
              <div>
                <p className="text-sm font-medium text-charcoal">Paste YouTube URL</p>
                <p className="text-xs text-muted-elegant mt-0.5">Any tutorial video</p>
              </div>
            </div>
            <div className="flex items-start gap-3 p-3 bg-white/95 backdrop-blur-sm rounded-xl shadow-elegant border border-gray-100">
              <div className="w-6 h-6 rounded-full bg-purple-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-xs font-medium text-purple-600">2</span>
              </div>
              <div>
                <p className="text-sm font-medium text-charcoal">Clicky analyzes</p>
                <p className="text-xs text-muted-elegant mt-0.5">Extracts key steps</p>
              </div>
            </div>
            <div className="flex items-start gap-3 p-3 bg-white/95 backdrop-blur-sm rounded-xl shadow-elegant border border-gray-100">
              <div className="w-6 h-6 rounded-full bg-green-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-xs font-medium text-green-600">3</span>
              </div>
              <div>
                <p className="text-sm font-medium text-charcoal">Execute step-by-step</p>
                <p className="text-xs text-muted-elegant mt-0.5">Guided automation</p>
              </div>
            </div>
          </div>
        )}
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
