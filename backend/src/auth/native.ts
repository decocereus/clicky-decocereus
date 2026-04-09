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
