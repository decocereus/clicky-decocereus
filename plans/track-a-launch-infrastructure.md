# Track A - Launch Infrastructure

> Current-state checklist for Clicky's launch infrastructure. This replaces the earlier phase-only planning view with a status-driven view of what is locked, what is implemented, what is partial, and what is still required before launch.

## Locked Decisions

These are the decisions we are currently building around:

- Clicky ships as a direct-download macOS app outside the Mac App Store.
- The website is a marketing and distribution surface, not the primary billing surface.
- The Mac app initiates auth and purchase flows.
- Auth is required for restore and entitlement sync.
- Google sign-in is the launch auth method.
- Checkout is Polar-hosted and opened from the Mac app.
- The launch commercial offer is a single launch pass product, not a multi-tier pricing model.
- Entitlements are user-level, not device-bound.
- Sparkle is the update mechanism.

## Done

These items are effectively implemented in code or documented strongly enough to count as completed for this track.

### Contracts and backend shape

- [x] Launch auth, billing, entitlement, and restore contracts are documented in [launch-phase-0-contracts.md](/Users/amartyasingh/Documents/projects/clicky-decocereus/docs/launch-phase-0-contracts.md).
- [x] Backend stack is chosen and scaffolded:
  - Cloudflare Workers + Hono
  - Neon Postgres
  - Drizzle
  - Better Auth
  - Polar
- [x] Better Auth tables and app-owned billing/entitlement tables are present in migrations.

### Auth foundation

- [x] Google sign-in is wired through Better Auth.
- [x] Native auth handoff is implemented:
  - `GET /v1/auth/native/start`
  - `GET /v1/auth/native/callback`
  - `POST /v1/auth/native/exchange`
- [x] The web handoff page exists and routes correctly at `/auth/native`.
- [x] The Mac app can initiate sign-in from Studio.
- [x] The Mac app can receive `clicky://auth/callback?...` and exchange the handoff code.
- [x] The Mac app stores the resulting session in Keychain.
- [x] The Mac app restores an existing session on launch.

### Entitlement model

- [x] Entitlement schema exists in the backend.
- [x] `GET /v1/entitlements/me` is implemented.
- [x] `POST /v1/entitlements/refresh` now runs a provider-backed Polar reconciliation path.
- [x] `POST /v1/billing/restore` now runs a provider-backed Polar reconciliation path.
- [x] The Mac app tracks entitlement state separately from raw auth state.
- [x] Studio surfaces account and entitlement state.

### Trial / paywall model

- [x] Backend-backed launch trial state exists with setup, welcome, credit, and paywall timestamps.
- [x] The launch trial now starts only after sign-in, so credits and restore state stay account-bound.
- [x] The Mac app enforces the backend-authoritative trial/paywall state inside the real companion turn flow.
- [x] Credits are consumed only after successful assisted turns.
- [x] The first turn after trial exhaustion becomes the paywall turn.
- [x] Fully paywalled state blocks the live companion interaction path.

### Polar integration core

- [x] `POST /v1/billing/checkout` creates real Polar checkout sessions.
- [x] Checkout audit records are persisted.
- [x] `POST /v1/webhooks/polar` verifies Polar webhooks.
- [x] `order.paid` updates launch entitlement state.
- [x] `order.refunded` updates launch entitlement state.
- [x] The Mac app can open Polar checkout from Studio.
- [x] The Mac app has a manual `Refresh Access` path.
- [x] Billing callback URLs exist:
  - `GET /v1/billing/callback/success`
  - `GET /v1/billing/callback/cancel`
- [x] The Mac app handles `clicky://billing/success` and `clicky://billing/cancel`.

### Website/backend integration

- [x] The website can talk to backend auth and `/v1/*` endpoints with CORS enabled.
- [x] The website no longer owns billing UX at launch.
- [x] The website contains a native auth handoff bridge without needing custom checkout UI.

## Partial / Needs Verification

These are implemented enough to exist, but are not proven or polished enough to count as fully done for launch.

### Live auth and purchase proof

- [ ] Google sign-in flow needs one full end-to-end live verification with the Mac app, browser, and backend.
  Current state:
  - code path exists
  - local envs were verified
  - OAuth URL generation works
  - needs one real browser consent loop

