# Launch Phase 0 Contracts

Status: initial implementation contract for launch infrastructure

This document freezes the first-pass backend and contract decisions for Clicky's launch path so the Mac app, backend, billing, and website can evolve against one shared model.

## Recommended stack

- **Backend runtime**: TypeScript on Cloudflare Workers using Hono
- **Database**: Neon serverless Postgres
- **ORM / schema**: Drizzle ORM + SQL migrations
- **Auth layer**: Better Auth
- **Billing**: Polar hosted checkout + Polar webhooks
- **Deployables**:
  - existing `worker/` stays the AI proxy for Anthropic, ElevenLabs, and AssemblyAI secrets
  - new `backend/` service becomes the auth, billing, and entitlement API

## Why this stack

- It stays fully TypeScript end to end.
- It avoids self-managed database infrastructure and keeps hosting lightweight.
- It matches the product shape better than a realtime-first backend because this launch surface is mostly classic HTTP: auth, callbacks, checkout creation, webhook reconciliation, and entitlement lookups.
- It fits the repo's existing Cloudflare footprint instead of introducing a totally separate compute platform.
- Postgres gives us durable relational primitives for entitlements, webhook dedupe, and purchase state without fighting SQLite edge cases.

## Why I am not recommending Convex for launch

Convex can work, but I do not think it is the best fit for this specific backend.

Why I am passing on it for launch:

- The core problem here is not collaborative realtime state. It is straightforward HTTP auth, native-app callback flows, Polar checkout creation, webhook processing, and entitlement reconciliation.
- The Mac app and website both want a thin, explicit HTTP API. Convex supports HTTP actions, but it is still a more opinionated app-backend model than we need here.
- Native-app auth would still require extra glue around token exchange and session issuance. That means we would absorb Convex's architecture without really using its main upside.

If we later build a collaborative web app with live backend state, Convex becomes more attractive. For launch infrastructure, I want the boring option.

## Hosting model

- `worker/`
  - keeps handling AI provider proxying and secret isolation
  - deploys under a worker hostname such as `proxy.clicky.app`

- `backend/`
  - Hono app running on Cloudflare Workers
  - deploys under a hostname such as `api.clicky.app`
  - owns auth, billing, entitlements, and native-app callback flows

- Neon Postgres
  - one managed database for auth tables and app billing tables
  - no EC2, no manually managed Postgres

## Launch product defaults

These are the defaults I recommend unless we explicitly change them:

- **Free taste boundary**: 10 backend-authoritative trial credits granted after setup completes.
- **Taste accounting**: backend-backed per signed-in user, not local-only per install.
- **Trial start gate**: the backend-backed launch trial begins only after the user signs in.
- **Welcome turn**: the first post-setup guided welcome turn does not decrement a trial credit.
- **Purchase model at launch**: one-time purchase.
- **Entitlement scope**: user-level, not device-bound.
- **Offline behavior after unlock**: keep last known unlocked state for 30 days after the most recent successful entitlement refresh.
- **Restore behavior**: signed-in users can always trigger a manual restore; app also refreshes entitlement quietly on launch and foreground transitions.

## Auth contract

## User-facing auth methods

- Launch with Google sign-in as the default.
- Keep magic-link or other email-based auth as a later option if needed.
- Require sign-in before the backend-backed launch trial starts.
- Require sign-in before purchase and before cross-device restore.

## Session model

- **Web**: Better Auth cookie session.
- **Mac app**: Better Auth-backed native bearer session obtained through a browser-based sign-in flow plus one-time code exchange.
- **Local storage**: Mac app stores session tokens and refresh metadata in Keychain.

## Native app auth flow

1. Mac app opens browser to `GET /v1/auth/native/start`.
2. Backend redirects into Better Auth sign-in flow.
3. After successful auth, backend creates a short-lived one-time exchange code.
4. Backend redirects to `clicky://auth/callback?code=...`.
5. Mac app receives the deep link and calls `POST /v1/auth/native/exchange`.
6. Backend returns:
   - bearer session token
   - refresh metadata or session expiry
   - user profile summary
   - current entitlement snapshot
7. Mac app stores the session in Keychain and enters signed-in state.

## Sign-out behavior

- Mac app calls backend sign-out/revoke endpoint.
- Backend invalidates the Better Auth session.
- Mac app clears Keychain session state and cached entitlement snapshot.

## Billing and entitlement contract

## Purchase flow

