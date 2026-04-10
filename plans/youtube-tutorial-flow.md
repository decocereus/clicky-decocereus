# Plan: YouTube Tutorial Flow

> Source PRD: Clicky product vision, the YouTube tutorial discussion, and the current desktop shell foundation.

## Why this is its own track

The YouTube tutorial flow is still part of Clicky's learning wedge, but it should not depend on Teach Mode shipping first.

The product loop is simpler:

- import a tutorial source
- extract usable evidence
- compile that evidence into a guided lesson
- help the user follow it on their own desktop

That keeps this track launch-friendly and avoids dragging workflow recording and replay complexity back into scope.

## Architectural decisions

- **Product role**: Clicky remains the desktop shell around an agent. It helps the user consume and follow a tutorial; it does not become a general-purpose video platform.
- **Primary source**: v1 starts from a user-provided YouTube URL.
- **Extraction dependency**: Transcript and frame extraction should be treated as an external ingestion dependency. It should not be assumed to already exist inside this repo.
- **Cloudflare posture**: The current Cloudflare Worker is optional for this track. If used, it should remain a thin auth or proxy layer, not the heavy video-processing engine.
- **Teach Mode dependency**: This track must not depend on Teach Mode or workflow recording shipping first.
- **Compilation path**: Imported tutorial evidence should be compiled by the user's selected agent backend into lesson steps that Clicky can present clearly.
- **Inline playback**: Inline video playback is helpful, but it is secondary to turning the tutorial into a usable guided flow.
- **Local-first v1**: Imported tutorial metadata, lesson drafts, and learner progress should live locally first.
- **Studio role**: Studio is the place for review, editing, and debugging imported tutorial structure. It should not be required for the happy-path import every time.
- **Execution posture**: v1 should optimize for guide-and-verify, not autonomous cursor control.

---

## Infrastructure shape

- **No new backend required for tutorial playback itself**: Once transcript, frames, and lesson structure exist locally, Clicky can guide the user without introducing a new service just to run the tutorial.
- **External ingestion is the main exception**: Importing a YouTube URL into transcript plus representative frames likely needs an existing external pipeline or a prior-project service.
- **Agent routing can stay flexible**: OpenClaw remains the broadest BYO-agent path. Direct API-key-backed providers can also work as long as Clicky can hand them the imported evidence bundle.
- **AssemblyAI is not foundational here**: It is part of the live speech-to-text stack today, but it is not required for the YouTube import path itself.

---

## Phase 1: Tutorial Import Foundations

**User stories**:
- As a user, I can give Clicky a YouTube tutorial URL.
- As a user, I can tell whether Clicky has enough material to turn that video into a guided tutorial.

### What to build

Add a dedicated tutorial-import flow that accepts a YouTube URL, validates it, and creates a local import draft. The draft should track source URL, import status, extraction metadata, and any failure reason without forcing the user into Studio.

### Acceptance criteria

- [ ] User can submit a YouTube URL from the shell or Studio.
- [ ] Clicky creates a local import draft with status and source metadata.
- [ ] Import failures are explained clearly enough for the user to retry or switch sources.
- [ ] The import flow does not depend on Teach Mode or recorded workflows.

---

## Phase 2: Extraction Pipeline Integration

**User stories**:
- As a user, Clicky can pull the useful instructional material out of a tutorial video.
- As a user, I do not need to manually transcribe or screenshot the source video first.

### What to build

Integrate the external extraction pipeline behind a narrow adapter. From a single YouTube URL, Clicky should import a transcript, representative frames or screenshots, timestamps, and basic structural markers. Keep the adapter thin so the extraction implementation can live outside this repo.

### Acceptance criteria

- [ ] Clicky can request transcript and frame extraction for a YouTube URL.
- [ ] Imported material includes transcript text, timestamps, and representative visual frames.
- [ ] The adapter isolates the app from extractor-specific details.
- [ ] Extraction can fail independently without corrupting the local draft.

---

## Phase 3: Agent-Compiled Lesson Drafts

**User stories**:
- As a user, Clicky turns imported tutorial material into something easier to follow than the original raw video.
- As a user, I get reusable steps instead of only a transcript dump.

### What to build

Hand the imported evidence bundle to the user's selected agent backend and ask it to produce a structured lesson draft. The result should emphasize clean step titles, user-facing instructions, likely app or window context, and lightweight verification hints. Studio should allow review and editing, but the happy path should compile automatically after import completes.

### Acceptance criteria

- [ ] Imported tutorial evidence can be compiled into a structured lesson draft.
- [ ] The compiled result is better than a raw transcript and clearly step-based.
- [ ] Clicky can save the compiled lesson locally without requiring a manual Studio-only flow.
- [ ] Studio can still review and edit the resulting lesson draft.

---

## Phase 4: Guided Tutorial Playback

**User stories**:
- As a learner, Clicky can guide me through the imported tutorial on my own screen.
- As a learner, I can stay oriented without constantly scrubbing the original video.

### What to build

Build a guided playback mode for imported tutorials. Clicky should present the current step, keep the learner's place, answer contextual questions, and optionally show source video context inline when helpful. The first version should focus on speaking, pointing, and verifying context rather than automating UI actions.

### Acceptance criteria

- [ ] Clicky can run a compiled tutorial step by step.
- [ ] The learner can move through steps and preserve progress locally.
- [ ] Clicky can answer contextual questions without losing the current tutorial position.
- [ ] Inline source-video context can be shown when it helps, but the lesson remains usable without constant playback.

---

## Phase 5: Review, Progress, And Polish

**User stories**:
- As a user, I can revisit imported tutorials later.
- As a user, I can tell what worked, what failed, and what still needs editing.

### What to build

Polish the review surface in Studio so imported tutorials feel like a real product feature rather than a debug pipeline. Add local progress, retry paths, and import diagnostics that make it clear what happened at each stage.

### Acceptance criteria

- [ ] Imported tutorials can be reopened and resumed later.
- [ ] Users can review lesson structure, progress, and import diagnostics in Studio.
- [ ] The Studio surface feels intentionally designed for review and editing, not like a temporary debug panel.
- [ ] The overall flow is launch-friendly and does not reintroduce Teach Mode complexity by accident.
