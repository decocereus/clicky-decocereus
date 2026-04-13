# Clicky Shell OpenClaw Plugin

Native OpenClaw plugin scaffold for connecting OpenClaw to the Clicky desktop shell.

## What it does today

- defines the `clicky-shell` plugin id
- exposes Clicky-specific config schema and UI hints
- registers Clicky-namespaced Gateway methods
- registers a simple `/clicky` command
- registers a `clicky_status` tool
- registers a `clicky_present` tool as the preferred final presentation surface for Clicky turns
- accepts real shell registrations
- tracks shell heartbeat freshness in memory
- reports shell status and session binding state
- syncs per-turn Clicky prompt context through plugin-owned gateway methods
- appends prompt context for fresh, bound Clicky shells during prompt build without exposing it in raw user message payloads
- prefers tool-driven Clicky presentation first, while keeping the raw structured JSON reply path as fallback

## What it will do next

- deepen shell trust semantics beyond freshness and transport scope
- make registration state more durable than process-memory-only state
- tighten stale-shell recovery behavior
- add locator-style tools so OpenClaw can ask Clicky for grounded coordinates instead of inferring them unaided
- continue maturing the installable bridge for local and remote OpenClaw

## Local install

```bash
openclaw plugins install ./plugins/openclaw-clicky-shell
openclaw plugins enable clicky-shell
openclaw gateway restart
```

## Files

- `package.json`
- `openclaw.plugin.json`
- `index.ts`

## Notes

This is still intentionally conservative. It is no longer a placeholder-only scaffold, but it is also not yet the final trust layer. The transport and identity contract is documented in:

- `docs/clicky-openclaw-integration-contract.md`
