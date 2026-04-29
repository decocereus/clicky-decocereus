# Plan: Clicky Computer Use Integration Contract

Status note:

- Clicky's response-mode contract is now stable across OpenClaw, Codex, and the shared parser path.
- `/Users/amartyasingh/Documents/projects/clicky-background-computer-use` is now the chosen desktop driver foundation.
- `BackgroundComputerUse` has been vendored into this repo under `Packages/BackgroundComputerUse` with a library target for the app and a standalone executable wrapper for driver development.
- Clicky now starts the driver with the app, reflects its permission/runtime state in Studio, and keeps onboarding focused on Accessibility and Screen Recording as first-run prerequisites for guided desktop action.
- The first Clicky-owned computer-use controller/client/action loop is in place: providers can request observe/locate/locate-many, while state-changing actions are policy-gated behind explicit user confirmation.
- Clicky-side contract tests now cover action parsing, policy gating, approved-action validation, result summaries, and recent-action continuation context.
- The OpenClaw plugin now exposes `clicky_request_computer_use`, which lets OpenClaw use a real tool to produce the exact JSON envelope Clicky executes locally.
- Approval requests now get a Clicky-side policy review with risk labels, original user request context, human-readable model-action summaries, policy copy, and compact payload previews instead of showing only raw tool names.
- The action policy now separates read-only tools, low-risk movement/window actions, normal mutations, sensitive/high-impact actions, and blocked sensitive requests. Sensitive requests such as delete, send/submit, purchase/payment, account/security changes, terminal/command execution, and irreversible actions are blocked unless the original user request explicitly asked for that kind of action. Allowed sensitive approvals require a fresh target-window re-observe immediately before execution.
- Approved actions now opportunistically re-read the affected/current window and include that post-action observation in the next assistant turn context.
- The remaining work is hardening the product loop into a polished runtime surface: tutorial autopilot integration, durable packaging/signing checks, and end-to-end Xcode/runtime verification.

This document defines the concrete integration seam between:

- the Clicky macOS app
- the local `BackgroundComputerUse` runtime
- the OpenClaw `clicky-shell` plugin
- Claude and Codex backends inside Clicky

It is deliberately implementation-oriented. The goal is to move straight from this contract into code.

## Decision

Clicky should adopt `BackgroundComputerUse` as its bundled local desktop driver.

The runtime should launch with Clicky itself. Do not use lazy launch as the default product behavior.

The onboarding flow should proactively get the required macOS permissions so the user finishes onboarding with computer-use capability ready:

- Accessibility
- Screen Recording

Do not make the model talk to `BackgroundComputerUse` directly.

Instead:

1. Clicky owns the lifecycle of the local driver from app startup.
2. Clicky owns the onboarding and diagnostics for permissions.
3. Clicky wraps the driver in a Clicky-native computer-use controller.
4. Every backend reaches computer-use through that same Clicky-owned controller.

That keeps:

- the desktop driver local and product-owned
- the product shell coherent
- the backend contract provider-agnostic
- the onboarding story understandable
- the release/signing surface controllable
- the future tutorial autopilot path on one substrate

## Product Goal

Clicky should support:

- guided pointing
- grounded locating
- direct computer-use actions
- multi-step automation
- tutorial autopilot

across:

- OpenClaw
- Codex
- Claude

The user should feel that Clicky itself can observe and act on the desktop.

The model should feel like it is using one stable set of Clicky tools, regardless of backend.

The product should not feel like it depends on a random second app or manually managed local service. Computer use is a Clicky capability.

## What BackgroundComputerUse Already Gives Us

From the cloned repo:

- loopback HTTP runtime with manifest/bootstrap
- app and window discovery
- per-window state reads with screenshot + projected tree
- background-safe actions:
  - click
  - scroll
  - type text
  - press key
  - set value
  - perform secondary action
  - drag / resize / set window frame
- action verification surfaces and state tokens

Relevant files:

