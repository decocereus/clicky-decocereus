# Clicky macOS Design Guide

This file is the source of truth for native macOS UI work in Clicky.

If an agent changes SwiftUI/AppKit UI in the desktop app, they must read this file first and preserve these rules unless the user explicitly asks to change the design direction.

## Core Philosophy

- Liquid Glass is front and center for Clicky on macOS.
- The menu bar companion should feel like a native floating glass object, not a custom dark sheet or a mini web page.
- The outer shell should stay light, clear, and system-native.
- Readability should come from the content inside the shell, not by darkening or muddying the shell itself.
- The app should feel compact, elegant, and intentional.

## Menu Bar Companion

- The companion panel is a quick-control surface, not a settings window.
- Keep it compact enough to fit comfortably below the menu bar on common laptop screens.
- Do not let the panel grow into a long inspector or form unless the user explicitly asks for that.
- Only keep essential information in the panel:
  - current status
  - immediate voice/action hint
  - active persona summary
  - backend routing quick control
  - one compact backend summary card when useful
  - one or two essential actions
- Move deeper configuration into Studio/Settings instead of expanding the panel.

## Shell And Cards

- The outer container should be a single shell.
- Do not reintroduce a visible second outer container or a rectangular background behind the rounded shell.
- Prefer a clear or lightly highlighted Liquid Glass shell on supported macOS versions.
- Do not heavily tint the shell green, gray, or charcoal.
- Interior cards may use warmer filled surfaces for readability, but those surfaces should live inside the shell.
- Interior cards should be visually lighter than the shell and should use readable charcoal text.
- For Studio specifically, the real window should be treated as the shell. Do not rely on a managed Settings-scene frame as the visible outer container if it causes chrome regressions.
- Preserve native traffic lights in Studio whenever possible. If Studio needs deeper window control, prefer a custom AppKit-managed window host over piling extra fake chrome into SwiftUI.

## Color System

- Match the desktop app to the web brand palette.
- Current brand palette:
  - warm background: `#FAF8F5`
  - warm secondary surface: `#F5F2EE`
  - lavender surface/accent: `#EAE8F0` / `#9B8FBF`
  - sage accent: `#E8EDE9` / `#7A9B8A`
  - charcoal text/action: `#1A1A1A`
- Use sage for brand presence and positive/status accents.
- Use lavender for focus, selection, and softer interaction accents.
- Use charcoal for strong CTA actions and high-contrast text.
- Avoid falling back to generic system blue when a branded control treatment is expected and practical.

## Contrast Rules

- Text on interior cards must use the card/content palette, not the outer shell palette.
- Primary actions must always be clearly visible at a glance.
- Secondary actions must still read as buttons, not as faded labels.
- Footer actions on the glass shell need enough contrast and structure to remain readable.
- If a control becomes hard to read over glass, fix the control styling before changing the shell.

## Controls

- Top-right utility buttons should feel like native glass controls.
- Do not over-tint neutral glass controls.
- Segmented or toggle-like quick controls should stay compact and visually clean.
- Prefer small, purposeful controls over large form-like rows in the panel.
- Every interactive control should show a pointer cursor on hover.

## What To Avoid

- Do not turn the companion panel into a mini settings page.
- Do not solve readability by making the whole shell opaque or muddy.
- Do not add extra sections just because there is space.
- Do not regress to double-shell chrome.
- Do not add decorative color for its own sake.
- Do not introduce UI that feels more web than native macOS unless the user explicitly wants that.

## Workflow For UI Changes

- Start with the Build macOS Apps plugin, especially `liquid-glass`, `swiftui-patterns`, and `appkit-interop` when needed.
- Read the existing panel/window structure before changing visual styling.
- Make the smallest change that preserves this design system.
- Prefer Xcode visual verification for UI changes in this repo.
- When a UI change meaningfully changes the design system, update this file and both AGENTS files in the same turn.

## Regression Check

Before considering macOS UI work done, verify:

- the panel still reads as one floating glass shell
- the panel height still fits the visible screen
- the interior cards are readable
- primary and secondary buttons are both clearly visible
- the panel is still compact
- Studio remains the place for deep settings
