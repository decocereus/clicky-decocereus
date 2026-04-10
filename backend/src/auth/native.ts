import { eq } from "drizzle-orm"

import { createDb } from "../db/client"
import { nativeAuthHandoffs } from "../db/schema"
import type { Env } from "../env"

const NATIVE_AUTH_HANDOFF_TTL_MINUTES = 15

function addMinutes(date: Date, minutes: number) {
  const nextDate = new Date(date)
  nextDate.setUTCMinutes(nextDate.getUTCMinutes() + minutes)
  return nextDate
}

function requireWebOrigin(env: Env) {
  if (!env.WEB_ORIGIN) {
    throw new Error("WEB_ORIGIN is required for native auth handoff.")
  }

  return env.WEB_ORIGIN
}

function requireApiBaseUrl(env: Env) {
  if (!env.BETTER_AUTH_URL) {
    throw new Error("BETTER_AUTH_URL is required for native auth handoff.")
  }

  return env.BETTER_AUTH_URL
}

export async function createNativeAuthHandoff(env: Env) {
  const db = createDb(env)
  const state = crypto.randomUUID()
  const requestedAt = new Date()
  const expiresAt = addMinutes(requestedAt, NATIVE_AUTH_HANDOFF_TTL_MINUTES)
  const returnScheme = env.MAC_APP_SCHEME ?? "clicky"
  const apiBaseUrl = requireApiBaseUrl(env)
  const webOrigin = requireWebOrigin(env)
  const callbackUrl = `${apiBaseUrl}/v1/auth/native/callback?state=${encodeURIComponent(state)}`
  const browserUrl =
    `${webOrigin}/auth/native?state=${encodeURIComponent(state)}` +
    `&callbackUrl=${encodeURIComponent(callbackUrl)}`

  await db.insert(nativeAuthHandoffs).values({
    state,
    returnScheme,
    browserUrl,
    callbackUrl,
    requestedAt,
    expiresAt,
  })

  return {
    state,
    browserUrl,
    callbackUrl,
    expiresAt: expiresAt.toISOString(),
    returnScheme,
  }
}

export async function getNativeAuthHandoff(env: Env, state: string) {
  const db = createDb(env)

  return db.query.nativeAuthHandoffs.findFirst({
    where: eq(nativeAuthHandoffs.state, state),
  })
}

export async function completeNativeAuthHandoff(
  env: Env,
  state: string,
  sessionToken: string,
  userId: string,
) {
  const db = createDb(env)
  const handoff = await getNativeAuthHandoff(env, state)

  if (!handoff) {
    return {
      ok: false as const,
      error: "Unknown native auth handoff state.",
      status: 404,
    }
  }

  if (handoff.expiresAt <= new Date()) {
    await db
      .update(nativeAuthHandoffs)
      .set({
        status: "expired",
      })
      .where(eq(nativeAuthHandoffs.id, handoff.id))

    return {
      ok: false as const,
      error: "Native auth handoff expired.",
      status: 410,
    }
  }

  const code = crypto.randomUUID()
  const authenticatedAt = new Date()

  await db
    .update(nativeAuthHandoffs)
    .set({
      code,
      sessionToken,
      userId,
      authenticatedAt,
      status: "authenticated",
    })
    .where(eq(nativeAuthHandoffs.id, handoff.id))

  return {
    ok: true as const,
    handoff: {
      ...handoff,
      code,
      sessionToken,
      userId,
      authenticatedAt,
      status: "authenticated" as const,
    },
  }
}

export async function exchangeNativeAuthCode(env: Env, code: string) {
  const db = createDb(env)
  const handoff = await db.query.nativeAuthHandoffs.findFirst({
    where: eq(nativeAuthHandoffs.code, code),
  })

  if (!handoff) {
    return {
      ok: false as const,
      error: "Unknown native auth exchange code.",
      status: 404,
    }
  }

  if (handoff.expiresAt <= new Date()) {
    await db
      .update(nativeAuthHandoffs)
      .set({
        status: "expired",
      })
      .where(eq(nativeAuthHandoffs.id, handoff.id))

    return {
      ok: false as const,
      error: "Native auth exchange code expired.",
      status: 410,
    }
  }

  if (handoff.status === "exchanged") {
    return {
      ok: false as const,
      error: "Native auth exchange code already used.",
      status: 409,
    }
  }

  if (handoff.status !== "authenticated" || !handoff.sessionToken || !handoff.userId) {
    return {
      ok: false as const,
      error: "Native auth handoff is not ready for exchange.",
      status: 409,
    }
  }

  const exchangedAt = new Date()

  await db
    .update(nativeAuthHandoffs)
    .set({
      status: "exchanged",
      exchangedAt,
      code: null,
    })
    .where(eq(nativeAuthHandoffs.id, handoff.id))

  return {
    ok: true as const,
    handoff: {
      ...handoff,
      exchangedAt,
      status: "exchanged" as const,
    },
  }
}
