import { useRef, useLayoutEffect } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Check, Sparkles, Shield, Zap, Download } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

export function PricingSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const headingRef = useRef<HTMLDivElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);
  const featuresRef = useRef<HTMLDivElement>(null);

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
    { icon: Zap, text: 'Unlimited screen conversations' },
    { icon: Sparkles, text: 'Workflow recording & replay' },
    { icon: Shield, text: 'YouTube → step-by-step automation' },
    { icon: Check, text: 'Custom personality & voice' },
    { icon: Check, text: 'Priority support via email' },
    { icon: Check, text: 'All future updates included' },
  ];

  return (
    <section
      ref={sectionRef}
      id="pricing"
      className="relative w-full min-h-screen bg-warm py-24 z-80"
    >
      <div className="max-w-4xl mx-auto px-6">
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
            <span className="font-serif-italic text-lavender">Everything included.</span>
          </h2>
        </div>

        {/* Pricing Card */}
        <div
          ref={cardRef}
          className="bg-white rounded-3xl shadow-elegant overflow-hidden"
        >
          {/* Popular Tag */}
          <div className="bg-charcoal py-2 px-4 text-center">
            <span className="text-warm text-xs font-medium tracking-wide flex items-center justify-center gap-1.5">
              <Sparkles size={12} />
              Welcome Pass — Limited Time Pricing
            </span>
          </div>

          <div className="p-10 md:p-14">
            {/* Price Section */}
            <div className="text-center mb-10">
              <div className="flex items-center justify-center gap-3 mb-2">
                <span className="text-xl text-muted-elegant line-through font-light">$79</span>
                <span
                  className="text-charcoal font-semibold"
                  style={{ fontSize: 'clamp(48px, 6vw, 72px)' }}
                >
                  $49
                </span>
                <span className="text-muted-elegant text-lg">/year</span>
              </div>
              <p className="text-sm text-muted-elegant">
                Early supporter price — lock in this rate forever
              </p>
            </div>

            {/* CTA Button */}
            <button
              id="pricing-download-cta"
              data-companion-cta-id="pricing-download-cta"
              data-companion-section-id="pricing"
              data-companion-target-kind="cta"
              className="w-full bg-charcoal text-warm py-4 rounded-full font-medium text-base hover:bg-lavender transition-all shadow-lg hover:shadow-xl flex items-center justify-center gap-2 mb-10 group"
            >
              <Download size={18} className="group-hover:translate-y-0.5 transition-transform" />
              Download for macOS
            </button>

            {/* Features Grid - Auto-sizing for content */}
            <div
              ref={featuresRef}
              className="grid grid-cols-1 sm:grid-cols-2 gap-3"
            >
              {features.map((feature, index) => (
                <div
                  key={index}
                  className="feature-item flex items-start gap-3 p-3 rounded-xl hover:bg-warm/50 transition-colors min-h-0"
                >
                  <div className="w-8 h-8 rounded-lg bg-sage/20 flex items-center justify-center flex-shrink-0">
                    <feature.icon size={16} className="text-sage" />
                  </div>
                  <span className="text-charcoal text-sm leading-snug pt-1">{feature.text}</span>
                </div>
              ))}
            </div>

            {/* Trust Row */}
            <div className="mt-10 pt-8 border-t border-gray-100">
              <div className="flex flex-wrap justify-center gap-8 text-muted-elegant text-sm">
                <span className="flex items-center gap-2">
                  <Shield size={14} />
                  14-day money-back guarantee
                </span>
                <span className="flex items-center gap-2">
                  <Zap size={14} />
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
