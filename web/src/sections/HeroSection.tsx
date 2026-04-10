import { useEffect, useRef, useLayoutEffect } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { ArrowDown } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

interface HeroSectionProps {
  onMascotEnter?: () => void;
}

export function HeroSection({ onMascotEnter }: HeroSectionProps) {
  const sectionRef = useRef<HTMLDivElement>(null);
  const headlineRef = useRef<HTMLDivElement>(null);
  const subheadRef = useRef<HTMLParagraphElement>(null);
  const ctaRef = useRef<HTMLDivElement>(null);
  const cardARef = useRef<HTMLDivElement>(null);
  const cardBRef = useRef<HTMLDivElement>(null);
  const cardCRef = useRef<HTMLDivElement>(null);
  const mascotRef = useRef<HTMLDivElement>(null);
  const bubbleRef = useRef<HTMLDivElement>(null);
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
        )
        .fromTo(
          mascotRef.current,
          { opacity: 0, x: 40, scale: 0.7 },
          { opacity: 1, x: 0, scale: 1, duration: 0.5, ease: 'back.out(1.5)' },
          '-=0.3'
        )
        .fromTo(
          bubbleRef.current,
          { opacity: 0, y: -16 },
          {
            opacity: 1,
            y: 0,
            duration: 0.35,
            ease: 'power2.out',
            onComplete: () => onMascotEnter?.(),
          },
          '-=0.2'
        );
    }, sectionRef);

    return () => ctx.revert();
  }, [onMascotEnter]);

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
            gsap.set(mascotRef.current, { opacity: 1, x: 0 });
            gsap.set(bubbleRef.current, { opacity: 1, y: 0 });
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
        )
        .fromTo(
          mascotRef.current,
          { x: 0, opacity: 1 },
          { x: '35vw', opacity: 0, ease: 'power2.in' },
          0.75
        )
        .fromTo(
          bubbleRef.current,
          { opacity: 1 },
          { opacity: 0, ease: 'power2.in' },
          0.7
        );
    }, section);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      className="relative w-full h-screen bg-warm overflow-hidden z-10"
    >
      {/* Decorative UI Cards */}
      <div
        ref={cardARef}
        className="absolute rounded-2xl shadow-elegant overflow-hidden"
        style={{
          left: '5vw',
          top: '8vh',
          width: '16vw',
          height: '20vh',
        }}
      >
        <img
          src="/hero_ui_card_a.jpg"
          alt="UI Preview"
          className="w-full h-full object-cover"
        />
      </div>

      <div
        ref={cardBRef}
        className="absolute rounded-2xl shadow-elegant overflow-hidden"
        style={{
          right: '5vw',
          top: '10vh',
          width: '18vw',
          height: '24vh',
        }}
      >
        <img
          src="/hero_ui_card_b.jpg"
          alt="Dashboard Preview"
          className="w-full h-full object-cover"
        />
      </div>

      <div
        ref={cardCRef}
        className="absolute rounded-2xl shadow-elegant overflow-hidden"
        style={{
          left: '6vw',
          bottom: '8vh',
          width: '14vw',
          height: '18vh',
        }}
      >
        <img
          src="/hero_ui_card_c.jpg"
          alt="Settings Preview"
          className="w-full h-full object-cover"
        />
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
          <button className="group flex items-center gap-2 text-charcoal text-sm font-medium hover:text-lavender transition-colors">
            <span>Explore the experience</span>
            <ArrowDown size={16} className="group-hover:translate-y-1 transition-transform" />
          </button>
        </div>
      </div>

      {/* Mascot */}
      <div
        ref={mascotRef}
        className="absolute"
        style={{ left: '65%', top: '48%' }}
      >
        {/* Speech Bubble */}
        <div
          ref={bubbleRef}
          className="absolute bottom-full left-1/2 -translate-x-1/2 mb-3"
        >
          <div className="bg-white rounded-2xl px-4 py-2.5 shadow-elegant whitespace-nowrap">
            <p className="text-sm text-charcoal">Hi, I'm Clicky!</p>
            <div 
              className="absolute top-full left-1/2 -translate-x-1/2 w-0 h-0"
              style={{
                borderLeft: '8px solid transparent',
                borderRight: '8px solid transparent',
                borderTop: '10px solid white',
              }}
            />
          </div>
        </div>

        {/* Clicky SVG - softer blue for light theme */}
        <svg viewBox="0 0 52 52" width="48" height="48" className="drop-shadow-md">
          <path
            d="M26 4C26 4 8 18 8 32C8 41.941 16.059 50 26 50C35.941 50 44 41.941 44 32C44 18 26 4 26 4Z"
            fill="#7A9BC4"
          />
          <ellipse cx="20" cy="26" rx="5" ry="7" fill="white" opacity="0.9" />
          <circle cx="18" cy="23" r="2" fill="white" opacity="0.6" />
        </svg>
      </div>
    </section>
  );
}

export default HeroSection;
