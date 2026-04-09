# Clicky Shell OpenClaw Plugin

Native OpenClaw plugin scaffold for connecting OpenClaw to the Clicky desktop shell.

## What it does today

- defines the `clicky-shell` plugin id
- exposes Clicky-specific config schema and UI hints
- registers Clicky-namespaced Gateway methods
- registers a simple `/clicky` command
- registers a `clicky_status` tool

## What it will do next

- accept real Clicky shell registrations from the desktop app
- keep shell heartbeat state fresh
- expose shell capability status to OpenClaw sessions
- become the installable bridge that makes local and remote OpenClaw work cleanly with Clicky

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

This is intentionally a conservative first scaffold. The transport and identity contract is documented in:

- `docs/clicky-openclaw-integration-contract.md`
