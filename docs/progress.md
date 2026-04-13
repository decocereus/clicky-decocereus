# Clicky Progress Snapshot

## Current State

Clicky is now a real product-shaped codebase rather than only a shell experiment.

Today the repo contains:
- a macOS menu bar companion app with a custom Studio window
- a provider-agnostic assistant pipeline with `Claude`, `Codex`, and `OpenClaw`
- backend-backed auth, billing, trial, paywall, and entitlement flows
- a website companion with per-visitor sessions and backend-mediated OpenClaw routing
- an OpenClaw `clicky-shell` plugin scaffold with real registration, heartbeat, status, and session binding
- a YouTube tutorial import and guided playback flow inside the Mac app

The highest-risk remaining work is no longer basic implementation. It is live verification, persistence, polish, and end-to-end product QA.

## What Is Done

### Shell and runtime

- Stable menu bar companion panel
- Unified Settings/Studio window
- Local development fallback path when the Cloudflare worker is not configured
- Better voice state UX: listening, transcribing, thinking, responding
- Structured logging + in-app diagnostics buffer
- Provider-adapter assistant pipeline with canonical turn request/response models
- Shared turn builder, system-prompt planner, base-prompt source, provider registry, and turn executor
- Backend-specific adapter files for Claude, Codex, and OpenClaw instead of inline request assembly in the main manager

### Focus context

- Cursor/focus context captured per turn
- Screenshot-relative cursor grounding with timing delta
- Frontmost app + window title context
- Best-effort AX focused element metadata
- Shared focus context formatting that flows to every backend through the canonical turn contract

### OpenClaw integration

- OpenClaw Gateway backend in the app
- Connection test flow
- Native `clicky-shell` OpenClaw plugin scaffold
- Shell registration + heartbeat
- Shell status + session binding
- Versioned shell capability payload
- Prompt injection for fresh, bound shell sessions in plugin source

### Identity model

- Upstream OpenClaw identity stays upstream
- Clicky-local presentation override exists separately
- Studio reflects that split

### Launch platform

- Better Auth-backed native sign-in flow
- Backend entitlement snapshot + refresh + restore endpoints
- Polar checkout creation, callback routes, and webhook handling
- Backend-authoritative launch trial state
- In-app paywall enforcement inside the real assistant turn loop
- Sparkle updater startup and `Check for Updates…` command

### Website companion

- Backend session bootstrap, event, message, transcribe, and end routes
- Anonymous per-visitor session model
- Section-aware target registry and curated context
- Website voice input path using browser recording plus backend transcription
- Website audio playback via backend-generated ElevenLabs audio when configured
- OpenClaw-backed website companion generation with local fallback

### Tutorial flow

- YouTube tutorial URL entry in the companion panel
- Authenticated backend proxy routes for tutorial extraction
- Local import draft state in the Mac app
- Evidence fetch + lesson compilation flow
- Inline YouTube playback anchored beside the cursor
- Tutorial mode turns for next-step, repeat-step, list-steps, and in-context help

## What Still Needs Work

### Live verification

- One real Google sign-in pass through the production native handoff flow
- One real Polar purchase with public webhook delivery and unlock confirmation
- One real restore pass on a returning or reinstalled app
- One real Sparkle update pass against a published appcast
- One proper end-to-end YouTube tutorial verification pass against real extractor output

### Product / UX polish

- Make the default OpenClaw UI much more user-facing
- Move technical OpenClaw wiring behind Advanced / Diagnostics
- Improve overall Studio visual design
- Add richer cursor text and animation states
- Add user-customizable cursor/icon/color themes
- Add proper voice selection UI

### OpenClaw trust layer hardening

- Make shell trust state more durable than registration alone
- Tighten stale-shell behavior and recovery
- Improve automatic session binding semantics

### Tutorial productization

- Persist tutorial drafts and learner progress beyond the current in-memory session
- Add a stronger review / resume surface for imported tutorials
- Harden lesson compilation against messy model output

### Automated coverage

- Backend behavior tests for auth, trial, billing, and web companion contracts
- Web companion behavior tests
- Tutorial flow tests
- More than the current small set of permission-focused Swift tests

## Recommended Next Steps

1. Run the live verification passes for auth, purchase, restore, Sparkle, and the tutorial pipeline.
2. Persist tutorial drafts and progress locally so the YouTube feature survives app restarts.
3. Finish simplifying the user-facing Studio/OpenClaw UI and keep support tooling backstage.
4. Improve model/provider observability in telemetry and UI.
5. Add Clicky-local voice and appearance customization.
