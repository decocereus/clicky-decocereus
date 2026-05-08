# Clicky Context

This context names Clicky-specific product concepts so architecture work can reuse the same language instead of rediscovering it in scattered files.

## Language

**Assistant response contract**:
The structured JSON envelope every assistant backend returns to Clicky, containing spoken text and optional ordered point targets.
_Avoid_: raw answer text, point-tag response

**Assistant runtime graph**:
The assembled set of assistant backend adapters, turn execution, response repair, and response processing used by normal and tutorial turns.
_Avoid_: provider setup in CompanionManager, backend wiring

**Point target**:
A screenshot-pixel location plus label and bubble metadata that Clicky can resolve into a cursor overlay destination.
_Avoid_: coordinate tag, pointer marker

**Managed pointing narration**:
An ordered spoken walkthrough where every point target has an explicit assistant-provided explanation.
_Avoid_: fallback narration, inferred narration

**Onboarding point tag**:
The legacy `[POINT:x,y:label|bubble]` text format used only by the first-launch onboarding demo.
_Avoid_: assistant contract, backend response format

**Tutorial state snapshot**:
The locally persisted current tutorial import draft plus current-step session progress.
_Avoid_: tutorial cache, backend tutorial history

**Studio chrome**:
The reusable shell, card, and row primitives shared by Studio scenes.
_Avoid_: one-off Studio styling, duplicated Studio cards

**Studio scene**:
A dedicated SwiftUI surface inside the Studio window for one configuration or support area.
_Avoid_: giant Studio root section, inline Studio tab

**Companion panel chrome**:
The reusable menu-bar panel screen models, permission rows, button styles, shell styling, transitions, and status chips.
_Avoid_: inline panel styles, duplicated menu-bar panel enums

**Companion panel flow state**:
The pure state snapshot that resolves the menu-bar panel's active screen from onboarding, auth, permission, paywall, and tutorial import inputs.
_Avoid_: inline panel screen resolver, scattered panel flow switches

**Companion panel primary content**:
The screen-aware narrative card rendered at the top of the menu-bar panel body.
_Avoid_: inline headline switch, duplicated panel copy cards

**Companion panel tutorial cards**:
The tutorial-specific secondary cards for YouTube import, lesson compilation, ready state, playback, and failure recovery inside the menu-bar panel.
_Avoid_: tutorial flow UI inside the root panel view

**Companion panel access cards**:
The onboarding, sign-in, permission repair, active-summary, and locked-state secondary cards inside the menu-bar panel.
_Avoid_: setup/access UI inside the root panel view

**Overlay indicators**:
The reusable cursor overlay waveform, spinner, halo, and pulsing-orb views.
_Avoid_: inline cursor animation helpers

**Overlay video bridges**:
The SwiftUI/AppKit player bridges for onboarding and tutorial video playback inside the overlay.
_Avoid_: inline AVPlayer/WKWebView wrappers

## Relationships

- An **Assistant response contract** may contain zero or more **Point targets**.
- The **Assistant runtime graph** produces and repairs an **Assistant response contract**.
- **Managed pointing narration** requires one explicit explanation per **Point target**.
- An **Onboarding point tag** is converted into a **Point target** before the overlay is queued.
- A **Tutorial state snapshot** restores one current tutorial draft and its current-step progress on this Mac.
- A **Studio scene** composes **Studio chrome** instead of redefining shared cards or rows.
- The menu-bar companion surface composes **Companion panel chrome** instead of redefining screen models or styles inline.
- **Companion panel flow state** chooses which **Companion panel chrome** screen model the menu-bar companion surface renders.
- **Companion panel primary content** owns the top narrative card for each **Companion panel flow state** screen.
- **Companion panel access cards** own setup, permission, active summary, and locked-state secondary surfaces.
- **Companion panel tutorial cards** own tutorial-specific secondary surfaces while **Companion panel flow state** decides when those surfaces appear.
- `BlueCursorView` composes **Overlay indicators** and **Overlay video bridges** while `OverlayWindow` owns window lifecycle.

## Example Dialogue

> **Dev:** "Can the backend return an **Onboarding point tag** for normal assistant turns?"
> **Domain expert:** "No. Normal turns must use the **Assistant response contract**; the tag format is only for the first-launch demo."

## Flagged Ambiguities

- "pointing response" has meant both the structured contract and the onboarding tag. Resolved: use **Assistant response contract** for normal turns and **Onboarding point tag** for the demo-only format.
