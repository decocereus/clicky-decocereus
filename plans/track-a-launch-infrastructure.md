# Plan: Track A - Launch Infrastructure

> Source PRD: Clicky product vision, launch/distribution discussion, auth/billing/update requirements from the current collaboration.

## Architectural decisions

Durable decisions that apply across this track:

- **Distribution**: Clicky ships outside the Mac App Store as a signed, notarized direct download from the project website.
- **Update system**: Clicky uses Sparkle for appcast-based updates, optional auto-update, and in-app "check for updates."
- **Billing**: Polar is the billing/checkout system.
- **Entitlements**: The Mac app and web app share one entitlement source of truth through a tiny backend plus small database.
- **Backend scope**: Minimal backend only. Responsible for auth, billing webhook processing, entitlement state, device/app unlock checks, and support telemetry endpoints if needed later.
- **Persistence split**:
  - **Local-only**: UI preferences, persona settings, BYO provider settings, cached voice choices, diagnostics toggle state.
  - **Backend-backed**: user identity, purchase/license/subscription state, entitlement state, webhook event dedupe, update channels if introduced later.
- **Secrets**: Local BYO provider API keys remain on device where possible and should be stored in Keychain, not in the backend database.
- **Diagnostics**: Diagnostics are hidden by default behind a support/developer toggle and can be copied/exported for support.
- **Frontend website**: The public website / web app UI will be built by the user directly, not by Codex. This plan covers backend contracts and app integration points that the frontend depends on.

---

## Phase 1: Support Mode And Diagnostics Gate

**User stories**:
- As a normal user, I should not see technical debugging information by default.
- As a support user, I should be able to enable diagnostics, inspect logs, and export them for debugging.

### What to build

Hide the current Diagnostics surface behind a support-mode toggle in Settings. When support mode is off, diagnostics are absent from the normal navigation. When enabled, the diagnostics panel exposes structured logs, latest request/response traces where safe, support export actions, and redaction-aware copy/export behavior.

### Acceptance criteria

- [ ] Diagnostics are hidden by default for normal users.
- [ ] A support/developer toggle enables the diagnostics section.
- [ ] Diagnostics can copy/export structured logs in a support-friendly format.
- [ ] Sensitive local secrets are excluded or redacted from any exported bundle.

---

## Phase 2: Auth Foundation And Tiny Backend

**User stories**:
- As a user, I can create/sign in to a Clicky account.
- As the product owner, I have one backend identity surface shared by Mac and web.

### What to build

Introduce a minimal backend and data store for authentication and identity. The backend issues authenticated app sessions and gives the Mac app a stable way to ask "who is this user?" and "what should be unlocked for them?" The web app consumes the same identity layer.

### Acceptance criteria

- [ ] Users can sign in and sign out.
- [ ] The Mac app can establish an authenticated session against the backend.
- [ ] The backend stores only the minimum identity/account data needed for entitlement sync.
- [ ] The auth/session model is shared between the Mac app and web app.

---

## Phase 3: Polar Billing And Entitlement Sync

**User stories**:
- As a paying user, purchasing on the web should unlock Clicky on Mac.
- As the product owner, I need reliable entitlement state after payment events.

### What to build

Integrate Polar billing with the tiny backend so successful purchases update a durable entitlement record. The Mac app should fetch and cache entitlement state after login. Webhooks should be idempotent and the entitlement model should support at least one-time purchase at launch, with room for subscription plans later.

### Acceptance criteria

- [ ] Polar checkout updates backend entitlement state.
- [ ] Mac app can fetch and reflect current entitlement state after login.
- [ ] Webhook handling is idempotent and deduped.
- [ ] Launch pricing can be represented cleanly as a one-time purchase.

---

## Phase 4: Mac Unlock Flow And Session Recovery

**User stories**:
- As a user, I can install the Mac app, sign in, and unlock it after purchase.
- As a returning user, my entitlement should restore without friction.

### What to build

Add a proper locked/unlocked state machine to the Mac app. On first launch, the app should guide the user to sign in or purchase. On later launches, it should restore the signed-in state and re-check entitlements quietly. Failure states should be understandable and recoverable.

### Acceptance criteria

- [ ] Locked users see a clear sign-in / purchase-required flow.
- [ ] Purchased users unlock successfully after sign-in.
- [ ] Returning users restore entitlement automatically when possible.
- [ ] The app handles expired, invalid, or missing entitlements gracefully.

---

## Phase 5: Sparkle Update Pipeline

**User stories**:
- As a user, I can update Clicky from inside the app.
- As the product owner, I can publish updates and have clients discover them reliably.

### What to build

Finish the Sparkle distribution path: appcast generation, signed update artifacts, in-app update settings, and manual/automatic update behavior. Users should be able to opt into auto-update behavior, and the Mac app should be able to surface update availability clearly.

### Acceptance criteria

- [ ] The app can check for updates from a published appcast.
- [ ] Users can enable/disable automatic updates.
- [ ] The app can download and install updates through the standard Sparkle flow.
- [ ] Release signing and update signing are documented and repeatable.

---

## Phase 6: Website Download And Launch Readiness Handoff

**User stories**:
- As a new user, I can buy Clicky on the website and download the Mac app.
- As the site owner, I can ship the web experience separately from the Mac app backend work.

### What to build

Define the backend/API requirements that the user-built web frontend needs: auth endpoints, entitlement endpoints, download gating rules, checkout callbacks, and account pages. The frontend implementation itself is owned by the user and stays outside Codex scope, but the backend contract and Mac app integration points must be clear and stable.

### Acceptance criteria

- [ ] Backend/API requirements for the website are documented and stable.
- [ ] Download flow assumptions for the Mac app are clear.
- [ ] The user can build the web frontend independently against those contracts.
- [ ] Launch operations checklist exists for site + app + billing + updates.

