# AGENTS.md - leanring-buddy (Main App Target)

## Repo Workflow

- Before starting work in this target, use the Build macOS Apps plugin as the default macOS guidance layer and pick the smallest relevant skill first.
- Default to plugin guidance for SwiftUI/AppKit structure, menu bar behavior, window activation, telemetry, window management, signing, packaging, and other desktop-specific choices.
- Actively help the user take advantage of the plugin by suggesting tighter run/debug loops, Run button support, and unified logging or telemetry when those would materially help.
- Repo override: do **not** use terminal `xcodebuild` here. Preserve TCC permissions by preferring Xcode.app for build/run unless the user explicitly accepts the tradeoff.
- The Codex app `Run` action is wired to `./script/build_and_run.sh`, which uses Xcode AppleScript automation rather than terminal `xcodebuild`.
- Do **not** automatically reinstall the local `clicky-shell` OpenClaw plugin or restart the OpenClaw Gateway while iterating on the macOS app. Only do that when the user explicitly asks for it, or explicitly agrees to a verification step that requires it.
- Launch/commercialization work should assume a direct-download website, a real free taste inside the Mac app, an in-app paywall, Polar-hosted checkout launched from the app, and backend-backed auth plus entitlement restore.
- Repo-wide website work should preserve the current landing-page design and treat the web companion as an additive Clicky shell layer with per-visitor OpenClaw sessions. See `docs/web-companion-prd.md` and `docs/web-openclaw-session-architecture.md`.

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
