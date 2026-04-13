# Diagnostics And Agent-Mediated Paywall Plan

Status note:

- most of the launch-trial and paywall mechanics described here have landed
- support-mode gating, diagnostics redaction, backend-backed trial state, welcome-turn handling, and paywall-turn enforcement now exist
- what remains is live verification and polish rather than first-pass implementation

> Execution plan for the next product slice after launch infrastructure: support-mode diagnostics, trial credits, welcome prompt injection, and the connected-agent paywall flow.

## Product Direction

This slice should make Clicky feel like a real product, not just a shell with billing bolted on.

The core experience we are aiming for:

1. User downloads Clicky and completes setup.
2. User connects either:
   - a BYO API path, or
   - an OpenClaw-backed agent
3. Clicky does **not** show a paywall yet.
4. Once setup is complete, Clicky injects a welcome/system prompt to the connected agent.
5. The agent explains what Clicky can do and encourages the user to try it.
6. The user gets a finite number of trial credits.
7. Credits are consumed only by real assisted turns.
8. When credits hit zero, the **next** turn becomes a paywall turn.
9. The connected agent explains that the trial is over and that Clicky now needs to be purchased.
10. At the same time, Clicky-native UI shifts into a locked purchase mode with stronger visual treatment.

## Non-Goals For This Slice

- Do not build multi-tier pricing.
- Do not build device-bound licensing.
- Do not build an advanced public billing UI on the website.
- Do not overcomplicate onboarding before we have the trial-credit model working.
- Do not rely on ad hoc prints for debugging.

## Core Decisions

- Trial should be **credit-based**, not time-based and not message-count-based.
- Credits are backend-authoritative.
- Credits are granted only after setup is complete.
- Credits should not be consumed by system-generated onboarding/welcome instructions.
- Credits should be consumed only by successful user-assisted turns.
- There is **no soft warning** before the hard stop.
- Once credits hit zero, the next turn is converted into the paywall turn.
- After paywall activation, the main Clicky experience is locked down and the purchase path becomes the primary remaining action.

## Diagnostics Plan

Diagnostics comes first because it makes the paywall and credit system debuggable.

### Goals

- Keep Diagnostics hidden from normal users unless support mode is enabled.
- Keep the in-app diagnostics buffer useful for auth, billing, credits, and paywall debugging.
- Ensure secrets and tokens are redacted before they are copied/exported.

### Required work

#### 1. Support mode gating

- Add a durable support-mode toggle in Studio.
- Hide the Diagnostics section from sidebar navigation when support mode is off.
- Keep the normal user flow free of technical state unless the user explicitly opts into support mode.

#### 2. Safer diagnostics output

- Redact tokens, secrets, API keys, exchange codes, and auth query params before they enter the diagnostics buffer.
- Keep copy/export actions available in Diagnostics.
- Export a support report with:
  - timestamp
  - account state
  - entitlement state
  - billing state
  - recent redacted logs

#### 3. High-signal event logging

- Add durable app logs for:
  - auth start
  - auth callback received
  - auth exchange success/failure
  - entitlement refresh
  - checkout start
  - billing callback success/cancel
  - trial credit decrement
  - paywall activation
  - paywall unlock

### Acceptance criteria

- Diagnostics is hidden when support mode is off.
- Diagnostics is available when support mode is on.
- Copy/export output is redacted.
- Critical auth/billing/paywall events are visible in logs.

## Trial Credit Plan

### Trial model

- Each newly activated user gets `10` trial credits.
- Credits are granted once setup is complete.
- Credits are stored in the backend so they are durable across reinstalls and sign-ins.

### Backend data model

Add a trial-credit record or equivalent backend-backed user state with:

- `user_id`
- `initial_credits`
- `remaining_credits`
- `setup_completed_at`
- `trial_activated_at`
- `paywall_activated_at`
- timestamps

### Credit decrement rules

Credits should decrement only when:

