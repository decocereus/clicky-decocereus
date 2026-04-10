import { useRef, useLayoutEffect } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

export function FooterSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const mascotRef = useRef<HTMLDivElement>(null);
  const bubbleRef = useRef<HTMLDivElement>(null);
  const linksRef = useRef<HTMLDivElement>(null);

  useLayoutEffect(() => {
    const section = sectionRef.current;
    if (!section) return;

    const ctx = gsap.context(() => {
      // Mascot animation
      gsap.fromTo(
        mascotRef.current,
        { scale: 0.85, opacity: 0 },
        {
          scale: 1,
          opacity: 1,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: section,
            start: 'top 85%',
            end: 'top 55%',
            scrub: 0.5,
          },
        }
      );

      // Bubble animation
      gsap.fromTo(
        bubbleRef.current,
        { y: -16, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: section,
            start: 'top 80%',
            end: 'top 60%',
            scrub: 0.5,
          },
        }
      );

      // Links animation
      gsap.fromTo(
        linksRef.current,
        { y: 10, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: linksRef.current,
            start: 'top 95%',
            end: 'top 80%',
            scrub: 0.5,
          },
        }
      );
    }, section);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      className="relative w-full h-screen bg-sage overflow-hidden z-90"
    >
      {/* Speech Bubble */}
      <div
        ref={bubbleRef}
        className="absolute"
        style={{ left: '50%', top: '18%', transform: 'translateX(-50%)' }}
      >
        <div className="bg-white rounded-2xl px-6 py-3 shadow-elegant">
          <p className="text-lg font-serif-italic text-charcoal">See you around!</p>
          <div
            className="absolute w-0 h-0"
            style={{
              top: '100%',
              left: '50%',
              transform: 'translateX(-50%)',
              borderLeft: '10px solid transparent',
              borderRight: '10px solid transparent',
              borderTop: '12px solid white',
            }}
          />
        </div>
      </div>

      {/* Large Mascot */}
      <div
        ref={mascotRef}
        className="absolute"
        style={{
          left: '50%',
          top: '46%',
          transform: 'translate(-50%, -50%)',
        }}
      >
        <svg
          viewBox="0 0 52 52"
          width="100"
          height="100"
          className="drop-shadow-lg"
        >
          <path
            d="M26 4C26 4 8 18 8 32C8 41.941 16.059 50 26 50C35.941 50 44 41.941 44 32C44 18 26 4 26 4Z"
            fill="#7A9BC4"
          />
          <ellipse cx="20" cy="26" rx="5" ry="7" fill="white" opacity="0.9" />
          <circle cx="18" cy="23" r="2" fill="white" opacity="0.6" />
        </svg>
      </div>

      {/* Footer Links */}
      <div
        ref={linksRef}
        className="absolute bottom-8 left-1/2 -translate-x-1/2"
      >
        <div className="flex flex-wrap justify-center gap-6 md:gap-10 text-charcoal/60 text-sm">
          <span>© Clicky</span>
          <a href="#" className="hover:text-charcoal transition-colors">
            Privacy
          </a>
          <a href="#" className="hover:text-charcoal transition-colors">
            Terms
          </a>
          <a href="#" className="hover:text-charcoal transition-colors">
            Twitter
          </a>
          <a href="#" className="hover:text-charcoal transition-colors">
            Contact
          </a>
        </div>
      </div>
    </section>
  );
}

export default FooterSection;