- [ ] Polar purchase flow needs one full end-to-end live verification with a public webhook URL.
  Current state:
  - checkout creation works structurally
  - webhook processing exists
  - needs a real purchase and real webhook delivery

### Restore and refresh semantics

- [ ] Provider-backed `billing/restore` and `entitlements/refresh` need one operational verification pass against real Polar/customer state.
- [ ] Offline grace behavior is documented, but not yet proven under real stale-session scenarios.

### Mac app access flow

- [ ] Studio has account, entitlement, purchase, refresh, and restore controls, but this is still a technical access surface rather than the final user-facing purchase experience.
- [ ] Launch access state is materially real, but the full “signed out / limited / unlocked / degraded” product flow is not yet presented in a polished way to normal users.

### Website contract drift

- [ ] The website handoff route is implemented, but the docs/checklist should be updated to reflect the current website architecture instead of the earlier, simpler scaffold.

## Remaining Before Launch

These are the real launch-blocking items still left.

### 1. Support Mode and Diagnostics Hardening

- [ ] Hide Diagnostics behind a support/developer toggle.
- [ ] Remove diagnostics from the normal user flow by default.
- [ ] Add safer copy/export behavior for logs.
- [ ] Ensure sensitive local values are not logged in plain form.

### 2. Free Taste and In-App Paywall

- [x] Choose and document the exact free-taste boundary.
- [x] Enforce the free-taste boundary in the Mac app.
- [x] Make the signed-out launch path explicit instead of silently bypassing the account-bound trial model.
- [ ] Build the actual in-app paywall UX for normal users.
- [ ] Make the paywall explain:
  - what the user got to try
  - what is now locked
  - how to sign in, buy, or restore

### 3. Real Restore and Unlock Behavior

- [x] Make `billing/restore` actually provider-backed.
- [x] Make `entitlements/refresh` actually sync provider state when needed.
- [ ] Tighten unlock behavior after successful purchase.
- [ ] Tighten returning-user restore behavior across reinstalls.
- [ ] Confirm refund/revocation behavior is acceptable.
- [ ] Confirm offline/stale entitlement grace behavior is acceptable.

### 4. Live Purchase Verification

- [ ] Expose the backend on a public URL for Polar webhook delivery.
- [ ] Configure Polar webhook endpoint against the public backend.
- [ ] Run one full real purchase from the Mac app.
- [ ] Verify:
  - checkout opens correctly
  - webhook is received
  - entitlement flips to active
  - Mac app reflects access after refresh

### 5. Sparkle Runtime Enablement

- [ ] Turn Sparkle on in the running app, not just in release scripts.
- [ ] Add/update user-facing update controls if needed.
- [ ] Verify appcast discovery and update flow from the app runtime.

### 6. Launch Ops and Docs

- [ ] Write a concise launch-ops checklist covering:
  - Google callback configuration
  - backend envs
  - Polar product and optional discount
  - public webhook URL
  - release/update steps
- [ ] Update launch docs so they match the current implementation, not the earlier plan narrative.

## Remaining Nice-to-Have

These are useful, but they should not block the first launch unless they expose a real product or support risk.

- [ ] Better support export bundle UX beyond basic log copy/export.
- [ ] Cleaner website/backend contract documentation for future contributors.
- [ ] More refined account/purchase UX outside Studio once the main launch flow is proven.
- [ ] Device-binding exploration if abuse becomes a real issue later.

## Immediate Next Steps

If we were executing from this checklist right now, the next best sequence would be:

1. Finish welcome prompt injection and the normal-user paywall messaging path.
2. Gate Diagnostics fully behind support mode and tighten support export/redaction.
3. Run one real purchase with a public webhook URL.
4. Harden whatever breaks in restore/unlock/offline behavior.
5. Enable Sparkle runtime behavior in the app.

## Notes

- The codebase has moved beyond the original planning phases. This file should now be treated as the canonical launch status view.
- When work lands, prefer updating this file by moving items between `Partial`, `Remaining Before Launch`, and `Done` rather than writing a second launch plan.
