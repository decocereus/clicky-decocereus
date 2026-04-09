# Clicky Backend

TypeScript backend for launch auth, billing, and entitlements.

This service is separate from `worker/`:

- `worker/` proxies AI providers and keeps model API keys out of the app
- `backend/` owns auth, checkout, entitlements, restore, and billing webhooks

## Commands

```bash
npm install
npm run dev
npm run typecheck
```

## Environment

Set these as Wrangler secrets or vars before real auth/billing work lands:

- `BETTER_AUTH_SECRET`
- `BETTER_AUTH_URL`
- `DATABASE_URL`
- `WEB_ORIGIN`
- `MAC_APP_SCHEME`
- `POLAR_ACCESS_TOKEN`
- `POLAR_WEBHOOK_SECRET`

The current scaffold exposes:

- health routes
- Better Auth handler routes at `/api/auth/*`
- session inspection at `/v1/me`
- placeholder native auth contract routes under `/v1/auth/native/*`
