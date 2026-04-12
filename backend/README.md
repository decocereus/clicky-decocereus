# Clicky Backend

TypeScript backend for launch auth, billing, and entitlements.

This service is separate from `worker/`:

- `worker/` proxies AI providers and keeps model API keys out of the app
- `backend/` owns auth, checkout, entitlements, restore, billing webhooks, and authenticated proxy routes for services the Mac app should not call directly

## Commands

```bash
npm install
npm run dev
npm run auth:generate
npm run db:generate
npm run typecheck
```

By default the backend dev server runs on `http://localhost:8788` so it does not collide with the existing AI proxy worker.

## Environment

Set these as Wrangler secrets or vars before real auth/billing work lands:

- `BETTER_AUTH_SECRET`
- `BETTER_AUTH_URL`
- `DATABASE_URL`
- `WEB_ORIGIN`
- `MAC_APP_SCHEME`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `ELEVENLABS_API_KEY`
- `ELEVENLABS_MODEL_ID`
- `ELEVENLABS_VOICE_ID`
- `POLAR_ACCESS_TOKEN`
- `POLAR_WEBHOOK_SECRET`
- `OPENCLAW_GATEWAY_URL`
- `OPENCLAW_GATEWAY_AUTH_TOKEN`
- `OPENCLAW_AGENT_ID`
- `OPENCLAW_CLICKY_WEB_SHELL_ENABLED`
- `OPENCLAW_CLICKY_WEB_PRESENTATION_NAME`
- `CONTENT_INGESTION_BASE_URL`
- `CONTENT_INGESTION_API_KEY`

For local development you can start from `.dev.vars.example`:

```bash
cp .dev.vars.example .dev.vars
```

The current scaffold exposes:

- health routes
- Better Auth handler routes at `/api/auth/*`
- session inspection at `/v1/me`
- placeholder native auth contract routes under `/v1/auth/native/*`
- web companion session bootstrap, events, and messages under `/v1/web-companion/*`
- authenticated tutorial extraction proxy routes under `/v1/tutorials/*`

For the web companion runtime:

- prefer `OPENCLAW_GATEWAY_URL` + `OPENCLAW_GATEWAY_AUTH_TOKEN` + `OPENCLAW_AGENT_ID`
  when you want the backend to speak the native OpenClaw Gateway WebSocket protocol
- set `ELEVENLABS_API_KEY` + `ELEVENLABS_VOICE_ID` when you want the backend to
  synthesize website companion audio directly through ElevenLabs

## Schema generation

- `npm run auth:generate` generates the Better Auth-required Drizzle schema using `src/auth.ts`
- `npm run db:generate` generates app-owned Drizzle SQL migrations from `src/db/schema.ts`