- the user initiates a real assisted turn
- the turn completes successfully enough to count as real usage

Credits should **not** decrement for:

- setup
- auth
- purchase
- restore
- system prompt injection
- internal welcome instructions

### Backend endpoints / behavior

We likely need:

- a way to read current trial state
- a way to decrement credits atomically
- a way to detect paywall activation atomically

### Acceptance criteria

- New users get 10 credits after setup completion.
- Credits survive reinstall/sign-in because they are backend-backed.
- Credits decrement only on real usage.
- Once credits hit zero, the next eligible turn is flagged as the paywall turn.

## Welcome Prompt Injection Plan

### Goal

Use the connected agent to sell the value of Clicky through the experience itself.

### Trigger

After setup is complete and the user is ready to use Clicky for real.

### Welcome prompt content

The injected system prompt should tell the connected agent:

- what Clicky is
- what capabilities Clicky unlocks
- how the user can try it
- that this is a limited trial experience

### Output requirements

The agent should:

- explain benefits clearly
- suggest a few useful first tasks
- sound helpful, not salesy

### Acceptance criteria

- Welcome prompt is injected exactly once per activated user/device state as intended.
- It does not consume trial credits.
- The resulting agent response helps the user get to value quickly.

## Paywall Turn Injection Plan

### Trigger

When `remaining_credits == 0` and the next eligible assisted turn starts.

### Behavior

Instead of fulfilling the requested task normally:

- inject a strict system instruction to the connected agent
- tell it the trial is exhausted
- ask it to summarize the user’s experience so far
- ask it to explain that Clicky now requires purchase to continue

### Constraints

- Keep the instruction tight and deterministic.
- Do not let the agent partially fulfill the blocked task.
- Do not make the message generic or robotic.

### Acceptance criteria

- The paywall turn happens automatically on the first turn after credits run out.
- The agent explains the paywall consistently.
- The blocked task is not completed beyond the paywall boundary.

## Locked UI State Plan

### Goal

When the paywall activates, Clicky-native UI should communicate that state clearly and elegantly.

### Desired behavior

- Disable the main companion experience.
- Keep the purchase path available.
- Keep minimal recovery paths available internally.
- Change cursor/panel visuals so the lock state feels intentional and premium.

### Candidate UI changes

- different cursor motion or idle behavior
- altered floating or suspended state
- locked companion panel mode
- purchase-focused primary action

### Acceptance criteria

- The lock state is unmistakable.
- Purchase action is obvious.
- The app does not feel broken or bugged.

## Unlock Path

### Behavior

After successful purchase:

- webhook activates entitlement
- app refreshes entitlement
- paywall state clears
- Clicky returns to normal operating mode

### Acceptance criteria

- Purchase unlocks Clicky without requiring manual debugging.
- Post-purchase refresh is understandable and reliable.

## Implementation Order

### Slice 1. Diagnostics hardening

- support-mode gating
- redaction
- support export
- high-signal auth/billing/paywall logs

### Slice 2. Trial credit backend model

- schema
- trial state read/decrement logic
- paywall activation state

### Slice 3. Mac app trial/paywall state

- read trial state
- represent locked/unlocked/trial state in the app
- add trial/billing diagnostics fields

### Slice 4. Welcome prompt injection

- detect setup completion
- inject welcome system prompt

### Slice 5. Paywall turn injection

- inject paywall system prompt when credits are exhausted

### Slice 6. Locked visuals

- lock down the panel
- purchase-focused cursor/panel treatment

### Slice 7. Real purchase verification

- verify that purchase clears the paywall in the real flow

## Immediate Next Task

The next coding slice should be:

1. finish diagnostics hardening
2. add dedicated logs for trial/purchase/paywall state transitions
3. then add the backend trial-credit model

## Notes

- This plan should evolve as we learn from live auth and billing tests.
- Keep product language aligned with “credits”, not “messages”.
- Do not introduce a soft warning step unless the product decision changes later.
