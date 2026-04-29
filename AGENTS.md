# Clicky - Coding Agent Instructions

## Overview

macOS menu bar companion app. Lives primarily in the macOS status bar (no dock icon in production), but also exposes a unified Studio window for deeper configuration and debugging. Clicking the menu bar icon opens a custom floating panel with companion voice controls, and the Studio window handles backend routing, OpenClaw Gateway configuration, voice pipeline status, and future integration/plugin setup. The app uses push-to-talk (ctrl+option) to capture voice input, transcribes it via AssemblyAI streaming when the Cloudflare Worker is configured, and otherwise falls back to Apple Speech for local development. The transcript plus a screenshot of the user's screen are sent to a selectable agent backend. Claude is the original backend via the Cloudflare Worker proxy. OpenClaw Gateway is also supported as a local/remote WebSocket agent backend. The chosen backend responds with text, the app speaks the reply through ElevenLabs or system speech fallback, and a blue cursor overlay can fly to and point at UI elements referenced in the reply.

All API keys live on a Cloudflare Worker proxy — nothing sensitive ships in the app.

## Architecture

- **App Type**: Menu bar-only (`LSUIElement=true`) in production, with a unified Studio window for deeper configuration
- **Framework**: SwiftUI (macOS native) with AppKit bridging for the menu bar panel and cursor overlay
- **Studio Window Host**: custom AppKit-managed `NSWindow` hosting SwiftUI content so Clicky can control the real outer shell, keep native traffic lights, and avoid Settings-scene chrome regressions
- **State Pattern**: Prefer the simplest state ownership model that fits the surrounding feature. Preserve existing patterns in-place, use SwiftUI-native state by default, and only introduce additional view-model-style abstraction when the feature genuinely needs it.
- **Agent Backends**: Clicky now uses a provider-agnostic assistant turn contract with backend-specific adapter files. Claude currently routes through the Cloudflare Worker proxy, and OpenClaw Gateway routes over WebSocket with image attachments and Gateway session routing. Future direct providers such as OpenAI/Codex should plug into the same contract rather than adding ad hoc logic in the main manager.
- **OpenClaw Plugin Direction**: The repo includes a native OpenClaw plugin in `plugins/openclaw-clicky-shell` and a contract doc in `docs/clicky-openclaw-integration-contract.md`. The plugin handles shell registration, status, prompt-context injection, and the `clicky_present` presentation tool. It should not expose desktop-operation tools unless a new implementation is deliberately designed and documented.
- **OpenClaw Prompt Hygiene**: Clicky runtime/system instructions for OpenClaw must flow through the `clicky-shell` plugin's prompt-injection path, not by being concatenated into the raw user `message` payload
- **OpenClaw Presentation Path**: For OpenClaw-backed Clicky turns, prefer the plugin-exposed `clicky_present` tool to choose the presentation mode, then have the agent emit the exact structured JSON envelope returned by that tool as the final assistant message. Keep raw structured JSON without the tool only as fallback during migration.
- **Web Companion Direction**: The marketing site should keep its current landing-page design and add the companion as a layered shell experience. Use per-visitor OpenClaw sessions/threads with curated section context, a semantic target registry for pointing, and a generated site-layout reference image rather than unrestricted DOM access or browser screen-share prompts. See `docs/web-companion-prd.md` and `docs/web-openclaw-session-architecture.md`
- **Identity Model**: The upstream agent identity belongs to OpenClaw. Clicky may optionally override presentation **inside Clicky only**; it should not silently rewrite the upstream agent identity
- **Speech-to-Text**: AssemblyAI when the worker is configured, with OpenAI and Apple Speech fallbacks
- **Text-to-Speech**: ElevenLabs via the worker, with system speech fallback for local development
- **Web Voice Pipeline**: The website companion should record mic audio in the browser, transcribe it on the backend with AssemblyAI, and play backend-generated ElevenLabs audio. The live website flow should not depend on browser screen-share. Do not rely on browser `SpeechRecognition` or `speechSynthesis` as the primary production path.
- **Screen Capture**: ScreenCaptureKit (macOS 14.2+), multi-monitor support
- **Focus Context**: The assistant turn contract now carries cursor/focus context in addition to screenshots: active display, cursor position, recent trail, screenshot-relative cursor coordinates, screenshot freshness delta, frontmost app/window, and best-effort AX focused element metadata.
- **Voice Input**: Push-to-talk via `AVAudioEngine` and a pluggable transcription-provider layer
- **Assistant Response Contract**: Clicky still renders one canonical structured response object with `spokenText` plus ordered point targets. For OpenClaw, prefer arriving at that contract through plugin tools rather than prompt-only formatting whenever possible.
- **Launch Commerce Model**: direct-download website, free download plus in-app taste, in-app paywall, Polar-hosted checkout launched from the Mac app, lightweight auth plus backend-backed entitlement restore

## Codex Workflow

- Instruction priority for this repo:
  1. Repo `AGENTS.md` files define product constraints, workflow guardrails, and launch assumptions.
  2. The Build macOS Apps plugin is the default source of macOS implementation guidance.
  3. `docs/clicky-identity.md` is the source of truth for Clicky's product identity, public-facing voice, and experience philosophy.
  4. `docs/macos-design.md` is the design source of truth for desktop UI.
  5. SwiftUI and Liquid Glass skills provide implementation-quality guidance unless they conflict with a more specific repo rule.
