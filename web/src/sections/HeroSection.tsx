import { useEffect, useRef, useLayoutEffect, useState } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { CursorCompanion } from '../components/CursorCompanion';
import { useWebCompanionExperience } from '../components/WebCompanionExperience';
import { Download, LoaderCircle, Mic, PlayCircle, Sparkles } from 'lucide-react';
import { getDownloadUrl } from '../lib/download';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '../components/ui/dialog';

gsap.registerPlugin(ScrollTrigger);

export function HeroSection() {
  const {
    errorMessage: companionErrorMessage,
    experienceMode,
    startExperience,
    status: companionStatus,
  } = useWebCompanionExperience();
  const [isPermissionModalOpen, setIsPermissionModalOpen] = useState(false);
  const downloadUrl = getDownloadUrl();
  const sectionRef = useRef<HTMLDivElement>(null);
  const headlineRef = useRef<HTMLDivElement>(null);
  const subheadRef = useRef<HTMLParagraphElement>(null);
  const ctaRef = useRef<HTMLDivElement>(null);
  const cardARef = useRef<HTMLDivElement>(null);
  const cardBRef = useRef<HTMLDivElement>(null);
  const cardCRef = useRef<HTMLDivElement>(null);
  const taglineRef = useRef<HTMLParagraphElement>(null);

  // Initial load animation
  useEffect(() => {
    const ctx = gsap.context(() => {
      const tl = gsap.timeline({ delay: 0.2 });

      tl.fromTo(
        taglineRef.current,
        { opacity: 0, y: 16 },
        { opacity: 1, y: 0, duration: 0.5, ease: 'power2.out' }
      )
        .fromTo(
          headlineRef.current,
          { opacity: 0, y: 30 },
          { opacity: 1, y: 0, duration: 0.7, ease: 'power2.out' },
          '-=0.2'
        )
        .fromTo(
          subheadRef.current,
          { opacity: 0, y: 20 },
          { opacity: 1, y: 0, duration: 0.5, ease: 'power2.out' },
          '-=0.3'
        )
        .fromTo(
          ctaRef.current,
          { opacity: 0, y: 16 },
          { opacity: 1, y: 0, duration: 0.4, ease: 'power2.out' },
          '-=0.2'
        )
        .fromTo(
          [cardARef.current, cardBRef.current, cardCRef.current],
          { opacity: 0, scale: 0.9, y: -30 },
          { opacity: 1, scale: 1, y: 0, duration: 0.6, stagger: 0.1, ease: 'power2.out' },
          '-=0.3'
        );
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  // Scroll-driven animation
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
          onLeaveBack: () => {
            gsap.set([taglineRef.current, headlineRef.current, subheadRef.current, ctaRef.current], {
              opacity: 1,
              y: 0,
            });
            gsap.set([cardARef.current, cardBRef.current, cardCRef.current], {
              opacity: 1,
              scale: 1,
              x: 0,
              y: 0,
            });
          },
        },
      });

      // Exit animations (70-100%)
      scrollTl
        .fromTo(
          [taglineRef.current, headlineRef.current, subheadRef.current, ctaRef.current],
          { y: 0, opacity: 1 },
          { y: '-14vh', opacity: 0, ease: 'power2.in' },
          0.7
        )
        .fromTo(
          cardARef.current,
          { x: 0, opacity: 1 },
          { x: '-8vw', opacity: 0, ease: 'power2.in' },
          0.7
        )
        .fromTo(
          cardBRef.current,
          { x: 0, opacity: 1 },
          { x: '8vw', opacity: 0, ease: 'power2.in' },
          0.7
        )
        .fromTo(
          cardCRef.current,
          { y: 0, opacity: 1 },
          { y: '8vh', opacity: 0, ease: 'power2.in' },
          0.7
        );
    }, section);

    return () => ctx.revert();
  }, []);

  const isRequestingCompanion = companionStatus === 'requesting-permission';
  const isCompanionActive = companionStatus === 'active';
  const isDemoOnlyMode = experienceMode === 'demo-only';
  const tryClickyLabel = isRequestingCompanion
    ? 'Starting Clicky...'
    : isCompanionActive && experienceMode === 'mic-only'
    ? 'Upgrade Clicky'
    : isDemoOnlyMode
    ? 'Enable live Clicky'
    : 'Try Clicky';

  return (
    <section
      ref={sectionRef}
      id="hero-section"
      className="relative w-full h-screen bg-warm overflow-hidden z-10"
    >
      {/* Cursor Companion - rendered inside section for DOM stability */}
      <CursorCompanion />
        {/* Decorative UI Cards - macOS Style Mockups */}
        <div
          ref={cardARef}
          data-card="A"
          className="absolute hidden rounded-xl shadow-elegant overflow-hidden bg-white/88 backdrop-blur-xl border border-[#DDE8EE]/80 hero-float-slow md:block"
          style={{
            left: '5vw',
            top: '8vh',
            width: '16vw',
            minWidth: '180px',
            maxWidth: '280px',
          }}
        >
          {/* macOS Window Chrome */}
          <div className="flex items-center gap-2 px-4 py-3 bg-gradient-to-b from-[#FAFCFF] to-[#EAF8FF] border-b border-[#DDE8EE]/70">
            <div className="w-3 h-3 rounded-full bg-red-400/80" />
            <div className="w-3 h-3 rounded-full bg-yellow-400/80" />
            <div className="w-3 h-3 rounded-full bg-[#4FE7EE]/80" />
          </div>
          {/* Mock Content - Figma-style interface */}
          <div className="p-4 space-y-3">
            <div className="flex gap-2">
              <div className="w-8 h-8 rounded-lg bg-[#EDF1FF] flex items-center justify-center">
                <div className="w-4 h-4 rounded-sm bg-[#8EA2FF]" />
              </div>
              <div className="flex-1 space-y-1.5">
                <div className="h-2.5 bg-gray-200 rounded-full w-3/4" />
                <div className="h-2 bg-gray-100 rounded-full w-1/2" />
              </div>
            </div>
            <div className="grid grid-cols-3 gap-2 pt-2">
              <div className="aspect-square rounded-lg bg-gradient-to-br from-[#EDF1FF] to-[#FFF1F6] border border-[#DDE8EE]" />
              <div className="aspect-square rounded-lg bg-gradient-to-br from-[#EAF8FF] to-[#D9FEFF] border border-[#A9D6EB]/60" />
              <div className="aspect-square rounded-lg bg-gradient-to-br from-[#FAFCFF] to-[#EAF8FF] border border-[#DDE8EE]" />
            </div>
          </div>
        </div>

        <div
          ref={cardBRef}
          data-card="B"
          className="absolute hidden rounded-xl shadow-elegant overflow-hidden bg-white/88 backdrop-blur-xl border border-[#DDE8EE]/80 hero-float md:block"
          style={{
            right: '5vw',
            top: '10vh',
            width: '18vw',
            minWidth: '200px',
            maxWidth: '300px',
          }}
        >
          {/* macOS Window Chrome */}
          <div className="flex items-center gap-2 px-4 py-3 bg-gradient-to-b from-[#FAFCFF] to-[#EAF8FF] border-b border-[#DDE8EE]/70">
            <div className="w-3 h-3 rounded-full bg-red-400/80" />
            <div className="w-3 h-3 rounded-full bg-yellow-400/80" />
            <div className="w-3 h-3 rounded-full bg-[#4FE7EE]/80" />
            <div className="flex-1 text-center">
              <span className="text-[10px] text-gray-400 font-medium">Settings</span>
            </div>
          </div>
          {/* Mock Content - Settings Panel */}
          <div className="p-4 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-6 h-6 rounded-md bg-[#EAF8FF]" />
                <div className="h-2 bg-gray-200 rounded-full w-16" />
              </div>
              <div className="w-8 h-4 rounded-full bg-[#3478F6]" />
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-6 h-6 rounded-md bg-[#D9FEFF]" />
                <div className="h-2 bg-gray-200 rounded-full w-20" />
              </div>
              <div className="w-8 h-4 rounded-full bg-[#4FE7EE]" />
            </div>
            <div className="pt-2 border-t border-gray-100">
              <div className="h-2 bg-gray-200 rounded-full w-full mb-2" />
              <div className="h-1.5 bg-gray-100 rounded-full w-2/3" />
            </div>
          </div>
        </div>

        <div
          ref={cardCRef}
          data-card="C"
          className="absolute hidden rounded-xl shadow-elegant overflow-hidden bg-white/88 backdrop-blur-xl border border-[#DDE8EE]/80 hero-float-reverse md:block"
          style={{
            left: '6vw',
            bottom: '12vh',
            width: '14vw',
            minWidth: '160px',
            maxWidth: '240px',
          }}
        >
          {/* macOS Window Chrome */}
          <div className="flex items-center gap-2 px-4 py-3 bg-gradient-to-b from-[#FAFCFF] to-[#EAF8FF] border-b border-[#DDE8EE]/70">
            <div className="w-3 h-3 rounded-full bg-red-400/80" />
            <div className="w-3 h-3 rounded-full bg-yellow-400/80" />
            <div className="w-3 h-3 rounded-full bg-[#4FE7EE]/80" />
          </div>
          {/* Mock Content - Code Editor */}
          <div className="p-3 space-y-2">
            <div className="flex gap-1.5">
              <div className="w-2 h-2 rounded-full bg-[#8EA2FF] mt-1.5" />
              <div className="flex-1 space-y-1">
                <div className="h-1.5 bg-[#D8DFFF] rounded-full w-24" />
                <div className="h-1.5 bg-gray-200 rounded-full w-32" />
                <div className="h-1.5 bg-gray-200 rounded-full w-20" />
              </div>
            </div>
            <div className="flex gap-1.5">
              <div className="w-2 h-2 rounded-full bg-[#3478F6] mt-1.5" />
              <div className="flex-1 space-y-1">
                <div className="h-1.5 bg-[#A9D6EB] rounded-full w-28" />
                <div className="h-1.5 bg-gray-200 rounded-full w-16" />
              </div>
            </div>
          </div>
        </div>

        {/* Main Content */}
        <div className="absolute inset-0 flex flex-col items-center justify-center px-5 pt-20 pb-8">
          {/* Small tagline */}
          <p
            ref={taglineRef}
            className="text-muted-elegant text-xs tracking-[0.2em] uppercase mb-6 font-mono"
          >
            Voice-first. Screen-aware. Ready to guide.
          </p>

          {/* Headline with mixed styling */}
          <div ref={headlineRef} className="w-full max-w-[min(760px,calc(100vw-2rem))] text-center">
            <h1
              className="text-charcoal"
              style={{
                fontSize: 'clamp(34px, 6vw, 96px)',
                lineHeight: 1.05,
              }}
            >
              <span className="font-semibold">Clicky stays</span>
            </h1>
            <h1
              className="text-lavender font-serif-italic mt-1"
              style={{
                fontSize: 'clamp(34px, 6vw, 96px)',
                lineHeight: 1.05,
              }}
            >
              next to your cursor
            </h1>
          </div>

          <p
            ref={subheadRef}
            className="text-muted-elegant text-center mt-8 max-w-[260px] px-2 leading-relaxed sm:max-w-lg sm:px-6"
            style={{ fontSize: 'clamp(14px, 1.2vw, 17px)' }}
          >
            Ask out loud. Clicky understands what you are looking at, points to the
            right place, and helps you learn unfamiliar software without breaking your
            flow.
          </p>

          <div ref={ctaRef} className="mt-10 flex flex-col items-center gap-4">
            <div className="flex w-full flex-col items-center gap-3 sm:w-auto sm:flex-row">
              <a
                id="hero-download-cta"
                href={downloadUrl}
                data-companion-cta-id="hero-download-cta"
                data-companion-section-id="hero-section"
                data-companion-target-kind="cta"
                className="group relative flex w-[calc(100vw-4rem)] max-w-[280px] items-center justify-center gap-2.5 bg-charcoal text-warm px-5 py-4 rounded-full text-[15px] font-medium hover:bg-[#3478F6] transition-all shadow-xl shadow-[#3478F6]/15 hover:shadow-2xl hover:shadow-[#3478F6]/22 hover:scale-105 active:scale-95 overflow-hidden sm:w-auto sm:max-w-[340px] sm:gap-3 sm:px-8 sm:text-base"
              >
                <span className="absolute inset-0 bg-gradient-to-r from-[#4FE7EE] via-[#3478F6] to-[#FFB9CF] opacity-0 group-hover:opacity-24 transition-opacity duration-500" />
                <Sparkles size={18} className="relative z-10 group-hover:rotate-12 transition-transform duration-300" />
                <span className="relative z-10">Download for macOS</span>
                <Download size={18} className="relative z-10 group-hover:translate-y-0.5 transition-transform duration-300" />
              </a>

              <button
                id="hero-try-clicky-cta"
                type="button"
                data-companion-cta-id="hero-try-clicky-cta"
                data-companion-section-id="hero-section"
                data-companion-target-kind="cta"
                onClick={() => {
                  if (isCompanionActive) {
                    return;
                  }
                  setIsPermissionModalOpen(true);
                }}
                disabled={isRequestingCompanion}
                className="group flex w-[calc(100vw-4rem)] max-w-[280px] items-center justify-center gap-2.5 rounded-full border border-[#DDE8EE] bg-white/84 px-5 py-4 text-[15px] font-medium text-charcoal shadow-[0_12px_36px_rgba(52,120,246,0.10)] backdrop-blur-md transition-all hover:-translate-y-0.5 hover:border-[#A9D6EB] hover:shadow-[0_18px_42px_rgba(52,120,246,0.15)] disabled:cursor-default disabled:opacity-70 sm:w-auto sm:max-w-[340px] sm:gap-3 sm:px-7 sm:text-base"
              >
                {isRequestingCompanion ? (
                  <LoaderCircle size={18} className="animate-spin" />
                ) : (
                  <Mic size={18} className="transition-transform duration-300 group-hover:scale-110" />
                )}
                <span>{tryClickyLabel}</span>
              </button>
            </div>

            <p className="max-w-[260px] text-center text-muted-elegant text-xs sm:max-w-none">
              {isCompanionActive && experienceMode === 'mic-only'
                ? (
                  <>
                    Mic is on. Hold{' '}
                    <span className="inline-flex items-center gap-1 align-middle">
                      <kbd className="rounded-md border border-black/10 bg-white/80 px-2 py-1 font-mono text-[11px] text-charcoal shadow-sm">
                        Ctrl
                      </kbd>
                      <span>+</span>
                      <kbd className="rounded-md border border-black/10 bg-white/80 px-2 py-1 font-mono text-[11px] text-charcoal shadow-sm">
                        Option
                      </kbd>
                    </span>{' '}
                    to talk to Clicky
                  </>
                )
                : isDemoOnlyMode
                ? (
                  <>
                    Demo mode is on. Scroll into the next section to watch Clicky in action, or reopen{' '}
                    <span className="font-medium text-charcoal">Try Clicky</span>{' '}
                    anytime to enable live permissions.
                  </>
                )
                : (
                  <>
                    Best experience here: allow mic. Clicky already knows this page, and
                    the Mac app goes even further with live screen-aware guidance across
                    real software.
                  </>
                )}
            </p>

            {!isCompanionActive && !isDemoOnlyMode ? (
              <p className="max-w-[260px] text-center text-muted-elegant text-[11px] sm:max-w-none">
                Two-step live demo: 1. Choose permissions. 2. Hold{' '}
                <span className="inline-flex items-center gap-1 align-middle">
                  <kbd className="rounded-md border border-black/10 bg-white/80 px-2 py-1 font-mono text-[11px] text-charcoal shadow-sm">
                    Ctrl
                  </kbd>
                  <span>+</span>
                  <kbd className="rounded-md border border-black/10 bg-white/80 px-2 py-1 font-mono text-[11px] text-charcoal shadow-sm">
                    Option
                  </kbd>
                </span>{' '}
                and ask what you should do next.
              </p>
            ) : null}

            {companionErrorMessage ? (
              <p className="max-w-md text-center text-xs leading-5 text-rose-600">
                {companionErrorMessage}
              </p>
            ) : null}
          </div>
        </div>

        <Dialog open={isPermissionModalOpen} onOpenChange={setIsPermissionModalOpen}>
          <DialogContent className="max-w-xl rounded-[28px] border-white/70 bg-[#FAFCFF]/96 p-0 shadow-[0_24px_90px_rgba(52,120,246,0.18)] backdrop-blur-xl">
            <div className="overflow-hidden rounded-[28px]">
              <div className="border-b border-[#DDE8EE] bg-gradient-to-r from-white/92 via-[#EAF8FF] to-white/92 px-7 py-6">
                <DialogHeader className="gap-3 text-left">
                  <DialogTitle className="text-2xl font-semibold text-charcoal">
                    Give Clicky the right context
                  </DialogTitle>
                  <DialogDescription className="max-w-lg text-sm leading-6 text-muted-elegant">
                    For the best live website demo, let Clicky hear you. It already has a
                    semantic map of this page, so it can point you to the right controls
                    without browser screen sharing. If you would rather not, the site keeps
                    going and the next section switches into a built-in demo reel.
                  </DialogDescription>
                </DialogHeader>
              </div>

              <div className="space-y-4 px-7 py-6">
                <div className="grid gap-3">
                  <button
                    type="button"
                    disabled={isRequestingCompanion}
                    onClick={() => {
                      setIsPermissionModalOpen(false);
                      void startExperience({ mode: 'mic-only' });
                    }}
                    className="group flex w-full items-start justify-between rounded-[24px] border border-[#DDE8EE] bg-white/92 px-5 py-4 text-left shadow-[0_16px_42px_rgba(52,120,246,0.10)] transition-all hover:-translate-y-0.5 hover:border-[#A9D6EB] hover:shadow-[0_22px_46px_rgba(52,120,246,0.15)]"
                  >
                    <div className="flex gap-4">
                      <div className="mt-0.5 inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-[#3478F6] text-warm shadow-[0_10px_26px_rgba(52,120,246,0.26)]">
                        <Mic size={20} />
                      </div>
                      <div>
                        <p className="text-base font-semibold text-charcoal">
                          Start live Clicky
                        </p>
                        <p className="mt-1 text-sm leading-6 text-muted-elegant">
                          Turn on the mic and talk naturally. Clicky uses the website target
                          map to point at the right controls and answer in context.
                        </p>
                      </div>
                    </div>
                    <span className="rounded-full bg-[#EAF8FF] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.16em] text-[#3478F6]">
                      Recommended
                    </span>
                  </button>

                  <button
                    type="button"
                    disabled={isRequestingCompanion}
                    onClick={() => {
                      setIsPermissionModalOpen(false);
                      void startExperience({ mode: 'demo-only' });
                    }}
                    className="group flex w-full items-start gap-4 rounded-[24px] border border-[#DDE8EE] bg-white/88 px-5 py-4 text-left shadow-[0_12px_28px_rgba(52,120,246,0.08)] transition-all hover:-translate-y-0.5 hover:border-[#A9D6EB] hover:shadow-[0_18px_34px_rgba(52,120,246,0.12)]"
                  >
                    <div className="mt-0.5 inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-[#EAF8FF] text-charcoal">
                      <PlayCircle size={20} />
                    </div>
                    <div>
                        <p className="text-base font-semibold text-charcoal">
                          Watch the demo first
                        </p>
                        <p className="mt-1 text-sm leading-6 text-muted-elegant">
                          No permissions yet. Keep scrolling and the next section will show a
                          permission-free Clicky demo reel instead.
                        </p>
                    </div>
                  </button>
                </div>

                <p className="px-1 text-xs leading-5 text-muted-elegant">
                  This web version uses semantic website targets instead of browser screen
                  share, so the live path only needs microphone permission.
                </p>
              </div>
            </div>
          </DialogContent>
        </Dialog>
    </section>
  );
}

export default HeroSection;
