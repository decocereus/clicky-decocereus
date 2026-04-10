import { useEffect, useRef, useLayoutEffect } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { CursorCompanion } from '../components/CursorCompanion';
import { Download, Sparkles } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

export function HeroSection() {
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
          className="absolute rounded-xl shadow-elegant overflow-hidden bg-white/90 backdrop-blur-sm border border-white/50 hero-float-slow"
          style={{
            left: '5vw',
            top: '8vh',
            width: '16vw',
            minWidth: '180px',
            maxWidth: '280px',
          }}
        >
          {/* macOS Window Chrome */}
          <div className="flex items-center gap-2 px-4 py-3 bg-gradient-to-b from-gray-50 to-gray-100 border-b border-gray-200/50">
            <div className="w-3 h-3 rounded-full bg-red-400/80" />
            <div className="w-3 h-3 rounded-full bg-yellow-400/80" />
            <div className="w-3 h-3 rounded-full bg-green-400/80" />
          </div>
          {/* Mock Content - Figma-style interface */}
          <div className="p-4 space-y-3">
            <div className="flex gap-2">
              <div className="w-8 h-8 rounded-lg bg-purple-100 flex items-center justify-center">
                <div className="w-4 h-4 rounded-sm bg-purple-400" />
              </div>
              <div className="flex-1 space-y-1.5">
                <div className="h-2.5 bg-gray-200 rounded-full w-3/4" />
                <div className="h-2 bg-gray-100 rounded-full w-1/2" />
              </div>
            </div>
            <div className="grid grid-cols-3 gap-2 pt-2">
              <div className="aspect-square rounded-lg bg-gradient-to-br from-purple-50 to-pink-50 border border-purple-100" />
              <div className="aspect-square rounded-lg bg-gradient-to-br from-blue-50 to-cyan-50 border border-blue-100" />
              <div className="aspect-square rounded-lg bg-gradient-to-br from-orange-50 to-amber-50 border border-orange-100" />
            </div>
          </div>
        </div>

        <div
          ref={cardBRef}
          data-card="B"
          className="absolute rounded-xl shadow-elegant overflow-hidden bg-white/90 backdrop-blur-sm border border-white/50 hero-float"
          style={{
            right: '5vw',
            top: '10vh',
            width: '18vw',
            minWidth: '200px',
            maxWidth: '300px',
          }}
        >
          {/* macOS Window Chrome */}
          <div className="flex items-center gap-2 px-4 py-3 bg-gradient-to-b from-gray-50 to-gray-100 border-b border-gray-200/50">
            <div className="w-3 h-3 rounded-full bg-red-400/80" />
            <div className="w-3 h-3 rounded-full bg-yellow-400/80" />
            <div className="w-3 h-3 rounded-full bg-green-400/80" />
            <div className="flex-1 text-center">
              <span className="text-[10px] text-gray-400 font-medium">Settings</span>
            </div>
          </div>
          {/* Mock Content - Settings Panel */}
          <div className="p-4 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-6 h-6 rounded-md bg-blue-100" />
                <div className="h-2 bg-gray-200 rounded-full w-16" />
              </div>
              <div className="w-8 h-4 rounded-full bg-blue-400" />
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-6 h-6 rounded-md bg-green-100" />
                <div className="h-2 bg-gray-200 rounded-full w-20" />
              </div>
              <div className="w-8 h-4 rounded-full bg-green-400" />
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
          className="absolute rounded-xl shadow-elegant overflow-hidden bg-white/90 backdrop-blur-sm border border-white/50 hero-float-reverse"
          style={{
            left: '6vw',
            bottom: '12vh',
            width: '14vw',
            minWidth: '160px',
            maxWidth: '240px',
          }}
        >
          {/* macOS Window Chrome */}
          <div className="flex items-center gap-2 px-4 py-3 bg-gradient-to-b from-gray-50 to-gray-100 border-b border-gray-200/50">
            <div className="w-3 h-3 rounded-full bg-red-400/80" />
            <div className="w-3 h-3 rounded-full bg-yellow-400/80" />
            <div className="w-3 h-3 rounded-full bg-green-400/80" />
          </div>
          {/* Mock Content - Code Editor */}
          <div className="p-3 space-y-2">
            <div className="flex gap-1.5">
              <div className="w-2 h-2 rounded-full bg-purple-400 mt-1.5" />
              <div className="flex-1 space-y-1">
                <div className="h-1.5 bg-purple-200 rounded-full w-24" />
                <div className="h-1.5 bg-gray-200 rounded-full w-32" />
                <div className="h-1.5 bg-gray-200 rounded-full w-20" />
              </div>
            </div>
            <div className="flex gap-1.5">
              <div className="w-2 h-2 rounded-full bg-blue-400 mt-1.5" />
              <div className="flex-1 space-y-1">
                <div className="h-1.5 bg-blue-200 rounded-full w-28" />
                <div className="h-1.5 bg-gray-200 rounded-full w-16" />
              </div>
            </div>
          </div>
        </div>

        {/* Main Content */}
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          {/* Small tagline */}
          <p
            ref={taglineRef}
            className="text-muted-elegant text-xs tracking-[0.2em] uppercase mb-6 font-mono"
          >
            An unexpectedly conscious AI companion
          </p>

          {/* Headline with mixed styling */}
          <div ref={headlineRef} className="text-center">
            <h1
              className="text-charcoal"
              style={{
                fontSize: 'clamp(48px, 6vw, 96px)',
                lineHeight: 1.05,
              }}
            >
              <span className="font-semibold">Soft.</span>{' '}
              <span className="font-semibold">Fluid.</span>
            </h1>
            <h1
              className="text-lavender font-serif-italic mt-1"
              style={{
                fontSize: 'clamp(48px, 6vw, 96px)',
                lineHeight: 1.05,
              }}
            >
              Intuitive.
            </h1>
          </div>

          <p
            ref={subheadRef}
            className="text-muted-elegant text-center mt-8 max-w-lg px-6 leading-relaxed"
            style={{ fontSize: 'clamp(14px, 1.2vw, 17px)' }}
          >
            Clicky is an organic layer of intelligence that flows through your software, 
            anticipating your needs before they become tasks.
          </p>

          <div ref={ctaRef} className="mt-10">
            <button className="group relative flex items-center gap-3 bg-charcoal text-warm px-8 py-4 rounded-full text-base font-medium hover:bg-charcoal/90 transition-all shadow-xl hover:shadow-2xl hover:scale-105 active:scale-95 overflow-hidden">
              {/* Animated gradient background */}
              <span className="absolute inset-0 bg-gradient-to-r from-lavender via-charcoal to-lavender opacity-0 group-hover:opacity-20 transition-opacity duration-500" />
              
              {/* Sparkle icon */}
              <Sparkles size={18} className="relative z-10 group-hover:rotate-12 transition-transform duration-300" />
              
              <span className="relative z-10">Download for macOS</span>
              
              {/* Download icon */}
              <Download size={18} className="relative z-10 group-hover:translate-y-0.5 transition-transform duration-300" />
            </button>
            
            {/* Subtle tag below button */}
            <p className="text-center text-muted-elegant text-xs mt-3">
              Free 14-day trial • No credit card required
            </p>
          </div>
        </div>
    </section>
  );
}

export default HeroSection;
