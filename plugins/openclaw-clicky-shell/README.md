# Clicky Shell OpenClaw Plugin

Native OpenClaw plugin scaffold for connecting OpenClaw to the Clicky desktop shell.

## What it does today

- defines the `clicky-shell` plugin id
- exposes Clicky-specific config schema and UI hints
- registers Clicky-namespaced Gateway methods
- registers a simple `/clicky` command
- registers a `clicky_status` tool
- registers a `clicky_present` tool as the preferred presentation-mode surface for Clicky turns
- registers runtime-shaped computer-use tools: `list_apps`, `list_windows`, `get_window_state`, `click`, `type_text`, `press_key`, `scroll`, `set_value`, `perform_secondary_action`, `drag`, `resize`, and `set_window_frame`
- queues computer-use tool calls for the connected Clicky shell, waits for Clicky to execute them through `BackgroundComputerUse`, and returns compact runtime JSON directly to the model
- accepts real shell registrations
- tracks shell heartbeat freshness in memory
- reports shell status and session binding state
- syncs per-turn Clicky prompt context through plugin-owned gateway methods
- appends prompt context for fresh, bound Clicky shells during prompt build without exposing it in raw user message payloads
- teaches an observe-act-observe loop where the model owns window choice, element choice, sequencing, and recovery
- keeps desktop control on the Clicky runtime path; generic `exec`, AppleScript, process, or browser automation is not part of the Clicky desktop-control contract
- treats `clicky_present` as final presentation only; completion claims after runtime mutations require a fresh post-action `get_window_state`

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

This is still intentionally conservative. It is no longer a placeholder-only scaffold, but it is also not yet the final trust layer. The transport and identity contract is documented in:

- `docs/clicky-openclaw-integration-contract.md`
