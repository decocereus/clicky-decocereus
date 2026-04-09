# Clicky Progress Snapshot

## Current State

Clicky now works as a real desktop shell around an OpenClaw agent on macOS.

The app can:
- capture push-to-talk audio
- capture screen context
- send that context to either the built-in Claude path or an OpenClaw Gateway backend
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

1. Finish simplifying the user-facing Studio/OpenClaw UI.
2. Verify the linked `clicky-shell` plugin end-to-end in the running OpenClaw Gateway.
3. Deepen the trust/presence policy once the simplified UI is in place.
4. Add Clicky-local voice and appearance customization.
5. Add auth + Polar when the shell experience is stable enough to package.
