import { useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { NativeAuthPage } from './components/NativeAuthPage';
import { Navigation } from './components/Navigation';
import { HeroSection } from './sections/HeroSection';
import { FeatureSection } from './sections/FeatureSection';
import { PricingSection } from './sections/PricingSection';
import { FooterSection } from './sections/FooterSection';
import './App.css';

gsap.registerPlugin(ScrollTrigger);

function LandingPage() {
  const mainRef = useRef<HTMLDivElement>(null);
  const snapTriggerRef = useRef<ScrollTrigger | null>(null);

  useEffect(() => {
    // Wait for all ScrollTriggers to be created
    const setupSnap = () => {
      // Get all pinned ScrollTriggers and sort by start position
      const pinned = ScrollTrigger.getAll()
        .filter((st) => st.vars.pin)
        .sort((a, b) => a.start - b.start);

      const maxScroll = ScrollTrigger.maxScroll(window);
      if (!maxScroll || pinned.length === 0) return;

      // Build ranges and snap targets from pinned sections
      const pinnedRanges = pinned.map((st) => ({
        start: st.start / maxScroll,
        end: (st.end ?? st.start) / maxScroll,
        center:
          (st.start + ((st.end ?? st.start) - st.start) * 0.5) / maxScroll,
      }));

      // Create global snap
      snapTriggerRef.current = ScrollTrigger.create({
        snap: {
          snapTo: (value: number) => {
            // Check if within any pinned range (allow small buffer)
            const inPinned = pinnedRanges.some(
              (r) => value >= r.start - 0.02 && value <= r.end + 0.02
            );
            if (!inPinned) return value; // Flowing section: free scroll

            // Find nearest pinned center
            const target = pinnedRanges.reduce(
              (closest, r) =>
                Math.abs(r.center - value) < Math.abs(closest - value)
                  ? r.center
                  : closest,
              pinnedRanges[0]?.center ?? 0
            );
            return target;
          },
          duration: { min: 0.15, max: 0.35 },
          delay: 0,
          ease: 'power2.out',
        },
      });
    };

    // Delay to ensure all section ScrollTriggers are created
    const timer = setTimeout(setupSnap, 500);

    return () => {
      clearTimeout(timer);
      if (snapTriggerRef.current) {
        snapTriggerRef.current.kill();
      }
    };
  }, []);

  // Cleanup all ScrollTriggers on unmount
  useEffect(() => {
    return () => {
      ScrollTrigger.getAll().forEach((st) => st.kill());
    };
  }, []);

  return (
    <div ref={mainRef} className="relative">
      <Navigation />

      <main className="relative">
        {/* Section 1: Hero - z-10 */}
        <HeroSection />

        {/* Section 2: Clicky sees your screen - z-20 */}
        <FeatureSection
          id="sees-screen"
          headline="Clicky sees"
          headlineItalic="your screen"
          bubbleText="I can see that!"
          imageSrc="/screen_design_tool.jpg"
          imageAlt="Design tool interface"
          mascotPosition="top-right"
          zIndex={20}
          entranceDirection="bottom"
          exitDirection="left"
          bgColor="warm"
        />

        {/* Section 3: Clicky points the way - z-30 */}
        <FeatureSection
          id="points-way"
          headline="Clicky points"
          headlineItalic="the way"
          bubbleText="Click this!"
          imageSrc="/screen_settings_panel.jpg"
          imageAlt="Settings panel interface"
          mascotPosition="top-left"
          zIndex={30}
          entranceDirection="right"
          exitDirection="bottom"
          bgColor="lavender"
        />

        {/* Section 4: Clicky knows your apps - z-40 */}
        <FeatureSection
          id="knows-apps"
          headline="Clicky knows"
          headlineItalic="your apps"
          bubbleText="I know Photoshop!"
          imageSrc="/screen_creative_app.jpg"
          imageAlt="Creative software interface"
          mascotPosition="top-right"
          zIndex={40}
          entranceDirection="bottom"
          exitDirection="right"
          bgColor="warm"
        />

        {/* Section 5: Clicky learns from video - z-50 */}
        <FeatureSection
          id="learns-video"
          headline="Clicky learns"
          headlineItalic="from video"
          bubbleText="I'll handle it!"
          imageSrc="/screen_youtube.jpg"
          imageAlt="YouTube video page"
          mascotPosition="bottom-right"
          zIndex={50}
          entranceDirection="left"
          exitDirection="top"
          bgColor="sage"
        />

        {/* Section 6: Clicky can be anything - z-60 */}
        <FeatureSection
          id="can-be-anything"
          headline="Clicky can be"
          headlineItalic="anything"
          bubbleText="What's next?"
          imageSrc="/screen_personality_picker.jpg"
          imageAlt="Personality picker interface"
          mascotPosition="bottom-left"
          zIndex={60}
          entranceDirection="bottom"
          exitDirection="left"
          bgColor="rose"
        />

        {/* Section 7: Clicky repeats workflows - z-70 */}
        <FeatureSection
          id="repeats-workflows"
          headline="Clicky repeats"
          headlineItalic="workflows"
          bubbleText="On it!"
          imageSrc="/screen_workflow_builder.jpg"
          imageAlt="Workflow builder interface"
          mascotPosition="top-right"
          zIndex={70}
          entranceDirection="right"
          exitDirection="bottom"
          bgColor="warm"
        />

        {/* Section 8: Pricing - z-80 (flowing) */}
        <PricingSection />

        {/* Section 9: Footer - z-90 (flowing) */}
        <FooterSection />
      </main>
    </div>
  );
}

function App() {
  const pathname = typeof window === 'undefined' ? '/' : window.location.pathname;

  if (pathname === '/auth/native') {
    return <NativeAuthPage />;
  }

  return <LandingPage />;
}

export default App;
