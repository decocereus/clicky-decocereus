# Plan: Track B - Product Capabilities

> Source PRD: Clicky product vision, workflow/tutorial/focus-mode discussion, OpenClaw shell direction, and the current Mac app foundation.

## Architectural decisions

Durable decisions that apply across this track:

- **Product role**: Clicky is the desktop shell around an agent, not the agent itself.
- **Primary interaction model**: Voice-first. The user should be able to speak to Clicky naturally rather than rely on explicit buttons for every step.
- **Workflow foundation**: A workflow is a structured sequence of visual steps that Clicky can guide, verify, and optionally perform.
- **Workflow execution UX**: Clicky speaks, points, and shows tiny contextual hints near the cursor; it does not rely on a button-heavy control bar.
- **Teach mode**: Teach mode is a first-class shell mode with its own visual state, cursor treatment, overlay behavior, and activation methods.
- **Focus mode**: Focus mode is a separate accountability mode, not a generic system "do not disturb" toggle.
- **Tutorial engine**: Tutorials are generated workflows plus lesson structure. Manual teach-mode workflows and AI-generated tutorial workflows should converge on the same underlying model.
- **YouTube ingestion**: The user provides a video URL, and Clicky derives course/workflow structure from transcript + sampled frames/screenshots. Video playback can appear inline, similar to the onboarding-video presentation model.
- **Execution safety**: v1 should prefer guide/verify/optional-safe-actions over unrestricted autonomous control.
- **Provider flexibility**: OpenClaw remains the broadest BYO-agent path; direct provider support can expand later but the workflow system should not depend on one specific model vendor.

---

## Phase 1: Teach Mode Foundations

**User stories**:
- As a user, I can enter a teach mode where Clicky understands I am demonstrating a reusable process.
- As a user, I can clearly tell when teach mode is active.

### What to build

Add a true Teach Mode to the shell. Entering it changes the cursor treatment, menu bar icon state, and overlay behavior so the user understands Clicky is now observing and structuring their demonstrated actions. Teach mode should be activatable by voice, keyboard shortcut, or shell UI.

### Acceptance criteria

- [ ] Teach mode has a visually distinct shell state.
- [ ] Teach mode can be toggled by voice and by a direct shortcut/UI path.
- [ ] The cursor/presence treatment changes immediately when teach mode starts.
- [ ] The menu bar shell reflects teach mode state.

---

## Phase 2: Workflow Data Model And Runner v1

**User stories**:
- As a user, I can save a reusable workflow made of discrete visual steps.
- As a user, Clicky can guide me through a saved workflow one step at a time.

### What to build

Define the core workflow object model and build the first local workflow runner. Each workflow should include step instructions, visual targets, optional actions, and completion rules. The runner should support voice-first step progression, pointer guidance, and optional safe actions.

### Acceptance criteria

- [ ] Workflows and steps have a stable local data model.
- [ ] Clicky can run a workflow step by step.
- [ ] The runner supports voice-first progression such as next / done / repeat / do it.
- [ ] The runner can point at the current target and track progress locally.

---

## Phase 3: AI-Assisted Workflow Authoring

**User stories**:
- As a user, I do not have to manually fill every workflow field.
- As a user, Clicky infers most of the structure and only asks me for what is truly missing.

### What to build

Build an authoring flow where Clicky infers the app, target, action, and likely completion checks from what the user demonstrates. The system should ask for the minimum missing information rather than force form-heavy entry. The output should still be a structured workflow object.

### Acceptance criteria

- [ ] Teach mode can infer step metadata from observed user actions.
- [ ] Clicky asks only for missing or ambiguous details.
- [ ] The saved result is still a structured workflow, not just a raw event recording.
- [ ] The authoring flow feels lighter than manual form entry.

---

## Phase 4: Focus Mode

**User stories**:
- As a user, I can tell Clicky what I am supposed to be working on.
- As a user, Clicky can call me out when I drift away from the intended task.

### What to build

Add Focus Mode as a separate shell behavior. The user defines a work intention or task, and Clicky monitors the visible desktop context for drift. When the user gets distracted, Clicky interrupts with accountability prompts. Tone should be configurable so strict or rude accountability is optional rather than mandatory.

### Acceptance criteria

- [ ] Focus Mode can be started and stopped intentionally.
- [ ] Clicky can compare current visible activity against the stated task.
- [ ] Clicky can issue accountability prompts when drift is detected.
- [ ] Focus Mode tone can be configured without changing the whole app persona.

---

## Phase 5: YouTube Tutorial Ingestion

**User stories**:
- As a user, I can give Clicky a YouTube tutorial and have it turn that into something I can follow on my own screen.
- As a learner, I can watch or reference tutorial video context inline while Clicky guides me.

### What to build

Integrate the existing YouTube extraction foundation into Clicky’s workflow system. From a single video URL, derive transcript, sampled frames/screenshots, and lesson structure. Use that material to generate a workflow/lesson draft. Support optional inline playback of the source video in the desktop shell or Studio, similar to the current onboarding-player experience.

### Acceptance criteria

- [ ] User can provide a YouTube URL as tutorial source.
- [ ] Clicky can extract transcript + representative frames/screens.
- [ ] Clicky can generate a workflow/lesson draft from that source.
- [ ] Inline video context can be shown during tutorial use when helpful.

---

## Phase 6: Guided Course Mode

**User stories**:
- As a learner, I can follow a course-like progression rather than a one-off workflow.
- As a learner, I can ask follow-up questions when I get stuck mid-lesson.

### What to build

Build a course mode on top of workflow execution. A course should bundle lesson structure, progress state, repeatable steps, and checkpoints. Clicky should answer contextual questions during the lesson while preserving the current step context.

### Acceptance criteria

- [ ] A workflow can be packaged and run as a lesson/course.
- [ ] Clicky tracks lesson progress through steps and checkpoints.
- [ ] The user can ask contextual questions without losing their place.
- [ ] Tutorial/course mode feels clearly distinct from generic assistant mode.

---

## Phase 7: Safe Execution And Testing Workflows

**User stories**:
- As a user, I can let Clicky perform safe repetitive workflow steps for me.
- As a user, I can repurpose workflows for lightweight testing or repeated UI flows.

### What to build

Expand the workflow runner so Clicky can optionally perform safe actions like clicking through known UI targets or typing into controlled fields. This should remain explicitly bounded and workflow-driven. The same mechanism can support repeated UI checks or lightweight manual test automation.

### Acceptance criteria

- [ ] Workflow steps can optionally include safe execution actions.
- [ ] Clicky can perform approved safe actions inside a workflow run.
- [ ] The same workflow model can be used for repeated UI test flows.
- [ ] The system keeps clear user control over when actions are executed automatically.
