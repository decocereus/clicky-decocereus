# Plan: YouTube Tutorial Integration Contract

Status note:

- the app-side import seam and backend tutorial proxy routes described here now exist
- the next missing piece is not first-pass integration but durable persistence and end-to-end verification

This document defines the next concrete seam between Clicky, the authenticated Clicky backend, and the external tutorial extraction service.

It assumes the fast extraction service can already do:

- `POST /tutorials/extract`
- `GET /tutorials/extract/:jobId`
- `GET /tutorials/evidence/:videoId`

## Product loop

The Clicky-side loop should be:

1. User pastes a YouTube URL into Clicky.
2. Clicky creates a local import draft immediately.
3. Clicky calls the authenticated Clicky backend.
4. The Clicky backend proxies tutorial extraction to the external ingestion service.
5. Clicky polls extraction status through the backend until the bundle is ready.
6. Clicky fetches the normalized evidence bundle through the backend and stores it locally.
7. Clicky hands that evidence bundle to the currently selected agent backend.
8. The selected backend returns a lesson draft.
9. Clicky stores the lesson draft locally and can guide the user through it.

## Clicky-side local state

Clicky should remain local-first for tutorial import state.

The app should store:

- source URL
- video ID
- embed URL
- title
- channel
- thumbnail
- extraction job ID
- import status
- extraction error
- compile error
- evidence bundle
- compiled lesson draft
- learner progress

These are modeled in:

- [TutorialImportModels.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/TutorialImportModels.swift:1)

## Extraction client seam

Clicky should not know about `yt-dlp`, captions, chapters, thumbnail heuristics, content-ingestion base URLs, or extractor API keys directly.

Clicky should only know:

- how to start extraction
- how to poll extraction status
- how to fetch the normalized evidence bundle

That is modeled in:

- [TutorialExtractionClient.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/TutorialExtractionClient.swift:1)

The Mac app should talk only to the authenticated Clicky backend and use the stored launch session token for tutorial requests.

The Clicky backend should own:

- authentication checks
- proxying to content-ingestion
- content-ingestion credentials
- future policy gates and rate limiting

## Compilation path

The compilation step should stay provider-agnostic in the same way the live assistant turn path is provider-agnostic today.

Do not create:

- a tutorial-specific Claude-only compile path
- a tutorial-specific OpenClaw-only compile path
- provider-specific lesson models

Instead:

1. Build one canonical Clicky lesson-compilation request.
2. Map that canonical request through backend-specific provider adapters.

That mirrors the existing assistant architecture:

- [ClickyAssistantProvider.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/ClickyAssistantProvider.swift:1)
- [ClickyAssistantTurn.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/ClickyAssistantTurn.swift:1)
- [ClickyAssistantTurnBuilder.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/ClickyAssistantTurnBuilder.swift:1)

## Suggested canonical lesson compilation request

The app should eventually build a provider-agnostic request with:

- system instructions for lesson drafting
- user-visible goal: turn evidence into a guided desktop lesson
- evidence bundle JSON
- optional app context, such as the user’s current backend, focus mode, and desktop posture

The output should normalize into:

- tutorial title
- short summary
- ordered steps
- each step with:
  - title
  - instruction
  - optional verification hint
  - optional source time range
  - optional source video prompt timestamp

These are already modeled in:

- [TutorialImportModels.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/TutorialImportModels.swift:1)

## Recommended implementation order in Clicky

### Phase 1

- Add a small tutorial import manager owned by `CompanionManager`.
- Let it create and update `TutorialImportDraft` records locally.
- Keep the first persistence layer simple.

### Phase 2

- Wire `TutorialExtractionClient` into the import manager.
- Support:
  - start extraction
  - poll job
  - fetch evidence
- Expose extraction state to Studio and the companion shell.

### Phase 3

- Add a provider-agnostic lesson compilation contract.
- Add one adapter per backend:
  - Claude
  - OpenClaw
- Keep the lesson draft output normalized before it reaches UI.

### Phase 4

- Add a guided playback state machine in Clicky.
- Keep first playback focused on:
  - current step
  - next step
  - source video open/embed target
  - voice guidance
  - cursor pointing
  - simple local progress

## UX boundaries

### Companion shell

The shell should handle:

- paste/import entry
- current import progress
- current tutorial step
- inline or adjacent video open action
- quick continue / repeat / next-step control

### Studio

Studio should handle:

- import history
- evidence inspection
- structure review
- compiled lesson editing
- failure diagnostics

That keeps the happy path out of Studio while preserving a real review surface.

## What should happen next

The next implementation step in Clicky should be:

1. persist tutorial drafts and tutorial session progress beyond the current in-memory state
2. add a stronger review/resume surface in Studio
3. run real end-to-end verification against actual extraction jobs and lesson-compilation output

The smallest useful integration step has already landed. The next work should make it durable and trustworthy.
