# OpenClaw Clicky Presentation Tool Progress

Last stable pushed checkpoint before this slice:

- `5294601` — `feat: harden clicky structured response and pointing flow`

## Goal

Move OpenClaw-backed Clicky turns away from prompt-only JSON formatting and toward a tool-driven final presentation path, without losing the current structured-response fallback that already works.

## Current Verification Result

The live local Gateway path was verified on April 21, 2026 after enabling
`clicky-shell` in `~/.openclaw/openclaw.json` and restarting the Gateway.

Direct app-like Gateway `agent` calls now pass for:

- `answer`
- `point`
- `walkthrough`
- ambiguous fallback as `answer`

Each run called `clicky_present` once with zero tool failures and returned the
structured JSON envelope that Clicky's Mac app parser expects.

Important runtime finding: OpenClaw treats a tool-only final response as an
empty user-visible response on the direct Gateway `agent` method. The working
path is for `clicky_present` to return finalization instructions, then for the
model to emit the exact JSON envelope as the final assistant message.

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
- The tool validates the same structured envelope Clicky already understands,
  then instructs the model to emit that exact envelope as the final assistant
  message so the app-side execution path stays intact.

### Plugin prompt changes

- The prompt path now appends explicit `clicky_present` tool guidance after the synced Clicky prompt context instead of relying only on the plugin's default fallback prompt.
- The prompt path handles OpenClaw's internal session keys, including both
  `agent:<agentId>:<sessionKey>` and
  `agent:<agentId>:explicit:<sessionKey>`, so Clicky's shorter bound session key
  still receives shell prompt context.
- The old cached-tool-result recovery and hidden normalizer paths have been
  deleted. The app-facing path is now tool call plus final JSON emission.

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

### Locator tool not implemented

`clicky_locate` / `clicky_locate_many` is still pending.

That is the next meaningful implementation phase, but it depends on confirming the cleanest plugin-to-shell request path for asking Clicky to resolve coordinates from the live screen context.

## Main Open Questions

1. Should the OpenClaw plugin be installed/provenanced cleanly instead of being
   loaded as unmanaged global code from `~/.openclaw/extensions/clicky-shell`?
2. Should the Mac app surface a clearer diagnostic when `clicky_present` is
   called but the final assistant message is not structured JSON?

## Verified Matrix

1. Answer-only
   - Example: general guidance, no screen grounding
   - Result: `clicky_present` with `mode=answer`, no points, final JSON returned

2. Single-point detailed explanation
   - Example: "what does this one button do?"
   - Result: `clicky_present` with `mode=point`, exactly one point, explanation present, final JSON returned

3. Narrated walkthrough
   - Example: steering wheel or gearbox walkthrough
   - Result: `clicky_present` with `mode=walkthrough`, multiple points, explanations on every point, final JSON returned

4. Ambiguous or low-confidence screen case
   - Example: blurry screenshot or vague target
   - Result: `clicky_present` with `mode=answer`, no points, final JSON returned

## If The Tool Path Fails Tomorrow

Check in this order:

1. Whether `clicky_present` appeared in the live plugin's advertised tools.
2. Whether the tool callback ran at all.
3. Whether the model emitted the exact final JSON object after the tool call.
4. Whether the model added prose around the final JSON.

If a future run regresses into an empty response, first check whether the model
emitted the final JSON after the `clicky_present` tool result.

## Next Implementation Phase

After the first live verification:

1. Clean up unmanaged plugin provenance.
2. Start `clicky_locate` or `clicky_locate_many`.
3. Use the existing element-location path as the grounding primitive, not a new coordinate system.

## Practical Pickup Point

Tomorrow, start here:

- review `plugins/openclaw-clicky-shell/index.ts`
- clean up the unmanaged global plugin provenance
- start `clicky_locate` or `clicky_locate_many`
