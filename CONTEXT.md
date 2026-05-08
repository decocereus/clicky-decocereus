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

## Relationships

- An **Assistant response contract** may contain zero or more **Point targets**.
- The **Assistant runtime graph** produces and repairs an **Assistant response contract**.
- **Managed pointing narration** requires one explicit explanation per **Point target**.
- An **Onboarding point tag** is converted into a **Point target** before the overlay is queued.
- A **Tutorial state snapshot** restores one current tutorial draft and its current-step progress on this Mac.

## Example Dialogue

> **Dev:** "Can the backend return an **Onboarding point tag** for normal assistant turns?"
> **Domain expert:** "No. Normal turns must use the **Assistant response contract**; the tag format is only for the first-launch demo."

## Flagged Ambiguities

- "pointing response" has meant both the structured contract and the onboarding tag. Resolved: use **Assistant response contract** for normal turns and **Onboarding point tag** for the demo-only format.
