import { Hono } from "hono"
import { cors } from "hono/cors"

import { createAuth } from "./auth/config"
import {
  completeNativeAuthHandoff,
  createNativeAuthHandoff,
  exchangeNativeAuthCode,
  getNativeAuthHandoff,
} from "./auth/native"
import { requireSession } from "./auth/session"
import {
  handleBillingCancelCallback,
  handleCreateCheckout,
  handleRestoreBilling,
  handleBillingSuccessCallback,
  handlePolarWebhook,
} from "./billing/routes"
import type { Env } from "./env"
import {
  handleGetEntitlements,
  handleRefreshEntitlements,
} from "./entitlements/routes"
import { getLaunchEntitlementSnapshot } from "./entitlements/service"
import {
  handleActivateTrial,
  handleConsumeTrialCredit,
  handleGetTrial,
  handleMarkTrialPaywalled,
} from "./trial/routes"

const app = new Hono<{ Bindings: Env }>()

const corsOptions = {
  origin: (origin: string, c: { env: Env }) => {
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
}

app.use(
  "/api/auth/*",
  cors(corsOptions),
)

app.use("/v1/*", cors(corsOptions))

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
      "GET /v1/trial/me",
      "POST /v1/trial/activate",
      "POST /v1/trial/consume",
      "POST /v1/trial/paywall-activate",
      "POST /v1/billing/checkout",
      "POST /v1/billing/restore",
      "POST /v1/webhooks/polar",
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
app.get("/v1/trial/me", handleGetTrial)
app.post("/v1/trial/activate", handleActivateTrial)
app.post("/v1/trial/consume", handleConsumeTrialCredit)
app.post("/v1/trial/paywall-activate", handleMarkTrialPaywalled)
app.post("/v1/billing/checkout", handleCreateCheckout)
app.post("/v1/billing/restore", handleRestoreBilling)
app.post("/v1/webhooks/polar", handlePolarWebhook)
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

  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return c.json(
      {
        error: "Browser auth session is required before completing native handoff.",
        handoff: {
          state: handoff.state,
          status: handoff.status,
          callbackUrl: handoff.callbackUrl,
          browserUrl: handoff.browserUrl,
        },
      },
      401,
    )
  }

  const rawSessionToken = sessionResult.session.session.token
  const completedHandoff = await completeNativeAuthHandoff(
    c.env,
    state,
    rawSessionToken,
    sessionResult.session.user.id,
  )

  if (!completedHandoff.ok) {
    return c.json(
      {
        error: completedHandoff.error,
      },
      { status: completedHandoff.status as 404 | 410 },
    )
  }

  const nativeCallbackUrl = new URL(`${completedHandoff.handoff.returnScheme}://auth/callback`)
  nativeCallbackUrl.searchParams.set("code", completedHandoff.handoff.code)
  nativeCallbackUrl.searchParams.set("state", completedHandoff.handoff.state)

  if (c.req.query("mode") === "json") {
    return c.json({
      state: completedHandoff.handoff.state,
      code: completedHandoff.handoff.code,
      callbackUrl: nativeCallbackUrl.toString(),
      userId: completedHandoff.handoff.userId,
    })
  }

  return c.redirect(nativeCallbackUrl.toString(), 302)
})

app.post("/v1/auth/native/exchange", async (c) => {
  const body = await c.req.json().catch(() => null) as { code?: string } | null
  const code = body?.code?.trim()

  if (!code) {
    return c.json(
      {
        error: "Native auth exchange code is required.",
      },
      400,
    )
  }

  const exchangeResult = await exchangeNativeAuthCode(c.env, code)

  if (!exchangeResult.ok) {
    return c.json(
      {
        error: exchangeResult.error,
      },
      { status: exchangeResult.status as 404 | 409 | 410 },
    )
  }

  const launchEntitlement = await getLaunchEntitlementSnapshot(
    c.env,
    exchangeResult.handoff.userId!,
  )

  return c.json({
    tokenType: "Bearer",
    sessionToken: exchangeResult.handoff.sessionToken,
    userId: exchangeResult.handoff.userId,
    entitlement: launchEntitlement,
  })
})

export default app
