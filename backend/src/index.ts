import { Hono } from "hono"
import { cors } from "hono/cors"

import { createAuth } from "./auth/config"
import { createNativeAuthHandoff, getNativeAuthHandoff } from "./auth/native"
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
      "GET /v1/auth/native/callback",
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

app.get("/v1/auth/native/start", async (c) => {
  try {
    const handoff = await createNativeAuthHandoff(c.env)

    if (c.req.query("mode") === "json") {
      return c.json(handoff)
    }

    return c.redirect(handoff.browserUrl, 302)
  } catch (error) {
    return c.json(
      {
        error: error instanceof Error ? error.message : "Native auth handoff failed.",
      },
      500,
    )
  }
})

app.get("/v1/auth/native/callback", async (c) => {
  const state = c.req.query("state")

  if (!state) {
    return c.json(
      {
        error: "Missing native auth handoff state.",
      },
      400,
    )
  }

  const handoff = await getNativeAuthHandoff(c.env, state)

  if (!handoff) {
    return c.json(
      {
        error: "Unknown native auth handoff state.",
      },
      404,
    )
  }

  return c.json(
    {
      error: "Native auth callback completion is not implemented yet.",
      handoff: {
        state: handoff.state,
        status: handoff.status,
        callbackUrl: handoff.callbackUrl,
        browserUrl: handoff.browserUrl,
      },
      nextStep: "Complete web sign-in handoff and issue one-time exchange codes.",
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