- [README.md](/Users/amartyasingh/Documents/projects/clicky-background-computer-use/README.md)
- [RuntimeBootstrap.swift](/Users/amartyasingh/Documents/projects/clicky-background-computer-use/Sources/BackgroundComputerUse/App/RuntimeBootstrap.swift)
- [LoopbackServer.swift](/Users/amartyasingh/Documents/projects/clicky-background-computer-use/Sources/BackgroundComputerUse/API/LoopbackServer.swift)
- [RouteRegistry.swift](/Users/amartyasingh/Documents/projects/clicky-background-computer-use/Sources/BackgroundComputerUse/API/RouteRegistry.swift)
- [WindowStateContracts.swift](/Users/amartyasingh/Documents/projects/clicky-background-computer-use/Sources/BackgroundComputerUse/Contracts/WindowStateContracts.swift)
- [ClickActionContracts.swift](/Users/amartyasingh/Documents/projects/clicky-background-computer-use/Sources/BackgroundComputerUse/Contracts/ClickActionContracts.swift)
- [TextActionContracts.swift](/Users/amartyasingh/Documents/projects/clicky-background-computer-use/Sources/BackgroundComputerUse/Contracts/TextActionContracts.swift)
- [ScrollActionContracts.swift](/Users/amartyasingh/Documents/projects/clicky-background-computer-use/Sources/BackgroundComputerUse/Contracts/ScrollActionContracts.swift)
- [SecondaryActionContracts.swift](/Users/amartyasingh/Documents/projects/clicky-background-computer-use/Sources/BackgroundComputerUse/Contracts/SecondaryActionContracts.swift)
- [PressKeyActionContracts.swift](/Users/amartyasingh/Documents/projects/clicky-background-computer-use/Sources/BackgroundComputerUse/Contracts/PressKeyActionContracts.swift)

This is enough to make Clicky genuinely do computer use.

The repo should be treated as implementation source material to integrate, not as a permanent external runtime boundary. Preserve the standalone executable wrapper only if it remains useful for local development, smoke tests, or debugging.

## What Clicky Still Needs To Own

BackgroundComputerUse is a desktop driver, not the product brain and not the shell.

Clicky still needs to own:

- provider selection
- voice interaction
- cursor overlay / tutorial presence
- response presentation contract
- desktop control policy
- action consent and risk policy
- onboarding permission flow
- user-facing permissions and diagnostics
- runtime packaging / signing / launch behavior
- tutorial autopilot state machine
- model-facing computer-use contract

## Core Architecture

### 1. Bundled local driver runtime

Clicky should treat `BackgroundComputerUse` as a bundled local runtime, not as a remote dependency and not as a user-visible sibling service.

Preferred repo shape:

- bring the driver into this repo under a local package/module path
- split the current executable-only package into:
  - a library/core runtime target that Clicky links
  - an optional standalone executable wrapper for dev/debug
  - preserved tests for route contracts, parsers, and action verification behavior
- keep the Clicky app as the product owner of permission onboarding, runtime state, and diagnostics

Clicky should:

- initialize it during app startup
- avoid lazy launching as the default behavior
- make the runtime ready or explain what permission/setup is missing during onboarding
- verify readiness through the runtime bootstrap contract
- show permission/setup state in Studio
- recover if the runtime fails or is restarted during development

If the loopback HTTP surface remains internally useful, Clicky may keep it behind the controller. In that case Clicky must validate:

- contract version
- runtime freshness
- base URL shape
- process/app ownership where applicable
- stale manifest state during development

The app should not rely on a temp manifest as the primary production trust boundary.

This should be encapsulated in a new local client layer, not scattered through `CompanionManager`.

### 2. Clicky computer-use controller

Add a Clicky-owned control surface above the raw driver:

- `ClickyComputerUseController`
- `ClickyComputerUseClient`
- `ClickyComputerUseRuntimeState`
- `ClickyComputerUseObservation`
- `ClickyComputerUseActionRequest`
- `ClickyComputerUseActionResult`

This layer should translate between:

- raw `BackgroundComputerUse` route DTOs
- Clicky's model-facing tool/action contract
- Clicky's cursor/tutorial shell needs

This is the key abstraction boundary.

Do not expose the raw driver contracts directly to every provider.

### 3. Provider-agnostic computer-use action loop

All three backends should reach the same Clicky computer-use surface.

That means the loop becomes:

1. model decides what it wants to do
2. Clicky validates and executes the action locally
3. Clicky re-reads state
4. Clicky decides whether to continue, present, or recover

The model remains responsible for reasoning.
Clicky remains responsible for desktop execution and product behavior.

