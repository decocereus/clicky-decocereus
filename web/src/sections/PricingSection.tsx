import { useRef, useLayoutEffect } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Check, CreditCard, X, Mail } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

export function PricingSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const headingRef = useRef<HTMLDivElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);
  const trustRef = useRef<HTMLDivElement>(null);

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

      // Trust items animation
      const trustItems = trustRef.current?.children;
      if (trustItems) {
        gsap.fromTo(
          trustItems,
          { y: 16, opacity: 0 },
          {
            y: 0,
            opacity: 1,
            stagger: 0.08,
            ease: 'power2.out',
            scrollTrigger: {
              trigger: trustRef.current,
              start: 'top 65%',
              end: 'top 45%',
              scrub: 0.5,
            },
          }
        );
      }
    }, section);

    return () => ctx.revert();
  }, []);

  const features = [
    'Unlimited screen chats',
    'Workflow recording & replay',
    'YouTube → execution plan',
    'Custom personality & voice',
  ];

  return (
    <section
      ref={sectionRef}
      id="pricing"
      className="relative w-full min-h-screen bg-warm py-24 z-80"
    >
      <div className="max-w-4xl mx-auto px-6">
        {/* Heading */}
        <div ref={headingRef} className="text-center mb-16">
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
            <span className="font-semibold">Start for free.</span>{' '}
            <span className="font-serif-italic text-lavender">Upgrade when you're ready.</span>
          </h2>
        </div>

        {/* Pricing Card */}
        <div
          ref={cardRef}
          className="bg-white rounded-3xl shadow-elegant p-10 md:p-14"
        >
          <div className="text-center mb-10">
            <div className="flex items-center justify-center gap-3 mb-3">
              <span className="text-xl text-muted-elegant line-through font-light">$59</span>
              <span
                className="text-charcoal font-semibold"
                style={{ fontSize: 'clamp(44px, 5vw, 64px)' }}
              >
                $49
              </span>
              <span className="text-muted-elegant text-base">/year</span>
            </div>
            <p className="text-muted-elegant">
              Pro plan — unlimited tasks, workflows, and priority support.
            </p>
          </div>

          <button className="w-full bg-charcoal text-warm py-4 rounded-full font-medium text-base hover:bg-lavender transition-colors shadow-lg mb-10">
            Download for macOS
          </button>

          {/* Features */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5 mb-10">
            {features.map((feature, index) => (
              <div key={index} className="flex items-center gap-3">
                <div className="w-5 h-5 rounded-full bg-sage/30 flex items-center justify-center flex-shrink-0">
                  <Check size={12} className="text-sage" />
                </div>
                <span className="text-charcoal text-sm">{feature}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Trust Row */}
        <div
          ref={trustRef}
          className="flex flex-wrap justify-center gap-8 mt-10"
        >
          <div className="flex items-center gap-2 text-muted-elegant">
            <CreditCard size={16} />
            <span className="text-sm">No credit card to start</span>
          </div>
          <div className="flex items-center gap-2 text-muted-elegant">
            <X size={16} />
            <span className="text-sm">Cancel anytime</span>
          </div>
          <div className="flex items-center gap-2 text-muted-elegant">
            <Mail size={16} />
            <span className="text-sm">Email support</span>
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
