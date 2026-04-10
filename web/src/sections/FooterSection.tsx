import { useRef, useLayoutEffect, useState } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Twitter, Mail, Heart, ArrowUpRight } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

export function FooterSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const mascotRef = useRef<HTMLDivElement>(null);
  const bubbleRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const linksRef = useRef<HTMLDivElement>(null);
  const [isHovered, setIsHovered] = useState(false);

  useLayoutEffect(() => {
    const section = sectionRef.current;
    if (!section) return;

    const ctx = gsap.context(() => {
      // Mascot bounce in animation
      gsap.fromTo(
        mascotRef.current,
        { scale: 0.6, opacity: 0, y: 50 },
        {
          scale: 1,
          opacity: 1,
          y: 0,
          ease: 'back.out(1.4)',
          scrollTrigger: {
            trigger: section,
            start: 'top 80%',
            end: 'top 50%',
            scrub: 0.5,
          },
        }
      );

      // Bubble pop in
      gsap.fromTo(
        bubbleRef.current,
        { scale: 0.8, opacity: 0, y: 20 },
        {
          scale: 1,
          opacity: 1,
          y: 0,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: section,
            start: 'top 75%',
            end: 'top 55%',
            scrub: 0.5,
          },
        }
      );

      // Content fade in
      gsap.fromTo(
        contentRef.current,
        { y: 30, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: section,
            start: 'top 70%',
            end: 'top 50%',
            scrub: 0.5,
          },
        }
      );

      // Links stagger in
      const linkItems = linksRef.current?.querySelectorAll('.footer-link');
      if (linkItems) {
        gsap.fromTo(
          linkItems,
          { y: 15, opacity: 0 },
          {
            y: 0,
            opacity: 1,
            stagger: 0.05,
            ease: 'power2.out',
            scrollTrigger: {
              trigger: linksRef.current,
              start: 'top 95%',
              end: 'top 80%',
              scrub: 0.5,
            },
          }
        );
      }
    }, section);

    return () => ctx.revert();
  }, []);

  // Gentle float animation for mascot
  useLayoutEffect(() => {
    if (!mascotRef.current) return;
    
    const floatAnim = gsap.to(mascotRef.current, {
      y: -8,
      duration: 2,
      ease: 'power1.inOut',
      yoyo: true,
      repeat: -1,
    });

    return () => {
      floatAnim.kill();
    };
  }, []);

  const socialLinks = [
    { icon: Twitter, label: 'Twitter', href: '#' },
    { icon: Mail, label: 'Email', href: 'mailto:hello@clicky.dev' },
  ];

  const footerLinks = [
    { label: 'Privacy', href: '#' },
    { label: 'Terms', href: '#' },
    { label: 'Support', href: '#' },
  ];

  return (
    <section
      ref={sectionRef}
      id="footer"
      className="relative w-full min-h-screen bg-sage overflow-hidden z-90"
    >
      {/* Background decorative elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-white/5 rounded-full blur-3xl" />
        <div className="absolute bottom-1/3 right-1/4 w-64 h-64 bg-lavender/10 rounded-full blur-2xl" />
      </div>

      {/* Main content */}
      <div className="relative z-10 flex flex-col items-center justify-center min-h-screen px-6 py-20">
        
        {/* Mascot with speech bubble */}
        <div className="relative mb-8">
          {/* Speech Bubble */}
          <div
            ref={bubbleRef}
            className="absolute left-1/2 -translate-x-1/2 bottom-full mb-4"
          >
            <div className="bg-white rounded-2xl px-6 py-3 shadow-elegant whitespace-nowrap">
              <p className="text-lg font-serif-italic text-charcoal">See you around!</p>
              <div
                className="absolute w-0 h-0 left-1/2 -translate-x-1/2"
                style={{
                  top: '100%',
                  borderLeft: '10px solid transparent',
                  borderRight: '10px solid transparent',
                  borderTop: '12px solid white',
                }}
              />
            </div>
          </div>

          {/* Clicky Mascot - Interactive */}
          <div
            ref={mascotRef}
            className="relative cursor-pointer transition-transform duration-300"
            onMouseEnter={() => setIsHovered(true)}
            onMouseLeave={() => setIsHovered(false)}
            style={{
              transform: isHovered ? 'scale(1.1)' : 'scale(1)',
            }}
          >
            <svg
              viewBox="0 0 52 52"
              width={isHovered ? 120 : 100}
              height={isHovered ? 120 : 100}
              className="drop-shadow-xl transition-all duration-300"
            >
              <path
                d="M26 4C26 4 8 18 8 32C8 41.941 16.059 50 26 50C35.941 50 44 41.941 44 32C44 18 26 4 26 4Z"
                fill="#7A9BC4"
                className="transition-all duration-300"
                style={{
                  fill: isHovered ? '#8BAAD4' : '#7A9BC4',
                }}
              />
              <ellipse cx="20" cy="26" rx="5" ry="7" fill="white" opacity="0.9" />
              <circle cx="18" cy="23" r="2" fill="white" opacity="0.6" />
              {/* Happy expression when hovered */}
              {isHovered && (
                <>
                  <ellipse cx="32" cy="26" rx="5" ry="7" fill="white" opacity="0.9" />
                  <circle cx="34" cy="23" r="2" fill="white" opacity="0.6" />
                  <path
                    d="M22 36 Q26 40 30 36"
                    stroke="white"
                    strokeWidth="2"
                    fill="none"
                    strokeLinecap="round"
                    opacity="0.8"
                  />
                </>
              )}
            </svg>
            
            {/* Sparkle effects on hover */}
            {isHovered && (
              <>
                <div className="absolute -top-2 -right-2 w-3 h-3 bg-yellow-300 rounded-full animate-pulse" />
                <div className="absolute -bottom-1 -left-3 w-2 h-2 bg-white rounded-full animate-pulse" style={{ animationDelay: '0.2s' }} />
              </>
            )}
          </div>
        </div>

        {/* Brand and tagline */}
        <div ref={contentRef} className="text-center mb-12">
          <h3 className="text-3xl font-semibold text-charcoal mb-3">Clicky</h3>
          <p className="text-muted-elegant text-sm max-w-xs mx-auto leading-relaxed">
            Your AI companion that sees, understands, and helps you navigate any software.
          </p>
        </div>

        {/* Social Links */}
        <div className="flex items-center gap-4 mb-12">
          {socialLinks.map((link) => (
            <a
              key={link.label}
              href={link.href}
              className="group flex items-center justify-center w-12 h-12 rounded-full bg-white/80 hover:bg-white shadow-elegant hover:shadow-lg transition-all duration-300"
              aria-label={link.label}
            >
              <link.icon size={20} className="text-charcoal/70 group-hover:text-charcoal transition-colors" />
            </a>
          ))}
        </div>

        {/* Download CTA */}
        <a
          id="footer-download-cta"
          data-companion-cta-id="footer-download-cta"
          data-companion-section-id="footer"
          data-companion-target-kind="cta"
          href="#"
          className="group flex items-center gap-2 bg-charcoal text-warm px-6 py-3 rounded-full font-medium text-sm hover:bg-charcoal/90 transition-all shadow-lg hover:shadow-xl mb-16"
        >
          <span>Download for macOS</span>
          <ArrowUpRight size={16} className="group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform" />
        </a>

        {/* Footer Links */}
        <div
          ref={linksRef}
          className="flex flex-wrap justify-center items-center gap-6 md:gap-8 text-sm"
        >
          <span className="footer-link text-charcoal/50">© {new Date().getFullYear()} Clicky</span>
          <div className="flex items-center gap-6">
            {footerLinks.map((link) => (
              <a
                key={link.label}
                href={link.href}
                className="footer-link text-charcoal/60 hover:text-charcoal transition-colors"
              >
                {link.label}
              </a>
            ))}
          </div>
        </div>

        {/* Made with love */}
        <div className="mt-8 flex items-center gap-1.5 text-xs text-charcoal/40">
          <span>Made with</span>
          <Heart size={12} className="text-rose-400 fill-rose-400" />
          <span>by the Clicky team</span>
        </div>
      </div>
    </section>
  );
}

export default FooterSection;