- Before starting any work in this repo, use the Build macOS Apps plugin as the default source of platform guidance.
- Pick the smallest relevant Build macOS Apps skill set for the task first, then say which skills are guiding the work. Most common fits here are `swiftui-patterns`, `window-management`, `appkit-interop`, `telemetry`, `view-refactor`, `build-run-debug`, `test-triage`, `signing-entitlements`, and `packaging-notarization`.
- Before writing public-facing copy, shaping onboarding/paywalls, or designing interfaces, read `docs/clicky-identity.md` first and treat it as the source of truth for what Clicky is supposed to feel like.
- For any macOS UI work, read `docs/macos-design.md` first and treat it as the design source of truth for the desktop app.
- When the task touches the menu bar companion, prioritize `liquid-glass` guidance first and preserve the compact single-shell panel design described in `docs/macos-design.md`.
- Treat the plugin as the default reference for macOS-specific decisions: scene structure, menu bar behavior, window activation/focus, toolbar and command design, app bundle behavior, unified logging, telemetry, packaging, and other desktop-native details.
- Actively guide the user to take advantage of the plugin. When relevant, suggest Codex Run button wiring, project-local run scripts, `.codex/environments/environment.toml`, unified logging, or targeted telemetry so future debugging loops are tighter.
- Clarify only when a decision would materially change architecture, UX, launch behavior, or verification cost. Otherwise, make the smallest safe assumption, state it, and keep moving.
- Repo-specific override: do **not** follow generic shell-first `xcodebuild` advice here. This project must not use `xcodebuild` from the terminal because it can invalidate TCC permissions and force the app to re-request screen recording, accessibility, and similar grants.
- If plugin guidance would normally suggest shell build/run automation, adapt it for this repo by preferring Xcode-launched build/run loops and non-destructive debugging paths first. Only discuss terminal build automation if the user explicitly wants that tradeoff and understands the TCC cost.
- If the user wants deeper observability, prefer lightweight `OSLog` / unified logging instrumentation and plugin-guided telemetry patterns over ad hoc prints.
- Do **not** automatically reinstall the local `clicky-shell` OpenClaw plugin or restart the OpenClaw Gateway during normal iteration. Only do either when the user explicitly asks, or when the user clearly agrees to that disruption for a specific verification step.

## Build & Run

```bash
# Open in Xcode
open leanring-buddy.xcodeproj

# Select the leanring-buddy scheme, set signing team, Cmd+R to build and run
```

Prefer Xcode.app as the primary build/run loop in this repo.

**Do NOT run `xcodebuild` from the terminal** — it invalidates TCC permissions and forces the app to re-request screen recording, accessibility, and related grants.

If the user wants Codex app Run button support or tighter build/run automation, propose a repo-safe path first and explicitly call out any TCC tradeoffs before wiring shell-based automation.

The Codex app `Run` action is wired through `.codex/environments/environment.toml` to `./script/build_and_run.sh`, which tells Xcode to build and run the `leanring-buddy` scheme via AppleScript so TCC-sensitive permissions stay intact.

## Code Style & Conventions

- Prefer clarity over brevity in names, control flow, and structure.
- Use SwiftUI unless a feature specifically requires AppKit bridging.
- Keep UI state changes on `@MainActor`.
- Use async/await for asynchronous work.
- Add comments only where they explain a non-obvious *why*.
- All interactive controls should show a pointer cursor on hover.
- Current brand palette is logo-led glass: soft white `#FAFCFF`, frost glass `#EAF8FF`, mist `#DDE8EE`, icy blue `#A9D6EB`, aqua glow `#4FE7EE`, cursor blue `#3478F6`, periwinkle `#8EA2FF`, blush `#FFB9CF`, and deep ink `#16212B`.
- Do not change the desktop design direction casually. If a macOS UI change meaningfully changes the design system, update `docs/macos-design.md`, this file, and `leanring-buddy/AGENTS.md` together.
- Do not write public-facing copy or design core product experiences in a way that conflicts with `docs/clicky-identity.md`. If the product identity changes meaningfully, update that doc and both `AGENTS.md` files in the same turn.

## Do NOT

- Do not add features or refactors that were not explicitly asked for.
- Do not add create branches unless explicitly asked
- Do not rename the project directory or scheme. The `leanring` typo is intentional/legacy.
- Do not try to clean up the known non-blocking warnings unless explicitly asked.
- Do not use `xcodebuild` from the terminal, even if generic plugin guidance suggests a shell-first macOS workflow.
- Do not reintroduce website-gated checkout assumptions without explicitly confirming a launch strategy change.

## Git Workflow

- Branch naming: `feature/description` or `fix/description`
- Commit messages: imperative mood, concise, explain the why
- Do not force-push to `main`

## Self-Update Instructions

When you make meaningful architecture or workflow changes, update this file and `leanring-buddy/AGENTS.md` together so all tracked agent entry points stay aligned.

When you make meaningful changes to Clicky's product identity, public-facing voice, or experience philosophy, update `docs/clicky-identity.md`, this file, and `leanring-buddy/AGENTS.md` together in the same turn.
