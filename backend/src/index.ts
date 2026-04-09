import { Hono } from "hono"
import { cors } from "hono/cors"

import { createAuth } from "./auth/config"
import { requireSession } from "./auth/session"
import { getLaunchEntitlementSnapshot } from "./entitlements/service"
import type { Env } from "./env"

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

app.get("/v1/entitlements/me", async (c) => {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const launchEntitlement = await getLaunchEntitlementSnapshot(
    c.env,
    sessionResult.session.user.id,
  )

  return c.json({
    userId: sessionResult.session.user.id,
    entitlement: launchEntitlement,
  })
})

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
