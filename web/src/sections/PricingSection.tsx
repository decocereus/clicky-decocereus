import { useRef, useLayoutEffect } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Check, Sparkles, Shield, Zap, Download, ArrowRight } from 'lucide-react';
import { getDownloadUrl } from '../lib/download';

gsap.registerPlugin(ScrollTrigger);

export function PricingSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const headingRef = useRef<HTMLDivElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);
  const featuresRef = useRef<HTMLDivElement>(null);
  const downloadUrl = getDownloadUrl();

  useLayoutEffect(() => {
    const section = sectionRef.current;
    if (!section) return;

    const ctx = gsap.context(() => {
      // Heading animation
      gsap.fromTo(
        headingRef.current,
        { y: 24, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: headingRef.current,
            start: 'top 80%',
            end: 'top 55%',
            scrub: 0.5,
          },
        }
      );

      // Card animation
      gsap.fromTo(
        cardRef.current,
        { y: 40, opacity: 0, scale: 0.98 },
        {
          y: 0,
          opacity: 1,
          scale: 1,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: cardRef.current,
            start: 'top 75%',
            end: 'top 50%',
            scrub: 0.5,
          },
        }
      );

      // Features animation
      const featureItems = featuresRef.current?.querySelectorAll('.feature-item');
      if (featureItems) {
        gsap.fromTo(
          featureItems,
          { y: 20, opacity: 0 },
          {
            y: 0,
            opacity: 1,
            stagger: 0.05,
            ease: 'power2.out',
            scrollTrigger: {
              trigger: featuresRef.current,
              start: 'top 70%',
              end: 'top 50%',
              scrub: 0.5,
            },
          }
        );
      }
    }, section);

    return () => ctx.revert();
  }, []);

  const features = [
    { icon: Zap, text: 'Unlimited guided conversations while you work' },
    { icon: Sparkles, text: 'Workflow capture and replay' },
    { icon: Shield, text: 'Tutorial videos turned into step-by-step guidance' },
    { icon: Check, text: 'Custom personality and voice' },
    { icon: Check, text: 'Priority support via email' },
    { icon: Check, text: 'All future updates included' },
  ];

  return (
    <section
      ref={sectionRef}
      id="pricing"
      className="relative w-full min-h-screen bg-warm py-24 z-80"
    >
      <div className="mx-auto max-w-6xl px-6">
        {/* Heading */}
        <div ref={headingRef} className="text-center mb-12">
          <p className="text-muted-elegant text-xs tracking-[0.2em] uppercase mb-4 font-mono">
            Simple, transparent pricing
          </p>
          <h2
            className="text-charcoal"
            style={{
              fontSize: 'clamp(36px, 4.5vw, 64px)',
              lineHeight: 1.15,
            }}
          >
            <span className="font-semibold">One plan.</span>{' '}
            <span className="font-serif-italic text-lavender">Keep Clicky with you.</span>
          </h2>
        </div>

        {/* Pricing band */}
        <div
          ref={cardRef}
          className="relative overflow-hidden border-y border-[#DDE8EE] bg-gradient-to-br from-[#FAFCFF] via-[#EAF8FF] to-[#F9F3F8] py-12 md:py-16"
        >
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_16%_20%,rgba(79,231,238,0.2),transparent_30%),radial-gradient(circle_at_88%_72%,rgba(255,185,207,0.22),transparent_34%)]" />
          <div className="relative grid gap-10 px-6 md:grid-cols-[0.9fr_1.1fr] md:px-12">
            <div className="flex flex-col justify-between gap-8">
              <div>
                <div className="mb-5 inline-flex items-center gap-2 rounded-full bg-charcoal px-3 py-1.5 text-xs font-medium tracking-wide text-white">
                  <Sparkles size={13} />
                  Welcome Pass
                </div>
                <div className="flex flex-wrap items-end gap-x-4 gap-y-2">
                  <span className="pb-3 text-2xl font-light text-muted-elegant line-through">
                    $79
                  </span>
                  <span
                    className="font-semibold leading-none text-charcoal"
                    style={{ fontSize: 'clamp(64px, 9vw, 112px)' }}
                  >
                    $49
                  </span>
                  <span className="pb-4 text-xl text-muted-elegant">/year</span>
                </div>
                <p className="mt-5 max-w-md text-base leading-7 text-muted-elegant">
                  Early supporter pricing for people who want Clicky beside them while they work.
                  Lock in the rate forever.
                </p>
              </div>

              <a
                id="pricing-download-cta"
                href={downloadUrl}
                data-companion-cta-id="pricing-download-cta"
                data-companion-section-id="pricing"
                data-companion-target-kind="cta"
                className="group inline-flex w-fit items-center justify-center gap-3 rounded-full bg-charcoal px-7 py-4 text-base font-medium text-warm shadow-lg shadow-[#3478F6]/15 transition-all hover:bg-[#3478F6] hover:shadow-xl"
              >
                <Download size={18} className="transition-transform group-hover:translate-y-0.5" />
                Download for macOS
                <ArrowRight size={18} className="transition-transform group-hover:translate-x-1" />
              </a>
            </div>

            <div className="space-y-8">
              <div
                ref={featuresRef}
                className="grid grid-cols-1 gap-x-8 gap-y-0 sm:grid-cols-2"
              >
                {features.map((feature, index) => (
                  <div
                    key={index}
                    className="feature-item flex items-start gap-3 border-t border-[#DDE8EE] py-5"
                  >
                    <div className="mt-0.5 flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-white/80">
                      <feature.icon size={16} className="text-[#3478F6]" />
                    </div>
                    <span className="pt-1 text-sm leading-6 text-charcoal">{feature.text}</span>
                  </div>
                ))}
              </div>

              <div
                className="grid gap-4 border-t border-[#DDE8EE] pt-6 text-sm text-muted-elegant sm:grid-cols-2"
              >
                <span className="flex items-center gap-2">
                  <Shield size={15} className="text-[#3478F6]" />
                  14-day money-back guarantee
                </span>
                <span className="flex items-center gap-2">
                  <Zap size={15} className="text-[#3478F6]" />
                  Instant digital delivery
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Secondary CTA */}
        <p className="text-center text-muted-elegant mt-10 text-sm">
          Questions?{' '}
          <a href="mailto:hello@clicky.dev" className="underline hover:text-charcoal transition-colors">
            hello@clicky.dev
          </a>
        </p>
      </div>
    </section>
  );
}

export default PricingSection;
