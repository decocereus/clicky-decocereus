import { Hono } from "hono"
import { cors } from "hono/cors"

import { createAuth } from "./auth/config"
import { requireSession } from "./auth/session"
import {
  handleBillingCancelCallback,
  handleCreateCheckout,
  handleRestoreBilling,
  handleBillingSuccessCallback,
} from "./billing/routes"
import type { Env } from "./env"
import {
  handleGetEntitlements,
  handleRefreshEntitlements,
} from "./entitlements/routes"

const app = new Hono<{ Bindings: Env }>()

app.use(
  "/api/auth/*",
  cors({
    origin: (origin, c) => {
      const allowedOrigins = new Set(
        [
          c.env.BETTER_AUTH_URL,
          c.env.WEB_ORIGIN,
        ].filter((value): value is string => Boolean(value)),
      )

      return allowedOrigins.has(origin) ? origin : ""
    },
    allowHeaders: ["Content-Type", "Authorization"],
    allowMethods: ["GET", "POST", "OPTIONS"],
    exposeHeaders: ["Content-Length", "set-auth-token"],
    credentials: true,
    maxAge: 600,
  }),
)

app.get("/", (c) => {
  return c.json({
    name: c.env.APP_NAME,
    service: "clicky-backend",
    status: "ok",
  })
})

app.get("/health", (c) => {
  return c.json({
    status: "ok",
    service: "clicky-backend",
  })
})

app.on(["GET", "POST"], "/api/auth/*", (c) => {
  const auth = createAuth(c.env)
  return auth.handler(c.req.raw)
})

app.get("/v1", (c) => {
  return c.json({
    status: "ok",
    message: "Clicky backend scaffold is live.",
    routes: [
      "GET /health",
      "GET /v1",
      "GET|POST /api/auth/*",
      "GET /v1/me",
      "GET /v1/entitlements/me",
      "POST /v1/entitlements/refresh",
      "POST /v1/billing/checkout",
      "POST /v1/billing/restore",
      "GET /v1/billing/callback/success",
      "GET /v1/billing/callback/cancel",
      "GET /v1/auth/native/start",
      "POST /v1/auth/native/exchange",
    ],
  })
})

app.get("/v1/me", async (c) => {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  return c.json(sessionResult.session)
})

app.get("/v1/entitlements/me", handleGetEntitlements)
app.post("/v1/entitlements/refresh", handleRefreshEntitlements)
app.post("/v1/billing/checkout", handleCreateCheckout)
app.post("/v1/billing/restore", handleRestoreBilling)
app.get("/v1/billing/callback/success", handleBillingSuccessCallback)
app.get("/v1/billing/callback/cancel", handleBillingCancelCallback)

app.get("/v1/auth/native/start", (c) => {
  return c.json(
    {
      error: "Native auth browser start is not implemented yet.",
      nextStep: "Implement browser handoff + one-time exchange flow.",
    },
    501,
  )
})

app.post("/v1/auth/native/exchange", (c) => {
  return c.json(
    {
      error: "Native auth code exchange is not implemented yet.",
      nextStep: "Implement one-time code exchange for bearer session issuance.",
    },
    501,
  )
})

export default app
