import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { NativeAuthPage } from './components/NativeAuthPage';
import { Navigation } from './components/Navigation';
import {
  WebCompanionExperienceProvider,
  useWebCompanionExperience,
} from './components/WebCompanionExperience';
import { HeroSection } from './sections/HeroSection';
import { FeatureSection } from './sections/FeatureSection';
import { PricingSection } from './sections/PricingSection';
import { FooterSection } from './sections/FooterSection';
import './App.css';
import { Agentation, type Annotation } from 'agentation';

gsap.registerPlugin(ScrollTrigger);

const AGENTATION_CALIBRATION_STORAGE_KEY = 'clicky:agentation-calibration:v1';

type CalibrationRecord = {
  accessibility?: string;
  boundingBox?: Annotation['boundingBox'];
  comment: string;
  cssClasses?: string;
  domId: string | null;
  matchedTargetId: string | null;
  element: string;
  elementPath: string;
  fullPath?: string;
  id: string;
  nearbyText?: string;
  reactComponents?: string;
  selectedText?: string;
  sourceFile?: string;
  timestamp: number;
  url?: string;
  x: number;
  y: number;
};

declare global {
  interface Window {
    __clickyAgentationCalibrationAnnotations?: CalibrationRecord[];
    __clickyExportCalibrationAnnotations?: () => CalibrationRecord[];
    __clickyClearCalibrationAnnotations?: () => void;
  }
}