Before any action is dispatched, Clicky must apply a product-level policy gate. Observation and locating are read-only. Movement/window actions such as scroll, drag, resize, and set-window-frame are low-risk but still approval-gated while automation is maturing. Ordinary mutations such as click, type, press key, set value, and secondary action require explicit approval. Sensitive actions that mention delete/remove, send/submit, purchase/payment, account/security changes, terminal/command execution, or irreversible/destructive effects are blocked unless the original user request explicitly asked Clicky to perform that exact kind of action. Allowed sensitive actions require approval plus a fresh target-window observation immediately before execution.

## Recommended Clicky-Native Computer Use Contract

Start with a bounded tool/action family:

- `clicky_observe`
- `clicky_locate`
- `clicky_locate_many`
- `clicky_click`
- `clicky_type_text`
- `clicky_press_key`
- `clicky_scroll`
- `clicky_set_value`
- `clicky_secondary_action`

Later:

- `clicky_drag`
- `clicky_resize_window`
- `clicky_set_window_frame`

### `clicky_observe`

Purpose:

- get the current app/window surface in a model-facing form

Suggested output:

- target app + window identity
- screenshot path or bytes
- compact projected tree summary
- state token
- focused element
- safety notes

This should be the main "read state" primitive.

### `clicky_locate`

Purpose:

- resolve one target to a grounded coordinate

Suggested request:

```json
{
  "windowID": "optional-live-window-id",
  "target": "Save button",
  "hints": {
    "role": "button",
    "text": "Save",
    "relativeArea": "lower right"
  }
}
```

Suggested response:

```json
{
  "found": true,
  "x": 820,
  "y": 460,
  "screenNumber": 1,
  "label": "Save button",
  "confidence": 0.93,
  "stateToken": "opaque-token"
}
```

Implementation note:

- prefer `get_window_state` plus projected-tree/activation-point evidence first
- fall back to screenshot/vision only when semantic evidence is not enough
- do not dump a full raw AX tree into the model

### `clicky_locate_many`

Purpose:

- resolve an ordered set of targets for walkthroughs

Suggested output:

- ordered target list
- per-target confidence
- unresolved items when present

This should feed directly into `clicky_present` walkthrough mode.

### Action tools

Each action tool should return:

- whether it dispatched
- whether the effect verified
- pre/post state token
- warnings
- compact explanation of what happened

Do not hide ambiguity.

If an action was sent but not verified, the model should know that.

### Coordinate and state semantics

Clicky should not allow ambiguous coordinate handoff between screenshot space, window space, display space, logical points, and physical pixels.

Every grounded target or action result should carry enough metadata for safe execution and presentation:

- coordinate space
- x/y
- screen number or display identifier
- screenshot size
- target window identity
- window frame when available
- state token
- confidence
- evidence source:
  - projected tree
  - accessibility activation point
  - screenshot/vision
  - manual/model estimate

Provider-facing presentation points can remain in Clicky's existing screenshot coordinate contract, but the controller should retain richer internal metadata.

## Backend Integration Strategy

### OpenClaw

OpenClaw should get first-class `clicky-shell` plugin tools for computer use.

Add tools to the existing plugin:

- `clicky_observe`
- `clicky_locate`
- `clicky_locate_many`
- `clicky_click`
- `clicky_type_text`
- `clicky_press_key`
- `clicky_scroll`
- `clicky_set_value`
- `clicky_secondary_action`

The plugin should not implement the desktop logic itself.

It should route to the registered Clicky shell, and Clicky should execute through the bundled BackgroundComputerUse runtime via the Clicky controller.

### Codex and Claude

Codex and Claude should not be second-class.

They should use the same Clicky computer-use controller, even if their interaction style differs from OpenClaw plugin tools.

Recommended path:

- add a Clicky-owned internal action loop for non-OpenClaw backends
- models emit structured action intents
- Clicky executes those intents through the same controller
- Clicky re-reads state and feeds back results
- Clicky enforces max-steps, cancellation, state-token threading, and policy gates

This means:

- same capabilities
- same verification
- same desktop semantics
- differences become model reasoning quality, not Clicky feature gaps

## How Tutorial Autopilot Fits

The tutorial system should eventually use the same controller.

The loop should be:

1. tutorial lesson step says what needs to happen
2. model chooses whether to explain, locate, or act
3. Clicky executes through computer-use controller
4. Clicky verifies state
5. Clicky advances or asks for correction

This is how we get:

- "show me"
- "do it for me"
- "follow the whole tutorial"

on the same substrate.

Do not build tutorial-specific desktop automation separate from the main computer-use layer.

## Permission And Launch Model

Clicky must not lose control of user trust.

