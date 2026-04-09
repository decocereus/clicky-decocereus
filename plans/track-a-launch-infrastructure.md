# Plan: Track A - Launch Infrastructure

> Source PRD: Clicky product vision, launch/distribution discussion, auth/billing/update requirements from the current collaboration.

## Launch model

Durable decisions that apply across this track:

- **Distribution**: Clicky ships outside the Mac App Store as a signed, notarized direct download from the project website.
- **Download strategy**: The website does not gate the DMG behind checkout. New users can download Clicky freely.
- **Monetization flow**: Clicky gives the user a real taste inside the Mac app, then presents an in-app paywall when they hit the chosen free-use boundary.
- **Checkout surface**: The Mac app owns the purchase entry point, but checkout itself is Polar-hosted and opened from the app when needed.
- **Auth**: Auth is still required even with app-first commerce so purchases can restore across reinstalls and devices.
- **Billing**: Polar is the billing/checkout system.
- **Entitlements**: The Mac app and website share one entitlement source of truth through a tiny backend plus small database.
- **Backend scope**: Minimal backend only. Responsible for auth, checkout session creation, billing webhook processing, entitlement state, restore/unlock checks, and support telemetry endpoints if needed later.
- **Identity scope**: Launch should be user-level entitlement first, not device-bound licensing. Device binding can be evaluated later if abuse becomes a real problem.
- **Persistence split**:
  - **Local-only**: UI preferences, persona settings, BYO provider settings, cached voice choices, diagnostics toggle state, cached session metadata.
  - **Backend-backed**: user identity, purchase state, entitlement state, webhook event dedupe, restore history, optional future update channels.
- **Secrets**: Local BYO provider API keys remain on device where possible and should be stored in Keychain, not in the backend database.
- **Diagnostics**: Diagnostics are hidden by default behind a support/developer toggle and can be copied/exported for support.
- **Website scope**: The website is primarily a marketing and distribution surface. The user owns the design/UI/UX in `web/`; Codex owns the backend contracts and app/backend integration needed to support that site.

## Current repo realities

This track should build on what already exists instead of pretending we are starting from zero:

- The app already has an in-Studio diagnostics surface and in-memory diagnostics buffer. The work here is to gate, redact, and polish it for support use.
- The repo already has Sparkle wiring and a release pipeline. The work here is to finish enabling and productizing that path, not invent an update system from scratch.
- The repo already has a Cloudflare Worker for API proxying. The launch backend should extend that footprint or sit immediately adjacent to it rather than multiplying backend surfaces without a reason.

## Recommended implementation order

1. Freeze auth, entitlement, purchase, and restore contracts before building flows on top of them.
2. Harden diagnostics and logging so launch debugging is not a scramble later.
3. Add app auth and a stable entitlement model.
4. Build the free-taste and in-app paywall flow in the Mac app.
5. Wire Polar checkout and webhook-driven entitlement sync.
6. Finish unlock, restore, and session recovery behavior.
7. Finish Sparkle enablement and release readiness.
8. Keep the website as a slim distribution surface built against those contracts rather than a second product track.

---

## Phase 0: Contracts And Launch Architecture

**User stories**:
- As the product owner, I need the auth, checkout, and restore model nailed down before implementation spreads across app, backend, and web.
- As an implementer, I need stable nouns and states so the app state machine does not churn.

### What to build

Write and freeze the minimum contract set for launch:

- auth entry points for the Mac app and website
- callback/deep-link return path from browser checkout back into the Mac app
- session storage model in Keychain
- entitlement vocabulary used by app, backend, and Polar mapping
- purchase states and restore semantics
- offline grace behavior and stale-entitlement behavior
- free-taste boundary for launch

### Acceptance criteria

- [ ] Auth/session, purchase, entitlement, and restore states are explicitly documented.
- [ ] The Mac app callback/deep-link return path is defined.
- [ ] Entitlement names are stable and decoupled from Polar product IDs where needed.
- [ ] Offline and stale-cache behavior is defined before implementation begins.
- [ ] The launch free-taste boundary is chosen and documented.

---

## Phase 1: Support Mode And Diagnostics Hardening

**User stories**:
- As a normal user, I should not see technical debugging information by default.
- As a support user, I should be able to enable diagnostics, inspect logs, and export them for debugging.

### What to build

Take the existing Diagnostics surface in Studio and move it behind a support-mode toggle. When support mode is off, diagnostics are absent from normal navigation. When enabled, diagnostics should expose structured logs, safe request/response traces where appropriate, and support copy/export actions.

This phase also includes secret-aware logging policy, not just redacted export. Sensitive values should be excluded or redacted at log-write time wherever possible, then redacted again at export time as a second layer.

### Acceptance criteria

- [ ] Diagnostics are hidden by default for normal users.
- [ ] A support/developer toggle enables the diagnostics section.
- [ ] Diagnostics can copy/export structured logs in a support-friendly format.
- [ ] Sensitive local secrets are excluded or redacted from exported bundles.
- [ ] Sensitive values are not written into the diagnostics pipeline in plain form.

---

## Phase 2: Auth Foundation And Shared Entitlement Model

**User stories**:
- As a user, I can create/sign in to a Clicky account.
- As the product owner, I have one backend identity surface shared by Mac and website.

