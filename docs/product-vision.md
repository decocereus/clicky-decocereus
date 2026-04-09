# Clicky Product Vision

## Core Product

Clicky is the desktop shell for AI agents.

It lives next to the cursor, sees the user’s screen, captures spoken intent,
and turns an agent’s thinking into something visually and verbally useful on
the desktop.

The important distinction is:

- OpenClaw or another agent runtime remains the **agent**
- Clicky becomes the **shell**

That means Clicky owns the user-facing desktop experience, while the integrated
agent runtime keeps its own cognition, memory, and execution model.

## Identity Model

This project must not confuse the integrated agent’s identity.

If a user connects an OpenClaw agent like `Zuko`, then:

- the upstream agent is still **Zuko**
- Clicky does **not** replace that identity
- Clicky may present Zuko differently **inside Clicky only**

So the identity model is:

- **Upstream agent identity**: owned by OpenClaw
- **Clicky-local presentation**: owned by Clicky
- **Shell capability contract**: owned by Clicky and versioned explicitly

Examples of Clicky-local presentation:

- display name inside Clicky
- voice selection
- cursor-side icon/avatar
- color treatment
- shell-specific persona notes

These should not automatically leak back into the upstream OpenClaw identity.

## Persona Rules

Users should have a clear choice:

1. **Use existing OpenClaw identity**
   Clicky presents the agent as-is.

2. **Override only inside Clicky**
   Clicky changes the local presentation without rewriting the upstream agent.

This means Clicky needs a persona scope toggle and clearly worded copy so users
understand what changes globally vs locally.

The shell payload should also stay explicit about:

- protocol version
- capability version
- screen context transport
- cursor pointing protocol
- speech output mode

## Plugin-First Integration

The preferred integration path is an installable **Clicky plugin** for
OpenClaw.

Why:

- it makes Clicky a first-class integration instead of loose glue
- it gives OpenClaw explicit knowledge of the Clicky shell
- it is easier to support remote OpenClaw instances cleanly
- it creates a reusable shape that other compatible runtimes may eventually support

The plugin should own:

- Clicky shell registration
- heartbeat/presence
- shell capability metadata
- session binding metadata
- Clicky-specific gateway methods

## Remote Support

Clicky must work with both:

- local OpenClaw
- remote hosted OpenClaw

The transport model should stay:

- Clicky connects outward to OpenClaw
- OpenClaw does not need to call into a desktop-local process

That is what keeps the integration viable for hosted deployments.

## UX Direction

The desktop experience should become richer over time, but without clutter.

### Near-term UI principles

- user-oriented copy
- explicit setup flow
- clear distinction between install, enable, connect, and ready
- avoid showing low-level details unless they help a user take action

### Future cursor-shell customization

These are explicitly in scope for later:

- custom cursor-side icon/avatar
- custom icon colors
- custom shell colors
- text rendered next to the cursor when useful
- richer thinking/response animations
- user-selectable appearance packs

### Voice customization

These are also in scope:

- choose different voices
- support more TTS providers
- allow Clicky-local voice changes without mutating the upstream agent identity

## Current Roadmap Order

1. Stabilize the local shell/runtime loop.
2. Build the proper Studio configuration surface.
3. Add OpenClaw Gateway support.
4. Ship the first Clicky plugin scaffold for OpenClaw.
5. Register Clicky as a live shell and keep heartbeats/session binding current.
6. Deepen the trust + identity handshake.
7. Expand local persona and appearance customization.

## Product Test

The product is on the right track if a user can say:

"My OpenClaw agent is still my OpenClaw agent. Clicky just makes that agent
feel alive and useful on my desktop."
