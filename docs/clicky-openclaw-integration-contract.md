# Clicky x OpenClaw Integration Contract

Status note:

- the first stable plugin surface described here now exists in code
- registration, heartbeat, status, bind-session, and prompt-injection behavior are implemented
- tool-driven final presentation for Clicky turns is now the preferred OpenClaw path
- the main remaining gap is deeper trust semantics and stronger durability than process-memory registration alone

## Goal

Make Clicky the desktop shell for OpenClaw.

OpenClaw should keep owning:
- agent cognition
- memory
- tool/runtime execution
- session orchestration

Clicky should keep owning:
- push-to-talk capture
- desktop screen context capture
- cursor presence and pointing UI
- local speech playback
- companion personality/presence shell

The integration must work for:
- local OpenClaw Gateways
- remote hosted OpenClaw Gateways over `wss://`

## Core Direction

The first stable integration surface is an **installable OpenClaw plugin**.

Why this shape:
- it gives OpenClaw a first-class, explicit concept of Clicky
- it keeps the integration namespaced and observable
- it avoids baking Clicky-specific assumptions into the app or into OpenClaw core
- it supports remote Gateways because Clicky already talks outward to OpenClaw over Gateway/WebSocket

## Transport Model

Do **not** assume a remote OpenClaw instance can call into a desktop-local Clicky process directly.

That breaks as soon as OpenClaw is hosted remotely.

The safe default is:
- Clicky connects outward to OpenClaw Gateway
- Clicky identifies itself to the `clicky-shell` plugin over plugin-owned Gateway methods
- OpenClaw stores that registration as shell metadata
- when a shell is fresh and explicitly bound to a session, Clicky syncs the current turn's shell prompt context through the plugin and the plugin appends that guidance into prompt build so Clicky's response contract lands after the base agent prompt
- OpenClaw continues sending turns/results through the Gateway session model
- Clicky remains the local shell that speaks, points, and renders presence

This means remote readiness comes from **Clicky dialing out**, not OpenClaw dialing in.

## Plugin Responsibilities

The `clicky-shell` plugin should own:
- plugin config schema and onboarding metadata
- shell registration state
- Clicky-specific Gateway RPC methods
- Clicky status/introspection command/tool surfaces
- prompt injection for bound/fresh Clicky shells so OpenClaw runs automatically understand the active shell capabilities
- the server-side path for per-turn Clicky runtime/system prompt context, so Clicky does not serialize that prompt into raw user message payloads
- the preferred tool-driven presentation surface for answer-only, single-point, and walkthrough-style Clicky replies
- the future handshake that tells OpenClaw what Clicky capabilities are currently online

The plugin should **not** own:
- model/provider execution
- desktop capture itself
- speech synthesis vendor logic
- cursor rendering

## First Plugin Surface

### Plugin id

`clicky-shell`

### First config fields

- `shellLabel`
  User-facing label for the shell integration.
- `registrationTtlMs`
  How long a shell registration remains fresh before it is treated as stale.
- `allowRemoteDesktopShell`
  Policy toggle for remote shell registration acceptance.

### First Gateway methods

- `clicky.status`
  Read-only status summary for the plugin and known shell registrations.
- `clicky.shell.register`
  Register a Clicky desktop shell with capability metadata.
- `clicky.shell.heartbeat`
  Refresh a shell registration so OpenClaw knows the shell is still alive.
- `clicky.shell.status`
  Return the plugin-side status for a specific Clicky shell id.
- `clicky.shell.bind_session`
  Explicitly bind a registered Clicky shell to an OpenClaw session key.
- `clicky.shell.set_prompt_context`
  Sync the current turn's Clicky runtime/system prompt so the plugin can inject it during prompt build without exposing it in the raw user message.

### First user-facing surfaces

- `/clicky`
  Simple operator command to inspect Clicky shell status.
- `clicky_status`
  Agent-visible tool that reports whether a Clicky shell is connected and what it can do.
- `clicky_present`
  Agent-visible tool that lets OpenClaw finish a Clicky turn in `answer`, `point`, `walkthrough`, or `tutorial` mode using one explicit schema instead of relying on prompt-only JSON formatting.

## Shell Registration Payload

The first registration payload should include:

- `agentIdentityName`
  The upstream OpenClaw agent identity.
- `shellId`
  Stable desktop-shell identifier.
- `shellLabel`
  Human-friendly shell/device label.
- `bridgeVersion`
  Clicky bridge/plugin protocol version.
- `shellProtocolVersion`
  Version of the Clicky shell contract.
- `clickyShellCapabilityVersion`
  Version of the Clicky shell capability payload.
- `capabilities`
  Example: `["push_to_talk", "screen_capture", "cursor_overlay", "local_tts"]`
- `clickyPresentationName`
  Clicky-local presentation name, which may match the upstream identity or override it locally.
- `personaScope`
  Whether Clicky is using the upstream identity directly or applying a Clicky-local override.
- `runtimeMode`
  Example: `desktop`, `debug`, `production`
- `screenContextTransport`
  How screen context is delivered to the agent.
- `cursorPointingProtocol`
  The structured assistant response contract the shell expects for speech plus pointing.
- `speechOutputMode`
  How reply audio is presented by the shell.
- `supportsInlineTextBubble`
  Whether the shell currently supports inline cursor-side text rendering.
- `sessionKey`
  The OpenClaw session the shell is currently attached to, if any.
- `registeredAt`
  Timestamp supplied by Clicky for debugging.

## Capability Ownership

The long-term capability split should be:

- OpenClaw thinks
- Clicky presents

Concrete interpretation:
- OpenClaw decides what to say and what to point at
- Clicky decides how that is spoken, shown, and animated on the user’s machine
- For OpenClaw-backed Clicky turns, the preferred finish path is now a `clicky_present` tool call that produces the same structured envelope the app already consumes internally. Raw structured JSON remains a fallback during migration.

## Remote-Ready Behavior

For remote OpenClaw:
- Studio stores a remote Gateway URL and token
- Clicky connects outbound to the remote Gateway
- the `clicky-shell` plugin accepts Clicky registration over the same Gateway connection
- no inbound desktop port exposure is required

## Future Steps After This Contract

1. Ship the installable native OpenClaw plugin scaffold.
2. Show plugin install/setup state in Clicky Studio.
3. Teach Clicky to call `clicky.shell.register` and `clicky.shell.heartbeat`.
4. Teach Clicky to read `clicky.shell.status` and update `clicky.shell.bind_session`.
5. Keep prompt-context syncing on the plugin path rather than concatenating runtime instructions into raw user turns.
6. Add the explicit identity handshake so OpenClaw knows Clicky is a trusted shell integration.
7. Route more shell-specific actions through the plugin as needed.
