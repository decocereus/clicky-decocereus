# Plan: YouTube Tutorial Playback UX Contract

Status note:

- the inline player, anchored bubble, keyboard controls, and pointing handoff model are now implemented
- remaining work is mainly QA and polish, not first-pass UX invention

This document defines the tutorial playback UX that Clicky should preserve when the imported tutorial flow lands in the cursor companion.

## Non-negotiable UX

The tutorial player should preserve the current onboarding-video interaction pattern instead of inventing a separate mini-player UI.

That means:

1. The cursor companion can visually transform into a floating inline player.
2. The text bubble appears above that player, anchored to the same cursor companion position.
3. When Clicky needs to point at something on the user’s desktop, the pointer-capable cursor companion should become visible again.
4. While Clicky is pointing, the video should still remain visible in the anchored playback spot.
5. After pointing finishes, the player should continue in the same anchored spot unless the flow explicitly decides otherwise.
6. Before tutorial playback really begins, Clicky should show the playback keyboard shortcuts to the user.

This is important because the current onboarding flow already teaches the right mental model:

- Clicky is still the companion
- the companion can temporarily become a video surface
- the same companion can also point and speak

## Source of truth for the current UX

The existing onboarding implementation already contains the interaction we want to preserve:

- onboarding player state lives in [CompanionManager.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/CompanionManager.swift:210)
- onboarding video setup starts in [CompanionManager.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/CompanionManager.swift:3619)
- the floating video is rendered beside the cursor in [OverlayWindow.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/OverlayWindow.swift:220)
- the prompt bubble is rendered above that anchored position in [OverlayWindow.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/OverlayWindow.swift:236)
- the pointer companion reappears in pointing mode in [OverlayWindow.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/OverlayWindow.swift:691)

The tutorial playback UX should reuse this pattern rather than replacing it with a detached player window or a Studio-only media surface.

## Required behavior

### Inline player mode

When a tutorial step wants source-video context:

- the companion should transform into an inline player near the cursor
- the player should feel like the cursor companion temporarily widening into a media card
- the player should not become a separate free-floating media window

### Bubble placement

When a tutorial step includes spoken or visible instructional text:

- the text bubble should appear above the inline player
- the bubble should remain visually tied to the companion/player anchor
- the bubble should not move to a disconnected HUD location

### Pointing handoff

When a tutorial step requires pointing:

- the inline player should remain visible in place
- the pointer-capable companion should reappear clearly
- the companion should fly to the target and point just like the current pointing flow
- after pointing completes, the companion should settle back into playback mode if appropriate

### Keyboard controls

Proper keyboard controls are required.

At minimum:

- `Space`: play / pause
- `Left Arrow`: seek backward
- `Right Arrow`: seek forward
- `Escape`: dismiss inline player when appropriate

These controls should only apply while the tutorial player surface is active.

Before tutorial playback begins, Clicky should briefly surface these shortcuts in the companion UI so the controls feel discoverable rather than hidden.

### Focus model

The inline player must not steal the core companion identity.

It is still Clicky.
The player is a temporary presentation mode of the companion, not a different feature shell.

## What to avoid

- Do not move tutorial playback into Studio for the happy path.
- Do not introduce a detached desktop media player window as the primary tutorial experience.
- Do not show the player and pointing cursor as unrelated UI objects.
- Do not place the instruction bubble in one place and the player in another.
- Do not lose keyboard playback control.

## App-side playback state

Tutorial playback needs an explicit state model so the UX is preserved by design.

That state is modeled in:

- [TutorialPlaybackModels.swift](/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/TutorialPlaybackModels.swift:1)

The important state is:

- `surfaceMode`
  - `hidden`
  - `inlineVideo`
  - `inlineVideoWithBubble`
  - `pointerGuidance`
- `resumeBehavior`
  - `resumeInlineVideoAfterPointing`
  - `stayHiddenAfterPointing`

These states should drive the overlay instead of ad hoc boolean combinations.

## Recommended implementation sequence

1. Verify the current playback surface against real tutorial sessions and pointing scenarios.
2. Tighten any regressions in keyboard control, point handoff, and bubble anchoring.
3. Preserve the same shared anchored-media pattern as more tutorial polish lands.

## Product rule

The tutorial player is not “video mode.”
It is still the cursor companion, temporarily widened into a player-backed guidance surface.

That mental model must survive implementation.
