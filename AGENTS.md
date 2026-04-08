# Clicky - Coding Agent Instructions

<!-- This file mirrors the project agent guidance in a lowercase, tool-agnostic form for coding agents that prefer `agents.md`. -->

## Overview

macOS menu bar companion app. Lives primarily in the macOS status bar (no dock icon in production), but also exposes a unified Settings/Studio window for deeper configuration and debugging. Clicking the menu bar icon opens a custom floating panel with companion voice controls, and the Settings/Studio scene handles backend routing, OpenClaw Gateway configuration, voice pipeline status, and future integration/plugin setup. The app uses push-to-talk (ctrl+option) to capture voice input, transcribes it via AssemblyAI streaming when the Cloudflare Worker is configured, and otherwise falls back to Apple Speech for local development. The transcript plus a screenshot of the user's screen are sent to a selectable agent backend. Claude is the original backend via the Cloudflare Worker proxy. OpenClaw Gateway is also supported as a local/remote WebSocket agent backend. The chosen backend responds with text, the app speaks the reply through ElevenLabs or system speech fallback, and a blue cursor overlay can fly to and point at UI elements referenced in the reply.

All API keys live on a Cloudflare Worker proxy — nothing sensitive ships in the app.

## Architecture

- **App Type**: Menu bar-only (`LSUIElement=true`) in production, with a unified Settings/Studio scene for deeper configuration
- **Framework**: SwiftUI (macOS native) with AppKit bridging for the menu bar panel and cursor overlay
- **Pattern**: MVVM with `@StateObject` / `@Published` state management
- **Agent Backends**: Claude via Cloudflare Worker proxy plus OpenClaw Gateway via WebSocket with image attachments and Gateway session routing
- **Speech-to-Text**: AssemblyAI when the worker is configured, with OpenAI and Apple Speech fallbacks
- **Text-to-Speech**: ElevenLabs via the worker, with system speech fallback for local development
- **Screen Capture**: ScreenCaptureKit (macOS 14.2+), multi-monitor support
- **Voice Input**: Push-to-talk via `AVAudioEngine` and a pluggable transcription-provider layer
- **Element Pointing**: Agent replies may include `[POINT:x,y:label:screenN]` tags that drive the blue cursor overlay

## Build & Run

```bash
# Open in Xcode
open leanring-buddy.xcodeproj

# Select the leanring-buddy scheme, set signing team, Cmd+R to build and run
```

**Do NOT run `xcodebuild` from the terminal** — it invalidates TCC permissions and forces the app to re-request screen recording, accessibility, and related grants.

## Code Style & Conventions

- Prefer clarity over brevity in names, control flow, and structure.
- Use SwiftUI unless a feature specifically requires AppKit bridging.
- Keep UI state changes on `@MainActor`.
- Use async/await for asynchronous work.
- Add comments only where they explain a non-obvious *why*.
- All interactive controls should show a pointer cursor on hover.

## Do NOT

- Do not add features or refactors that were not explicitly asked for.
- Do not rename the project directory or scheme. The `leanring` typo is intentional/legacy.
- Do not try to clean up the known non-blocking warnings unless explicitly asked.
- Do not use `xcodebuild` from the terminal.

## Git Workflow

- Branch naming: `feature/description` or `fix/description`
- Commit messages: imperative mood, concise, explain the why
- Do not force-push to `main`

## Self-Update Instructions

When you make meaningful architecture or workflow changes, update this file and the main `AGENTS.md` file together so both stay aligned.