function inferDomId(annotation: Annotation) {
  const candidates = [annotation.fullPath, annotation.elementPath, annotation.element];

  for (const candidate of candidates) {
    if (!candidate) {
      continue;
    }

    const idMatches = [...candidate.matchAll(/#([A-Za-z][\w:-]*)/g)];
    const lastMatch = idMatches.at(-1);
    if (lastMatch?.[1]) {
      return lastMatch[1];
    }
  }

  return null;
}

function inferMatchedTargetId(annotation: Annotation) {
  const normalizedComment = annotation.comment.trim();
  return normalizedComment || null;
}

function normalizeCalibrationRecord(annotation: Annotation): CalibrationRecord {
  return {
    accessibility: annotation.accessibility,
    boundingBox: annotation.boundingBox,
    comment: annotation.comment,
    cssClasses: annotation.cssClasses,
    domId: inferDomId(annotation),
    matchedTargetId: inferMatchedTargetId(annotation),
    element: annotation.element,
    elementPath: annotation.elementPath,
    fullPath: annotation.fullPath,
    id: annotation.id,
    nearbyText: annotation.nearbyText,
    reactComponents: annotation.reactComponents,
    selectedText: annotation.selectedText,
    sourceFile: annotation.sourceFile,
    timestamp: annotation.timestamp,
    url: annotation.url,
    x: annotation.x,
    y: annotation.y,
  };
}

function AgentationCalibrationBridge() {
  const [annotations, setAnnotations] = useState<CalibrationRecord[]>(() => {
    if (typeof window === 'undefined') {
      return [];
    }

    try {
      const storedValue = window.localStorage.getItem(AGENTATION_CALIBRATION_STORAGE_KEY);
      if (!storedValue) {
        return [];
      }

      const parsedValue = JSON.parse(storedValue) as unknown;
      return Array.isArray(parsedValue) ? (parsedValue as CalibrationRecord[]) : [];
    } catch {
      return [];
    }
  });

  useEffect(() => {
    if (typeof window === 'undefined') {
      return;
    }

    window.__clickyAgentationCalibrationAnnotations = annotations;
    window.__clickyExportCalibrationAnnotations = () => annotations;
    window.__clickyClearCalibrationAnnotations = () => {
      setAnnotations([]);
      window.localStorage.removeItem(AGENTATION_CALIBRATION_STORAGE_KEY);
    };
  }, [annotations]);

  useEffect(() => {
    if (typeof window === 'undefined') {
      return;
    }

    window.localStorage.setItem(
      AGENTATION_CALIBRATION_STORAGE_KEY,
      JSON.stringify(annotations)
    );
  }, [annotations]);

  const upsertAnnotation = useCallback((annotation: Annotation) => {
    const normalizedRecord = normalizeCalibrationRecord(annotation);
    setAnnotations((currentAnnotations) => {
      const nextAnnotations = currentAnnotations.filter(
        (currentAnnotation) => currentAnnotation.id !== normalizedRecord.id
      );
      nextAnnotations.push(normalizedRecord);
      nextAnnotations.sort((left, right) => left.timestamp - right.timestamp);
      return nextAnnotations;
    });

    console.debug('[clicky-calibration] annotation', normalizedRecord);
  }, []);

  const deleteAnnotation = useCallback((annotation: Annotation) => {
    setAnnotations((currentAnnotations) =>
      currentAnnotations.filter(
        (currentAnnotation) => currentAnnotation.id !== annotation.id
      )
    );
  }, []);

  const clearAnnotations = useCallback(() => {
    setAnnotations([]);
  }, []);

  const submitCalibration = useCallback(
    (_output: string, rawAnnotations: Annotation[]) => {
      const normalizedAnnotations = rawAnnotations.map(normalizeCalibrationRecord);
      setAnnotations(normalizedAnnotations);
      console.debug('[clicky-calibration] submit', normalizedAnnotations);
    },
    []
  );

  const toolbarClassName = useMemo(() => 'z-[10002]', []);

  return (
    <Agentation
      className={toolbarClassName}
      copyToClipboard={false}
      onAnnotationAdd={upsertAnnotation}
      onAnnotationDelete={deleteAnnotation}
      onAnnotationUpdate={upsertAnnotation}
      onAnnotationsClear={clearAnnotations}
      onSubmit={submitCalibration}
    />
  );
}

function LandingPage() {
  const mainRef = useRef<HTMLDivElement>(null);
  const snapTriggerRef = useRef<ScrollTrigger | null>(null);
  const { experienceMode } = useWebCompanionExperience();

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
          headline="Clicky reads"
          headlineItalic="the context"
          bubbleText="You're here."
          imageSrc="/screen_design_tool.jpg"
          imageAlt="Design tool interface"
          mascotPosition="top-right"
          zIndex={20}
          entranceDirection="bottom"
          exitDirection="left"
          bgColor="warm"
          showDemoReel={experienceMode === 'demo-only'}
        />

        {/* Section 3: Clicky points the way - z-30 */}
        <FeatureSection
          id="points-way"
          headline="Clicky shows"
          headlineItalic="where to look"
          bubbleText="Right here."
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
          headline="Clicky learns"
          headlineItalic="your tools"
          bubbleText="I know this."
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
          headline="Clicky turns tutorials"
          headlineItalic="into guidance"
          bubbleText="Let's run it."
          imageSrc="/screen_youtube.jpg"
          imageAlt="YouTube video page"
          mascotPosition="bottom-right"
          zIndex={50}
          entranceDirection="left"
          exitDirection="top"
          bgColor="sage"
          description="Paste a tutorial link and Clicky turns passive watching into step-by-step help you can actually follow while you work."
          showSteps={true}
        />

        {/* Section 6: Clicky can be anything - z-60 */}
        <FeatureSection
          id="can-be-anything"
          headline="Clicky adapts"
          headlineItalic="to the moment"
          bubbleText="Choose the vibe."
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
          headline="Clicky keeps"
          headlineItalic="the useful parts"
          bubbleText="Again?"
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

  if (pathname === '/auth/native' || pathname === '/auth/native/complete') {
    return <NativeAuthPage />;
  }

  return (
    <WebCompanionExperienceProvider>
      <LandingPage />
      <AgentationCalibrationBridge />
    </WebCompanionExperienceProvider>
  );
}

export default App;
