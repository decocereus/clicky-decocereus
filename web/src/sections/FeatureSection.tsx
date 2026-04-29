import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { PlayCircle } from 'lucide-react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { ClickyCursorMark } from '../components/ClickyCursorMark';

gsap.registerPlugin(ScrollTrigger);

const DEMO_FRAMES = [
  {
    caption: 'Clicky spots the active canvas and responds with context-aware help.',
    title: 'Screen-aware guidance',
  },
  {
    caption: 'The companion points toward the right control instead of forcing you to search.',
    title: 'Visual pointing',
  },
  {
    caption: 'Clicky adapts to whatever app you are in, not just one workflow.',
    title: 'App-aware help',
  },
  {
    caption: 'Once a pattern is clear, Clicky can help repeat it on demand.',
    title: 'Repeatable workflows',
  },
];

function getEntranceTransform(direction: 'bottom' | 'top' | 'left' | 'right') {
  switch (direction) {
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
}

function getExitTransform(direction: 'left' | 'right' | 'top' | 'bottom') {
  switch (direction) {
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
}

type MockupKind = 'design' | 'settings' | 'creative' | 'tutorial' | 'personality' | 'workflow';

function getMockupKind(imageAlt: string, showSteps: boolean, showDemoReel: boolean): MockupKind {
  const normalizedAlt = imageAlt.toLowerCase();

  if (showSteps || normalizedAlt.includes('youtube') || normalizedAlt.includes('tutorial')) {
    return 'tutorial';
  }

  if (showDemoReel) {
    return 'workflow';
  }

  if (normalizedAlt.includes('settings')) {
    return 'settings';
  }

  if (normalizedAlt.includes('creative')) {
    return 'creative';
  }

  if (normalizedAlt.includes('personality')) {
    return 'personality';
  }

  if (normalizedAlt.includes('workflow')) {
    return 'workflow';
  }

  return 'design';
}

function ProductMockupPanel({
  activeDemoFrame,
  imageAlt,
  showDemoReel,
  showSteps,
}: {
  activeDemoFrame: (typeof DEMO_FRAMES)[number];
  imageAlt: string;
  showDemoReel: boolean;
  showSteps: boolean;
}) {
  const kind = getMockupKind(imageAlt, showSteps, showDemoReel);

  return (
    <div className="relative h-full overflow-hidden bg-[#F8FCFF]">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_25%_18%,rgba(79,231,238,0.16),transparent_32%),radial-gradient(circle_at_78%_62%,rgba(255,185,207,0.18),transparent_30%)]" />
      <div className="relative grid h-full grid-cols-1 text-charcoal md:grid-cols-[160px_minmax(0,1fr)] lg:grid-cols-[160px_minmax(0,1fr)_180px]">
        <aside className="hidden border-r border-[#DDE8EE]/80 bg-white/54 p-4 md:block">
          <div className="mb-5 h-2 w-20 rounded-full bg-charcoal/14" />
          {['Canvas', 'Capture', 'Pointer', 'Voice'].map((item, index) => (
            <div
              key={item}
              className={`mb-3 flex items-center gap-3 rounded-xl px-3 py-2 ${
                index === 1 ? 'bg-[#EAF8FF] text-[#3478F6]' : 'text-charcoal/50'
              }`}
            >
              <span className="h-2.5 w-2.5 rounded-full bg-current opacity-50" />
              <span className="text-xs font-medium">{item}</span>
            </div>
          ))}
        </aside>

        <main className="relative min-w-0 p-5 md:p-7">
          {kind === 'design' && (
            <div className="relative h-full rounded-2xl border border-[#DDE8EE]/80 bg-white/72 p-5 shadow-[inset_0_1px_0_rgba(255,255,255,0.85)]">
              <div className="mb-5 flex items-center justify-between">
                <div>
                  <div className="h-2 w-24 rounded-full bg-charcoal/18" />
                  <div className="mt-2 h-2 w-36 rounded-full bg-[#A9D6EB]/45" />
                </div>
                <div className="rounded-full bg-[#EAF8FF] px-3 py-1.5 text-xs font-medium text-[#3478F6]">
                  Clicky sees this
                </div>
              </div>
              <div className="grid h-[calc(100%-56px)] grid-cols-2 gap-4">
                <div className="rounded-2xl bg-[#EAF8FF] p-4">
                  <div className="h-full rounded-[28px] bg-gradient-to-br from-[#4FE7EE]/45 via-[#8EA2FF]/35 to-[#FFB9CF]/45" />
                </div>
                <div className="space-y-3">
                  <div className="h-16 rounded-2xl bg-charcoal/10" />
                  <div className="h-20 rounded-2xl bg-[#D9FEFF]" />
                  <div className="h-12 rounded-2xl bg-[#EDF1FF]" />
                </div>
              </div>
            </div>
          )}

          {kind === 'settings' && (
            <div className="grid h-full gap-4">
              {['Screen context', 'Voice response', 'Cursor pointing', 'Workflow memory'].map(
                (label, index) => (
                  <div
                    key={label}
                    className="flex items-center justify-between rounded-2xl border border-[#DDE8EE]/80 bg-white/76 px-5 py-4"
                  >
                    <div>
                      <div className="text-sm font-semibold">{label}</div>
                      <div className="mt-1 h-2 w-44 rounded-full bg-charcoal/10" />
                    </div>
                    <div className={`h-7 w-12 rounded-full p-1 ${index === 3 ? 'bg-charcoal/14' : 'bg-[#4FE7EE]'}`}>
                      <div className={`h-5 w-5 rounded-full bg-white shadow-sm ${index === 3 ? '' : 'ml-5'}`} />
                    </div>
                  </div>
                )
              )}
            </div>
          )}

          {kind === 'creative' && (
            <div className="grid h-full grid-rows-[1fr_72px] gap-4">
              <div className="relative rounded-2xl border border-[#DDE8EE]/80 bg-white/76 p-5">
                <div className="absolute left-10 top-10 h-24 w-48 rounded-[32px] bg-[#8EA2FF]/30" />
                <div className="absolute left-32 top-20 h-40 w-40 rounded-full bg-[#4FE7EE]/30" />
                <div className="absolute bottom-12 right-16 h-24 w-36 rounded-[40px] bg-[#FFB9CF]/42" />
                <div className="absolute left-24 top-36 h-px w-64 rotate-[-24deg] bg-charcoal/35" />
                <div className="absolute bottom-16 left-16 h-px w-80 bg-charcoal/28" />
                <ClickyCursorMark className="absolute right-10 top-10" size={34} />
              </div>
              <div className="grid grid-cols-5 gap-2">
                {Array.from({ length: 5 }).map((_, index) => (
                  <div key={index} className="rounded-xl bg-white/72 p-2">
                    <div className="h-full rounded-lg bg-gradient-to-r from-[#4FE7EE]/35 to-[#8EA2FF]/25" />
                  </div>
                ))}
              </div>
            </div>
          )}

          {kind === 'tutorial' && (
            <div className="grid h-full gap-4 md:grid-cols-[minmax(0,1fr)_210px]">
              <div className="relative overflow-hidden rounded-2xl bg-charcoal">
                <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(79,231,238,0.26),transparent_42%)]" />
                <PlayCircle className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 text-white" size={58} />
                <div className="absolute bottom-4 left-4 right-4 h-2 rounded-full bg-white/20">
                  <div className="h-full w-2/5 rounded-full bg-[#4FE7EE]" />
                </div>
              </div>
              <div className="space-y-3">
                {['Find the setting', 'Point at the toggle', 'Confirm the change'].map((step, index) => (
                  <div key={step} className="rounded-2xl bg-white/78 p-3">
                    <div className="mb-2 flex items-center gap-2">
                      <span className="grid h-6 w-6 place-items-center rounded-full bg-[#EAF8FF] text-xs font-semibold text-[#3478F6]">
                        {index + 1}
                      </span>
                      <span className="text-xs font-semibold">{step}</span>
                    </div>
                    <div className="h-2 rounded-full bg-charcoal/10" />
                  </div>
                ))}
              </div>
            </div>
          )}

          {kind === 'personality' && (
            <div className="grid h-full grid-cols-1 gap-4 md:grid-cols-3">
              {['Calm', 'Direct', 'Playful'].map((voice, index) => (
                <div
                  key={voice}
                  className={`rounded-2xl border p-4 ${
                    index === 1
                      ? 'border-[#4FE7EE]/70 bg-[#EAF8FF]'
                      : 'border-[#DDE8EE]/80 bg-white/72'
                  }`}
                >
                  <div className="mb-5 h-14 w-14 rounded-2xl bg-gradient-to-br from-[#4FE7EE]/50 to-[#FFB9CF]/45" />
                  <div className="text-sm font-semibold">{voice}</div>
                  <div className="mt-3 space-y-2">
                    <div className="h-2 rounded-full bg-charcoal/14" />
                    <div className="h-2 w-2/3 rounded-full bg-charcoal/10" />
                  </div>
                </div>
              ))}
            </div>
          )}

          {kind === 'workflow' && (
            <div className="relative h-full rounded-2xl border border-[#DDE8EE]/80 bg-white/70 p-5">
              <div className="mb-4 flex items-center justify-between">
                <div>
                  <div className="text-sm font-semibold">{activeDemoFrame?.title ?? 'Workflow replay'}</div>
                  <div className="mt-1 max-w-sm text-xs leading-5 text-muted-elegant">
                    {activeDemoFrame?.caption ?? 'Clicky turns the repeated work into a guided sequence.'}
                  </div>
                </div>
                <div className="rounded-full bg-charcoal px-3 py-1.5 text-xs font-medium text-white">
                  Live pattern
                </div>
              </div>
              <div className="absolute left-[18%] top-[38%] h-px w-[56%] bg-[#A9D6EB]" />
              <div className="absolute left-[42%] top-[52%] h-px w-[32%] rotate-[28deg] bg-[#A9D6EB]" />
              {['Listen', 'Read screen', 'Point', 'Act'].map((node, index) => (
                <div
                  key={node}
                  className="absolute rounded-2xl border border-white/80 bg-gradient-to-br from-white to-[#EAF8FF] px-4 py-3 text-xs font-semibold shadow-sm"
                  style={{
                    left: `${14 + index * 19}%`,
                    top: `${index % 2 === 0 ? 34 : 56}%`,
                  }}
                >
                  {node}
                </div>
              ))}
            </div>
          )}
        </main>

        <aside className="hidden border-l border-[#DDE8EE]/80 bg-white/48 p-4 lg:block">
          <div className="mb-4 text-xs font-semibold text-charcoal/46">Context</div>
          {['Focused element', 'Front app', 'Recent action', 'Intent'].map((label) => (
            <div key={label} className="mb-4 rounded-xl bg-white/72 p-3">
              <div className="mb-2 text-[10px] font-semibold uppercase tracking-[0.14em] text-charcoal/36">
                {label}
              </div>
              <div className="h-2 rounded-full bg-[#A9D6EB]/45" />
            </div>
          ))}
        </aside>
      </div>
    </div>
  );
}

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

      const entrance = getEntranceTransform(entranceDirection);
      const exit = getExitTransform(exitDirection);

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
  }, [description, entranceDirection, exitDirection, mascotPosition, showSteps]);

  useEffect(() => {
    if (!showDemoReel) {
      return undefined;
    }

    const intervalId = window.setInterval(() => {
      setDemoFrameIndex((currentIndex) => (currentIndex + 1) % DEMO_FRAMES.length);
    }, 2200);

    return () => {
      window.clearInterval(intervalId);
    };
  }, [showDemoReel]);

  const activeDemoFrame = DEMO_FRAMES[showDemoReel ? demoFrameIndex : 0];

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

      {/* Product UI mockup */}
      <div
        ref={cardRef}
        className="absolute overflow-hidden rounded-[28px] border border-white/80 bg-white/72 shadow-elegant backdrop-blur-xl"
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
          <div className="flex items-center gap-2 px-4 py-3 bg-gradient-to-b from-[#FAFCFF] to-[#EAF8FF] border-b border-[#DDE8EE]/70 flex-shrink-0">
            <div className="w-3 h-3 rounded-full bg-red-400/80" />
            <div className="w-3 h-3 rounded-full bg-yellow-400/80" />
            <div className="w-3 h-3 rounded-full bg-[#4FE7EE]/80" />
            <div className="flex-1 text-center">
              <span className="text-xs text-gray-400 font-medium">{imageAlt}</span>
            </div>
          </div>
          {/* Recreated interface mockup */}
          <div className="flex-1 relative overflow-hidden">
            <ProductMockupPanel
              activeDemoFrame={activeDemoFrame}
              imageAlt={imageAlt}
              showDemoReel={showDemoReel}
              showSteps={showSteps}
            />
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
              <div className="w-6 h-6 rounded-full bg-[#EAF8FF] flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-xs font-medium text-[#3478F6]">1</span>
              </div>
              <div>
                <p className="text-sm font-medium text-charcoal">Paste YouTube URL</p>
                <p className="text-xs text-muted-elegant mt-0.5">Any tutorial video</p>
              </div>
            </div>
            <div className="flex items-start gap-3 p-3 bg-white/95 backdrop-blur-sm rounded-xl shadow-elegant border border-gray-100">
              <div className="w-6 h-6 rounded-full bg-[#EDF1FF] flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-xs font-medium text-[#526EF3]">2</span>
              </div>
              <div>
                <p className="text-sm font-medium text-charcoal">Clicky analyzes</p>
                <p className="text-xs text-muted-elegant mt-0.5">Extracts key steps</p>
              </div>
            </div>
            <div className="flex items-start gap-3 p-3 bg-white/95 backdrop-blur-sm rounded-xl shadow-elegant border border-gray-100">
              <div className="w-6 h-6 rounded-full bg-[#D9FEFF] flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-xs font-medium text-[#138D98]">3</span>
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
        <ClickyCursorMark size={46} />
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
