# Clicky Context

This context names Clicky-specific product concepts so architecture work can reuse the same language instead of rediscovering it in scattered files.

## Language

**Assistant response contract**:
The structured JSON envelope every assistant backend returns to Clicky, containing spoken text and optional ordered point targets.
_Avoid_: raw answer text, point-tag response

**Point target**:
A screenshot-pixel location plus label and bubble metadata that Clicky can resolve into a cursor overlay destination.
_Avoid_: coordinate tag, pointer marker

**Managed pointing narration**:
An ordered spoken walkthrough where every point target has an explicit assistant-provided explanation.
_Avoid_: fallback narration, inferred narration

**Onboarding point tag**:
The legacy `[POINT:x,y:label|bubble]` text format used only by the first-launch onboarding demo.
_Avoid_: assistant contract, backend response format

## Relationships

- An **Assistant response contract** may contain zero or more **Point targets**.
- **Managed pointing narration** requires one explicit explanation per **Point target**.
- An **Onboarding point tag** is converted into a **Point target** before the overlay is queued.

## Example Dialogue

> **Dev:** "Can the backend return an **Onboarding point tag** for normal assistant turns?"
> **Domain expert:** "No. Normal turns must use the **Assistant response contract**; the tag format is only for the first-launch demo."

## Flagged Ambiguities

- "pointing response" has meant both the structured contract and the onboarding tag. Resolved: use **Assistant response contract** for normal turns and **Onboarding point tag** for the demo-only format.
