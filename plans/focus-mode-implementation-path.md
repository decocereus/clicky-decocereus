# Plan: Focus Mode Implementation Path

Status note:

- this remains planning-only
- I did not find a corresponding implemented Focus Mode slice in the current codebase

> Source PRD: Clicky product vision, focus-mode discussion, and the current desktop shell foundation.

## Why this is a separate track

Focus Mode is important, but it is not the same wedge as teach mode, workflows, tutorials, and course authoring.

It reuses the same shell primitives:

- screen context
- voice interaction
- cursor-side presence
- lightweight local state

But the product loop is different:

- workflow mode helps the user learn or repeat a process
- focus mode helps the user stay on the task they already chose

Keeping it separate prevents accountability features from distorting the workflow/tutorial model too early.

## Architectural decisions

- **Product role**: Focus Mode is a Clicky shell behavior, not a general macOS blocking tool.
- **Primary unit**: A focus session starts from a user-stated intention, task, or goal.
- **Monitoring style**: v1 should observe visible desktop context and compare it against the active intention rather than hard-block apps or websites.
- **Intervention style**: Clicky should interrupt lightly and briefly. Accountability is the product, but constant nagging is not.
- **Tone control**: Tone must be configurable per focus session or profile without mutating the user's global Clicky persona.
- **Privacy**: Focus judgments should be local-first. Do not introduce a new backend requirement just to monitor drift in v1.
- **Escalation**: v1 should prefer reminders and check-ins over punitive enforcement.

---

## Phase 1: Focus Session Foundations

**User stories**:
- As a user, I can start a focus session with a clear stated task.
- As a user, I can clearly tell when Focus Mode is active.

### What to build

Add a dedicated Focus Mode shell state with a clear start and stop path, visible mode treatment, and an active intention attached to the session. The session should feel separate from the normal assistant loop and separate from Teach Mode.

### Acceptance criteria

- [ ] Focus Mode can be started and stopped intentionally.
- [ ] The user can set or speak a focus intention at session start.
- [ ] The shell has a visually distinct Focus Mode state.
- [ ] The current focus intention remains visible or reviewable during the session.

---

## Phase 2: Drift Detection Heuristics v1

**User stories**:
- As a user, Clicky can notice when my visible activity no longer matches what I said I was doing.
- As a user, false positives stay manageable.

### What to build

Build a first drift-detection layer that compares the active intention against visible app, window, and screen context. Start with lightweight heuristics and confidence thresholds rather than pretending the model is perfectly certain.

### Acceptance criteria

- [ ] Clicky can compare the active intention against current visible activity.
- [ ] Drift detection produces a confidence or certainty signal rather than only a binary judgment.
- [ ] The system can distinguish likely on-task, ambiguous, and likely off-task states.
- [ ] v1 heuristics are reviewable and tunable without rewriting the whole mode.

---

## Phase 3: Accountability Prompts And Tone Profiles

**User stories**:
- As a user, Clicky can call me back to the task when I drift.
- As a user, I can choose whether that tone is gentle, direct, or harsh.

### What to build

Add interruption behavior for likely drift states. Prompts should be short, contextual, and mode-specific. Tone should be configurable independently from the user’s general companion voice and presentation settings.

### Acceptance criteria

- [ ] Clicky can issue accountability prompts when drift is detected.
- [ ] Prompt tone can be configured without changing the whole app persona.
- [ ] Prompts can reference the active focus intention and current drift reason.
- [ ] Users can quickly dismiss or acknowledge a prompt and continue.

---

## Phase 4: Session Review And Iteration Loop

**User stories**:
- As a user, I can understand how a focus session went after it ends.
- As the product owner, I can improve drift detection without redefining the whole mode.

### What to build

Add a lightweight post-session summary showing intention, duration, number of interventions, and notable drift moments. This creates a feedback loop for both product quality and user trust.

### Acceptance criteria

- [ ] Focus sessions have a local summary at the end.
- [ ] Users can review intervention count and major drift moments.
- [ ] The system can expose enough diagnostic detail to tune heuristics later.
- [ ] Session review remains local-first in v1.
