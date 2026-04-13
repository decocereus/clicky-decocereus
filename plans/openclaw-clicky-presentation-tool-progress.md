# OpenClaw Clicky Presentation Tool Progress

Last stable pushed checkpoint before this slice:

- `5294601` — `feat: harden clicky structured response and pointing flow`

## Goal

Move OpenClaw-backed Clicky turns away from prompt-only JSON formatting and toward a tool-driven final presentation path, without losing the current structured-response fallback that already works.

## What Is Implemented

### Plugin-side presentation tool

- `clicky_present` now exists as a real agent-visible tool in:
  - `plugins/openclaw-clicky-shell/index.ts`
  - `plugins/openclaw-clicky-shell/openclaw.plugin.json`
- The tool supports four modes:
  - `answer`
  - `point`
  - `walkthrough`
  - `tutorial`
- The tool validates:
  - non-empty `spokenText`
  - mode-compatible point counts
  - explanations on non-`answer` modes
  - point coordinate/label basics
- The tool returns the same structured envelope Clicky already understands, so the app-side execution path stays intact.

### Plugin prompt and interception changes

- The prompt path now appends explicit `clicky_present` tool guidance after the synced Clicky prompt context instead of relying only on the plugin's default fallback prompt.
- The reply interceptor now checks for a pending `clicky_present` tool result before:
  1. accepting raw structured JSON already in the reply
  2. using hidden normalization
- There is best-effort session tracking using:
  - `sessionKey`
  - `sessionId`
  - a transport-session to session-key map

### App-side contract alignment

- The shared response parser now understands an optional `mode` field in:
  - `leanring-buddy/ClickyAssistantResponseContract.swift`
- Diagnostics now log the parsed mode in:
  - `leanring-buddy/ClickyAgentTurnDiagnostics.swift`
- Repair prompts in:
  - `leanring-buddy/CompanionManager.swift`
  now teach the optional `mode` field too.

### Docs and guidance updated

- `AGENTS.md`
- `leanring-buddy/AGENTS.md`
- `README.md`
- `docs/architecture.md`
- `docs/clicky-openclaw-integration-contract.md`
- `plugins/openclaw-clicky-shell/README.md`

These now describe `clicky_present` as the preferred OpenClaw final presentation path, with raw structured JSON kept as fallback during migration.

## What Is Not Done Yet

### Not live-verified

The code has not yet been live-verified against the running gateway/plugin because we deliberately did not:

- reinstall the local `clicky-shell` plugin
- restart the OpenClaw gateway

That was intentional to preserve the current runtime during iteration unless the user explicitly wants the disruption.

### Locator tool not implemented

`clicky_locate` / `clicky_locate_many` is still pending.

That is the next meaningful implementation phase, but it depends on confirming the cleanest plugin-to-shell request path for asking Clicky to resolve coordinates from the live screen context.

### Old fallback path still present

We still keep:

- raw structured JSON parsing
- hidden normalization
- current repair path

This is intentional. The migration is additive right now.

## Main Open Questions

1. Does the live OpenClaw runtime pass a stable enough session identifier into `clicky_present` tool execution for the stored tool result to be recovered reliably in `before_agent_reply`?
2. Does `before_agent_reply` expose both `sessionKey` and `sessionId` in practice, or only `sessionKey`?
3. Is `structuredContent` from the tool callback surfaced usefully enough in the live runtime, or are we effectively depending only on the cached JSON string right now?
4. When the model calls `clicky_present`, does it consistently stop cleanly afterward, or does it still tend to add prose after the tool call?

## First Verification Pass To Run

After explicit user approval to reload the plugin/gateway, verify these four turn types:

1. Answer-only
   - Example: general guidance, no screen grounding
   - Expected: `clicky_present` with `mode=answer`, no points

2. Single-point detailed explanation
   - Example: "what does this one button do?"
   - Expected: `clicky_present` with `mode=point`, exactly one point, explanation present

3. Narrated walkthrough
   - Example: steering wheel or gearbox walkthrough
   - Expected: `clicky_present` with `mode=walkthrough`, multiple points, explanations on every point

4. Ambiguous or low-confidence screen case
   - Example: blurry screenshot or vague target
   - Expected: answer-only fallback, or raw structured JSON fallback if tool path is missed

## If The Tool Path Fails Tomorrow

Check in this order:

1. Whether `clicky_present` appeared in the live plugin's advertised tools.
2. Whether the tool callback ran at all.
3. Whether the callback saw a usable `sessionId`.
4. Whether `before_agent_reply` saw the same session identity.
5. Whether the model added prose after the tool call.

If the callback runs but the pending result is not recovered, the likely next fix is to make the session handoff explicit instead of inferred.

## Next Implementation Phase

After the first live verification:

1. Decide whether the session handoff is reliable enough to keep.
2. Start `clicky_locate` or `clicky_locate_many`.
3. Use the existing element-location path as the grounding primitive, not a new coordinate system.
4. Only after tool reliability is proven, trim the old repair and normalization path.

## Practical Pickup Point

Tomorrow, start here:

- review `plugins/openclaw-clicky-shell/index.ts`
- reload the live plugin/gateway only if the user wants verification
- run the four-turn verification matrix above
- inspect logs for whether `clicky_present` is actually winning before fallback

Do not begin by deleting the old JSON/repair path. First prove the tool path works live.
