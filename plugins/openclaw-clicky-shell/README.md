# Clicky Shell OpenClaw Plugin

Native OpenClaw plugin scaffold for connecting OpenClaw to the Clicky desktop shell.

## What it does today

- defines the `clicky-shell` plugin id
- exposes Clicky-specific config schema and UI hints
- registers Clicky-namespaced Gateway methods
- registers a simple `/clicky` command
- registers a `clicky_status` tool
- registers a `clicky_present` tool as the preferred presentation-mode surface for Clicky turns
- accepts real shell registrations
- tracks shell heartbeat freshness in memory
- reports shell status and session binding state
- syncs per-turn Clicky prompt context through plugin-owned gateway methods
- appends prompt context for fresh, bound Clicky shells during prompt build without exposing it in raw user message payloads
- explicitly tells OpenClaw that desktop action tools are not available

## What it will do next

- deepen shell trust semantics beyond freshness and transport scope
- make registration state more durable than process-memory-only state
- tighten stale-shell recovery behavior
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

This is intentionally conservative. The prior desktop-action queue/polling path has been removed; the plugin currently owns shell registration, prompt context, status, and `clicky_present` only. The transport and identity contract is documented in:

- `docs/clicky-openclaw-integration-contract.md`