1. User hits the in-app paywall.
2. If not signed in, the app prompts sign-in first.
3. App calls `POST /v1/billing/checkout`.
4. Backend creates or reuses the Polar customer mapping for the signed-in user.
5. Backend creates a Polar hosted checkout session and returns the checkout URL.
6. App opens that URL in the browser.
7. Polar completes checkout and redirects to a backend success URL.
8. Backend can optionally bounce the browser into `clicky://billing/success?...` for a tighter native return flow.
9. Polar webhook updates entitlement state in Postgres.
10. App refreshes entitlement and unlocks.

## Restore flow

1. User signs in on a new or reinstalled Mac app.
2. App calls `GET /v1/entitlements/me`.
3. Backend returns current entitlement snapshot.
4. If needed, app offers a `Restore Purchase` action that triggers a fresh sync path.

## Refund / revocation posture

- Launch should support eventual revocation through webhook updates.
- We should not hard-lock an already unlocked user immediately during temporary backend failures.
- If refund handling becomes noisy, we can tighten grace behavior later.

## App state model

The Mac app should support at least these launch/access states:

- `onboardingRequired`
- `permissionsRequired`
- `signedOutTrialReady`
- `paywallRequired`
- `authInProgress`
- `signedInEntitlementUnknown`
- `signedInLimited`
- `unlocked`
- `degradedOfflineUnlocked`
- `lockedNoEntitlement`

Transitions should be explicit and main-actor owned inside the app.

## API surface

All endpoints below are first-pass names and can be adjusted once the backend is scaffolded, but the behavior contract should stay stable.

## Auth endpoints

- `GET /v1/auth/native/start`
  - starts browser auth for the Mac app

- `POST /v1/auth/native/exchange`
  - exchanges a one-time code for native session credentials

- `POST /v1/auth/signout`
  - revokes current session

- `GET /v1/me`
  - returns user profile summary for the active session

## Entitlement endpoints

- `GET /v1/entitlements/me`
  - returns current entitlement snapshot, refresh timestamp, and grace status

- `POST /v1/entitlements/refresh`
  - forces a refresh after purchase or manual restore

## Billing endpoints

- `POST /v1/billing/checkout`
  - creates a Polar hosted checkout session for the current user

- `POST /v1/billing/restore`
  - triggers an explicit restore/sync path when the user asks for it

- `POST /v1/webhooks/polar`
  - receives Polar webhook events

## Website support endpoints

The website only needs a slim contract at launch:

- session-aware `GET /v1/me`
- session-aware `GET /v1/entitlements/me`
- whatever Better Auth web routes are mounted
- static download CTA to the latest DMG URL

The website does not need custom checkout UI for launch.

## Runtime updates

- Clicky uses Sparkle for direct-download app updates.
- The runtime app points at the repo-owned `appcast.xml` feed.
- Release automation is responsible for publishing a notarized DMG, updating `appcast.xml`, and pushing the refreshed feed to the same repository.

## Database model

## Auth tables

Managed by Better Auth and its adapter schema:

- `user`
- `session`
- `account`
- `verification`

## App-owned tables

- `polar_customer_link`
  - `user_id`
  - `polar_customer_id`
  - `email_at_link_time`
  - timestamps

- `entitlement`
  - `user_id`
  - `product_key`
  - `status` (`inactive`, `active`, `revoked`, `refunded`)
  - `source` (`polar`)
  - `granted_at`
  - `refreshed_at`
  - `expires_at` nullable
  - `raw_reference` for provider IDs

- `billing_webhook_event`
  - `provider`
  - `event_id`
  - `event_type`
  - `received_at`
  - `processed_at`
  - `status`
  - unique constraint on `(provider, event_id)`

- `checkout_session_audit`
  - `user_id`
  - `provider`
  - `provider_checkout_id`
  - `product_key`
  - `status`
  - `created_at`
  - `completed_at` nullable

We do **not** add a device licensing table at launch.

## Security and reliability guardrails

- Tokens and API secrets never go into structured logs.
- Polar webhook verification is mandatory.
- Webhook processing must be idempotent.
- Entitlement refresh endpoints should be safe to retry.
- Backend remains stateless beyond database state so Cloudflare scale behavior stays simple.

## Initial implementation order

1. Scaffold `backend/` as a Cloudflare Worker TypeScript service with Hono.
2. Add Drizzle + Neon connection and migrations.
3. Add Better Auth and its schema.
4. Implement native auth start/exchange flow.
5. Implement entitlement read endpoint and app-side state integration.
6. Implement Polar checkout creation and webhook ingestion.
7. Implement restore + refresh endpoints.
8. Wire the Mac app paywall and unlock state machine against those contracts.

## Open assumptions to validate during implementation

- `clicky://` custom URL scheme is the native callback path.
- Google sign-in is the default launch auth method.
- The free taste is measured by successful cloud-backed requests, not wall-clock time.
- The 30-day offline unlock grace window is acceptable for a one-time purchase launch.
