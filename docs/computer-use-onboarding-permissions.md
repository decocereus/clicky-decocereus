# Computer Use Onboarding Permission Note

Date: 2026-04-28

## Context

During a live OpenClaw-backed computer-use tweet draft test, the flow succeeded after the user approved macOS permission prompts for a `node` process during the task. The task eventually opened the X composer and typed `hello world`, but the permission prompts appeared in the middle of execution instead of during Clicky's onboarding.

That is a poor first-run experience. Computer use should feel ready before the user gives Clicky a task, not stall halfway through a live action while macOS asks about a helper/runtime process.

The canonical runtime source of truth is [`actuallyepic/background-computer-use`](https://github.com/actuallyepic/background-computer-use). Clicky's onboarding, plugin schema, and route forwarding should follow that runtime's documented permission model, API flow, route names, screenshots-as-ground-truth guidance, and optional runtime cursor contract.

## Observed Flow

Gateway logs for the successful run show this rough sequence:

1. A first assistant turn declined to draft without a topic.
2. The next task started the computer-use loop.
3. OpenClaw called `list_windows`.
4. OpenClaw called `get_window_state`.
5. OpenClaw called `list_apps`.
6. OpenClaw called `list_windows` again.
7. Clicky completed the queued runtime actions and the final response said the composer had been opened and `hello world` had been typed as a draft.

The user observed two macOS prompts during that flow:

- a permission prompt for a `node` process before or while opening the composer
- a Screen Recording prompt for a `node` process before the text appeared

After approving those prompts, the flow completed.

## Product Requirement

Clicky onboarding must account for every permission needed by the actual computer-use path before the user runs their first task.

The onboarding flow should remain lightweight and Clicky-like, but it must not leave users discovering helper-process permissions mid-action. If the current OpenClaw/node helper architecture requires macOS TCC grants for `node`, Clicky should surface that readiness gap early and guide the user through it intentionally.

## Permissions To Inventory

Clicky's existing onboarding already covers:

- Microphone
- Accessibility
- Screen Recording
- Screen Content / ScreenCaptureKit access

Computer use onboarding must also verify the active execution path for:

- Clicky app Accessibility
- Clicky app Screen Recording
- Clicky app ScreenCaptureKit / shareable content readiness
- BackgroundComputerUse runtime readiness
- OpenClaw Gateway process readiness when OpenClaw is selected
- `node` helper Accessibility if the Gateway/runtime path triggers it
- `node` helper Screen Recording if the Gateway/runtime path triggers it

## Implementation Direction

Do not add another late fallback prompt around individual actions. The right fix is a readiness gate before computer use starts.

Recommended shape:

1. Add a Computer Use readiness step to onboarding and Studio.
2. Run a harmless permission preflight that exercises the same process boundary used by live computer use.
3. Show only missing items, with short labels and actions.
4. If macOS will display a prompt for `node`, explain that it is Clicky's local OpenClaw helper.
5. Persist readiness state, but always re-check before a task because TCC permissions can be revoked.
6. Keep Auto Approved as the happy path once all required macOS permissions are granted.

## Acceptance Criteria

- A new user can complete onboarding and then run an OpenClaw computer-use task without a surprise macOS permission prompt mid-task.
- If permissions are missing, Clicky explains what is missing before the task starts.
- Studio shows the same readiness truth in the Computer Use section.
- The model does not need to handle permission discovery as part of normal task planning.
- The runtime still fails cleanly if permissions are revoked after onboarding.