Studio should show:

- whether the bundled computer-use runtime is running
- Accessibility permission state
- Screen Recording permission state
- whether the driver/controller is reachable
- last action/read health
- user-facing repair steps

Onboarding should request and verify permissions before declaring the user ready.

Clicky should not require the user to think in terms of "another app" or "random local service."

It should feel like Clicky owns the capability.

## Recommended File/Module Additions In Clicky

### New computer-use client layer

- `leanring-buddy/ClickyComputerUseClient.swift`
- `leanring-buddy/ClickyComputerUseController.swift`
- `leanring-buddy/ClickyComputerUseModels.swift`
- `leanring-buddy/ClickyComputerUseRuntimeState.swift`

### New provider-facing control loop pieces

- `leanring-buddy/ClickyComputerUseActionContract.swift`
- `leanring-buddy/ClickyComputerUseActionExecutor.swift`
- `leanring-buddy/ClickyComputerUseObservationFormatter.swift`

### OpenClaw plugin expansion

- extend `plugins/openclaw-clicky-shell/index.ts`

## Recommended Phasing

### Phase 1: bundled runtime + full internal controller surface

- bring `BackgroundComputerUse` into the Clicky repo as a local module/package
- split the driver into a linkable runtime/library plus optional standalone executable wrapper
- initialize the runtime with the Clicky app
- wire onboarding permission checks for Accessibility and Screen Recording
- call/read bootstrap readiness through a Clicky-owned client/controller
- show runtime readiness and permission repair state in Studio
- add internal wrappers/models for the full current driver surface:
  - observe/window state
  - locate
  - locate many
  - click
  - scroll
  - type text
  - press key
  - set value
  - secondary action
  - drag
  - resize window
  - set window frame
- keep provider exposure policy-gated

Success condition:

- Clicky launches with its computer-use runtime initialized, onboarding can get the required permissions, Studio can explain readiness, and the controller can address the full current driver surface internally

### Phase 2: observe + locate provider exposure

- implement `clicky_observe`
- implement `clicky_locate`
- implement `clicky_locate_many`
- expose these first to OpenClaw and the non-OpenClaw structured action loop

Success condition:

- backends can ask Clicky to ground targets without guessing raw coordinates

### Phase 3: policy-gated safe actions

- implement `clicky_click`
- implement `clicky_press_key`
- implement `clicky_type_text`
- implement `clicky_scroll`
- implement `clicky_set_value`
- implement `clicky_secondary_action`
- continue tightening action-risk policy and confirmation copy from live Xcode/runtime feedback

Success condition:

- Clicky can complete common desktop workflows with read-act-read verification while preserving user trust

### Phase 4: provider parity

- OpenClaw plugin tools live
- Codex structured action loop live
- Claude structured action loop live

Success condition:

- all three providers use the same local execution substrate

### Phase 5: tutorial autopilot

- connect tutorial playback to the same action controller
- allow guided execution of lesson steps
- add pause/review/recovery behavior

Success condition:

- Clicky can both teach and execute through the same contract

## What Not To Do

- do not dump the full raw AX tree into the model by default
- do not let providers bypass Clicky and talk to the local driver directly
- do not build OpenClaw-only computer use
- do not create a tutorial-only automation path
- do not make the user manage raw ports or manifest files manually
- do not make lazy launch the default product behavior
- do not ship a separate user-visible driver app unless there is a strong signing/packaging reason
- do not expose dangerous action tools to providers without Clicky's policy gate

## Open Questions

1. What exact in-repo layout should we use for the imported driver module?
2. Should the runtime keep loopback HTTP internally, or should Clicky call the runtime through direct Swift APIs after the package split?
3. What action categories require user confirmation in v1?
4. Should the first provider-exposed tools be strictly `locate`/`observe`, or should we expose low-risk actions at the same time behind policy?
5. What is the cleanest model-facing structured action format for Codex and Claude inside Clicky?

## Recommended Immediate Next Step

Implement the revised Phase 1 first:

- import/refactor `BackgroundComputerUse` into the Clicky repo as a bundled module
- initialize it with the app
- move permission readiness into onboarding and Studio
- create the Clicky controller/client/models around the full current driver surface

Then expose `clicky_observe`, `clicky_locate`, and `clicky_locate_many` to providers before opening policy-gated action tools.

That gives Clicky the strongest foundation for full computer use without making the user manage another service or letting providers bypass the product shell.
