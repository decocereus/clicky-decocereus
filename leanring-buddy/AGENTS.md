# AGENTS.md - leanring-buddy (Main App Target)

## Repo Workflow

- Before starting work in this target, use the Build macOS Apps plugin as the default macOS guidance layer and pick the smallest relevant skill first.
- For any desktop UI work, read `../docs/macos-design.md` first and treat it as the source of truth for native design decisions.
- For menu bar companion work, start from the `liquid-glass` skill and preserve the compact single-shell panel and interior-card philosophy documented in `../docs/macos-design.md`.
- Treat Studio as a custom AppKit-managed window hosting SwiftUI, not as a normal Settings-scene surface. Preserve the real outer Studio window as the first shell and keep native traffic lights whenever possible.
- Default to plugin guidance for SwiftUI/AppKit structure, menu bar behavior, window activation, telemetry, window management, signing, packaging, and other desktop-specific choices.
- Actively help the user take advantage of the plugin by suggesting tighter run/debug loops, Run button support, and unified logging or telemetry when those would materially help.
- Repo override: do **not** use terminal `xcodebuild` here. Preserve TCC permissions by preferring Xcode.app for build/run unless the user explicitly accepts the tradeoff.
- The Codex app `Run` action is wired to `./script/build_and_run.sh`, which uses Xcode AppleScript automation rather than terminal `xcodebuild`.
- Do **not** automatically reinstall the local `clicky-shell` OpenClaw plugin or restart the OpenClaw Gateway while iterating on the macOS app. Only do that when the user explicitly asks for it, or explicitly agrees to a verification step that requires it.
- Launch/commercialization work should assume a direct-download website, a real free taste inside the Mac app, an in-app paywall, Polar-hosted checkout launched from the app, and backend-backed auth plus entitlement restore.
- Repo-wide website work should preserve the current landing-page design and treat the web companion as an additive Clicky shell layer with per-visitor OpenClaw sessions, a semantic target registry for pointing, and a generated site-layout reference image instead of browser screen-share prompts. See `docs/web-companion-prd.md` and `docs/web-openclaw-session-architecture.md`.
- Website voice work should use browser mic capture plus backend AssemblyAI and backend ElevenLabs. Do not reintroduce browser `SpeechRecognition`, `speechSynthesis`, or browser screen-share as the primary production path for the public site experience.
- If a UI change intentionally changes the desktop design system, update `../docs/macos-design.md`, `/AGENTS.md`, and this file together in the same turn.

## Source Files

### FloatingSessionButton.swift
- `FloatingSessionButtonManager` — `@MainActor` class managing the `NSPanel` lifecycle
  - `showFloatingButton()` — Creates/shows the panel in top-right of primary screen
  - `hideFloatingButton()` — Hides panel (keeps it alive for quick re-show)
  - `destroyFloatingButton()` — Removes panel permanently (session ended)
  - `onFloatingButtonClicked` — Callback closure, set by ContentView to bring main window to front
  - `floatingButtonPanel` — Exposed `NSPanel` reference for screenshot exclusion
- `FloatingButtonView` — Private SwiftUI view with gradient circle, scale+glow hover animation, pointer cursor

### ContentView.swift
- Receives `FloatingSessionButtonManager` via `@EnvironmentObject`
- `isMainWindowCurrentlyFocused` — Tracks main window focus state
- `configureFloatingButtonManager()` — Wires up the click callback
- `startObservingMainWindowFocusChanges()` — Sets up `NSWindow` notification observers
- `updateFloatingButtonVisibility()` — Core logic: show if running + not focused, hide otherwise
- `bringMainWindowToFront()` — Activates app and orders main window front

### ScreenshotManager.swift
- `floatingButtonWindowToExcludeFromCaptures` — `NSWindow?` reference set by ContentView
- `captureScreen()` — Matches the floating window to an `SCWindow` and excludes it from capture filter

### leanring_buddyApp.swift
- Owns `FloatingSessionButtonManager` as `@StateObject`
- Injects it into ContentView via `.environmentObject()`