### What to build

Introduce the minimal backend and data store needed for authentication and identity. The backend issues authenticated app sessions and gives the Mac app a stable way to ask:

- who is this user?
- what entitlement do they have?
- when was that entitlement last refreshed?

The website consumes the same identity layer, but does not need a full billing product surface at launch.

### Acceptance criteria

- [ ] Users can sign in and sign out.
- [ ] The Mac app can establish and restore an authenticated session against the backend.
- [ ] Session credentials are stored locally in Keychain or an equally appropriate secure store.
- [ ] The backend stores only the minimum identity/account data needed for entitlement sync and restore.
- [ ] The auth/session model is shared between the Mac app and website.

---

## Phase 3: Free Taste And In-App Paywall Flow

**User stories**:
- As a new user, I can try Clicky before paying.
- As a user who reaches the free-use boundary, I get a clear, motivating paywall rather than a dead end.

### What to build

Add the launch free-taste model to the Mac app and pair it with a proper paywall flow. The app should let users experience the core value first, then transition to a locked or limited state that clearly explains:

- what they have already tried
- what is now limited or locked
- how to sign in, purchase, or restore access

The app should own the paywall UX and purchase CTA, even if the actual checkout happens in Polar-hosted browser UI.

### Acceptance criteria

- [ ] A user can install the app and get a meaningful first-use taste without paying first.
- [ ] The free-use boundary is enforced consistently.
- [ ] The paywall explains value, state, and next actions clearly.
- [ ] The paywall offers sign-in, purchase, and restore paths.
- [ ] The app can launch checkout from the paywall.

---

## Phase 4: Polar Checkout And Entitlement Sync

**User stories**:
- As a paying user, purchasing from the app flow unlocks Clicky on Mac.
- As the product owner, I need reliable entitlement state after payment events.

### What to build

Integrate Polar billing with the backend so the Mac app can request checkout, the browser can complete purchase, and successful payment events update a durable entitlement record. Webhooks must be idempotent. The launch model should support a one-time purchase cleanly, while leaving room for subscription plans later.

### Acceptance criteria

- [ ] The Mac app can request or launch a Polar checkout flow.
- [ ] Polar checkout updates backend entitlement state.
- [ ] The backend webhook path is idempotent and deduped.
- [ ] The entitlement model supports a one-time launch purchase cleanly.
- [ ] The Mac app can refresh and reflect the latest entitlement state after purchase.

---

## Phase 5: Unlock, Restore, And Session Recovery

**User stories**:
- As a user, I can sign in after purchase and unlock Clicky reliably.
- As a returning user, my access restores without friction.
- As a user with a network issue or stale session, I get understandable recovery paths.

### What to build

Add a proper launch/access state machine to the Mac app that coexists with the app's current onboarding and permissions flow. The app should be able to represent at least these states:

- onboarding incomplete
- permissions missing
- signed out
- signed in, entitlement unknown
- limited/free-taste mode
- unlocked
- locked due to missing entitlement
- degraded due to offline or refresh failure

On later launches, the app should restore session state and re-check entitlement quietly when possible. Failure states should be understandable and recoverable.

### Acceptance criteria

- [ ] Locked users see a clear sign-in / purchase-required flow.
- [ ] Purchased users unlock successfully after sign-in and refresh.
- [ ] Returning users restore session and entitlement automatically when possible.
- [ ] The app handles expired, invalid, missing, or stale entitlements gracefully.
- [ ] Offline or temporary backend failure behavior matches the documented grace policy.

---

## Phase 6: Sparkle Enablement And Release Pipeline Hardening

**User stories**:
- As a user, I can update Clicky from inside the app.
- As the product owner, I can publish updates and have clients discover them reliably.

### What to build

Finish the Sparkle distribution path that already exists in the repo: appcast generation, signed update artifacts, in-app update settings, and manual/automatic update behavior. Users should be able to opt into auto-update behavior, and the app should be able to surface update availability clearly.

### Acceptance criteria

- [ ] The app can check for updates from a published appcast.
- [ ] Users can enable or disable automatic updates.
- [ ] The app can download and install updates through the standard Sparkle flow.
- [ ] Release signing and update signing are documented and repeatable.
- [ ] The existing release pipeline is aligned with the chosen Sparkle runtime behavior.

---

## Phase 7: Website Distribution Contract And Launch Readiness

**User stories**:
- As a new user, I can discover Clicky on the website and download the Mac app easily.
- As the site owner, I can build the website UI independently without blocking on backend ambiguity.

### What to build

Define the backend/API requirements that the user-built `web/` frontend depends on:

- download CTA assumptions
- auth endpoints
- session endpoints
- entitlement status endpoint
- purchase-start endpoint
- purchase success/cancel return expectations
- restore/account basics if exposed on the site

The website does not need a full launch billing product flow. It is primarily a marketing and distribution surface, while the Mac app owns the productized paywall and purchase entry point.

### Acceptance criteria

- [ ] Backend/API requirements for the website are documented and stable before frontend functionality depends on them.
- [ ] Website download flow assumptions are clear and ungated.
- [ ] The website can be built independently against those contracts.
- [ ] The website does not need custom checkout UI for launch.
- [ ] A launch operations checklist exists for site, app, billing, auth, entitlements, and updates.
