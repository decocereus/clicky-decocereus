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
import { readEnvValue, type Env } from "./env"
import {
  handleGetEntitlements,
  handleRefreshEntitlements,
} from "./entitlements/routes"
import { getLaunchEntitlementSnapshot } from "./entitlements/service"
import {
  handleCreateWebCompanionSession,
  handleEndWebCompanionSession,
  handleGetWebCompanionSession,
  handleRecordWebCompanionEvent,
  handleSendWebCompanionMessage,
  handleTranscribeWebCompanionAudio,
} from "./web-companion/routes"
import {
  handleActivateTrial,
  handleConsumeTrialCredit,
  handleGetTrial,
  handleMarkTrialPaywalled,
  handleMarkTrialWelcomeDelivered,
} from "./trial/routes"

const app = new Hono<{ Bindings: Env }>()

function expandLocalhostOrigin(origin: string | undefined) {
  if (!origin) {
    return []
  }

  const trimmedOrigin = origin.trim()
  if (!trimmedOrigin) {
    return []
  }

  const origins = new Set([trimmedOrigin])

  try {
    const url = new URL(trimmedOrigin)
    const isLoopbackHost =
      url.hostname === "localhost" || url.hostname === "127.0.0.1"

    if (isLoopbackHost) {
      const alternateUrl = new URL(url.toString())
      alternateUrl.hostname = url.hostname === "localhost" ? "127.0.0.1" : "localhost"
      origins.add(alternateUrl.origin)
    }
  } catch {
    // Ignore invalid URLs and just keep the original value.
  }

  return [...origins]
}

const corsOptions = {
  origin: (origin: string, c: { env: Env }) => {
    const allowedOrigins = new Set(
      [
        ...expandLocalhostOrigin(readEnvValue(c.env, "BETTER_AUTH_URL")),
        ...expandLocalhostOrigin(readEnvValue(c.env, "WEB_ORIGIN")),
      ],
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

app.onError((error, c) => {
  console.error("[clicky-backend]", error)

  return c.json(
    {
      error: error instanceof Error ? error.message : "Internal Server Error",
    },
    500,
  )
})

app.get("/", (c) => {
  return c.json({
    name: readEnvValue(c.env, "APP_NAME") ?? "Clicky Backend",
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
      "POST /v1/trial/welcome-delivered",
      "POST /v1/billing/checkout",
      "POST /v1/billing/restore",
      "POST /v1/webhooks/polar",
      "GET /v1/billing/callback/success",
      "GET /v1/billing/callback/cancel",
      "POST /v1/web-companion/sessions",
      "GET /v1/web-companion/sessions/:sessionId",
      "POST /v1/web-companion/sessions/:sessionId/events",
      "POST /v1/web-companion/sessions/:sessionId/messages",
      "POST /v1/web-companion/sessions/:sessionId/transcribe",
      "POST /v1/web-companion/sessions/:sessionId/end",
      "GET /v1/auth/native/start",
      "GET /v1/auth/native/google/start",
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
app.post("/v1/trial/welcome-delivered", handleMarkTrialWelcomeDelivered)
app.post("/v1/billing/checkout", handleCreateCheckout)
app.post("/v1/billing/restore", handleRestoreBilling)
app.post("/v1/webhooks/polar", handlePolarWebhook)
app.get("/v1/billing/callback/success", handleBillingSuccessCallback)
app.get("/v1/billing/callback/cancel", handleBillingCancelCallback)
app.post("/v1/web-companion/sessions", handleCreateWebCompanionSession)
app.get("/v1/web-companion/sessions/:sessionId", handleGetWebCompanionSession)
app.post("/v1/web-companion/sessions/:sessionId/events", handleRecordWebCompanionEvent)
app.post("/v1/web-companion/sessions/:sessionId/messages", handleSendWebCompanionMessage)
app.post("/v1/web-companion/sessions/:sessionId/transcribe", handleTranscribeWebCompanionAudio)
app.post("/v1/web-companion/sessions/:sessionId/end", handleEndWebCompanionSession)

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

app.get("/v1/auth/native/google/start", async (c) => {
  const callbackUrl = c.req.query("callbackUrl")?.trim()

  if (!callbackUrl) {
    return c.json(
      {
        error: "Native auth callback URL is required.",
      },
      400,
    )
  }

  const auth = createAuth(c.env)
  const signInRequestUrl = new URL("/api/auth/sign-in/social", c.req.url)
  const webOrigin = readEnvValue(c.env, "WEB_ORIGIN")?.trim() || new URL(c.req.url).origin
  const headers = new Headers({
    "content-type": "application/json",
    origin: webOrigin,
    referer: `${webOrigin}/auth/native`,
  })
  const cookieHeader = c.req.header("cookie")
  const userAgent = c.req.header("user-agent")
  const xForwardedFor = c.req.header("x-forwarded-for")
  const xForwardedProto = c.req.header("x-forwarded-proto")
  const xForwardedHost = c.req.header("x-forwarded-host")

  if (cookieHeader) {
    headers.set("cookie", cookieHeader)
  }

  if (userAgent) {
    headers.set("user-agent", userAgent)
  }

  if (xForwardedFor) {
    headers.set("x-forwarded-for", xForwardedFor)
  }

  if (xForwardedProto) {
    headers.set("x-forwarded-proto", xForwardedProto)
  }

  if (xForwardedHost) {
    headers.set("x-forwarded-host", xForwardedHost)
  }

  const authResponse = await auth.handler(
    new Request(signInRequestUrl, {
      method: "POST",
      headers,
      body: JSON.stringify({
        provider: "google",
        disableRedirect: true,
        callbackURL: callbackUrl,
      }),
    }),
  )

  if (!authResponse.ok) {
    return authResponse
  }

  const payload = await authResponse.json().catch(() => null) as { url?: string } | null
  const redirectUrl = payload?.url?.trim()

  if (!redirectUrl) {
    return c.json(
      {
        error: "Google sign-in URL was missing from Better Auth.",
      },
      500,
    )
  }

  const redirectHeaders = new Headers({
    Location: redirectUrl,
  })

  for (const [headerName, headerValue] of authResponse.headers.entries()) {
    if (headerName.toLowerCase() === "set-cookie") {
      redirectHeaders.append(headerName, headerValue)
    }
  }

  return new Response(null, {
    status: 302,
    headers: redirectHeaders,
  })
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
