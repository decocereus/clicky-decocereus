# Clicky Progress Snapshot

## Current State

Clicky now works as a real desktop shell around an OpenClaw agent on macOS.

The app can:
- capture push-to-talk audio
- capture screen context
- capture cursor/focus context alongside screenshots
- send that context through a shared provider-agnostic assistant turn contract
- speak the reply back locally
- show cursor-side presence and pointing
- register itself as a live Clicky shell with the `clicky-shell` OpenClaw plugin

## What Is Done

### Shell and runtime

- Stable menu bar companion panel
- Unified Settings/Studio window
- Local development fallback path when the Cloudflare worker is not configured
- Better voice state UX: listening, transcribing, thinking, responding
- Structured logging + in-app diagnostics buffer
- Provider-adapter assistant pipeline with canonical turn request/response models
- Shared turn builder, system-prompt planner, base-prompt source, provider registry, and turn executor
- Backend-specific adapter files for Claude and OpenClaw instead of inline request assembly in the main manager

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

## What Still Needs Work

### Product / UX

- Make the default OpenClaw UI much more user-facing
- Move technical OpenClaw wiring behind Advanced / Diagnostics
- Improve overall Studio visual design
- Add richer cursor text and animation states
- Add user-customizable cursor/icon/color themes
- Add proper voice selection UI

### OpenClaw trust layer

- Verify the newest plugin behavior end-to-end in the running Gateway
- Make shell trust state more durable than registration alone
- Tighten stale-shell behavior and recovery
- Improve automatic session binding semantics

### Product platform

- Auth
- Billing via Polar
- Minimal entitlement/backend state once auth+billing land

## Recommended Next Steps

1. Add the next direct provider on top of the new assistant contract, starting with Codex/OpenAI.
2. Improve model-level observability and surface the effective provider/model identity in telemetry and UI.
3. Finish simplifying the user-facing Studio/OpenClaw UI.
4. Verify the linked `clicky-shell` plugin end-to-end in the running OpenClaw Gateway.
5. Add Clicky-local voice and appearance customization.
