import { and, eq, lt, sql } from "drizzle-orm"

import { createDb } from "../db/client"
import { rateLimitWindows, type rateLimitScopeEnum } from "../db/schema"
import type { Env } from "../env"

type RateLimitScope = (typeof rateLimitScopeEnum.enumValues)[number]

export class RateLimitExceededError extends Error {
  retryAfterSeconds: number

  constructor(message: string, retryAfterSeconds: number) {
    super(message)
    this.name = "RateLimitExceededError"
    this.retryAfterSeconds = retryAfterSeconds
  }
}

export function isRateLimitExceededError(error: unknown): error is RateLimitExceededError {
  return error instanceof RateLimitExceededError
}

function floorWindowStart(now: Date, windowMs: number) {
  const startedAt = Math.floor(now.getTime() / windowMs) * windowMs
  return new Date(startedAt)
}

function buildRateLimitMessage(scope: RateLimitScope) {
  switch (scope) {
    case "web_companion_transcribe":
      return "Too many voice transcription requests. Please wait a moment and try again."
    case "web_companion_messages":
      return "Too many Clicky messages in a short time. Please wait a moment and try again."
    case "web_companion_events":
      return "Too many Clicky companion events in a short time. Please wait a moment and try again."
    case "web_companion_sessions":
    default:
      return "Too many Clicky session requests. Please wait a moment and try again."
  }
}

export async function enforceRateLimit(
  env: Env,
  input: {
    scope: RateLimitScope
    key: string
    limit: number
    windowMs: number
  },
) {
  const db = createDb(env)
  const now = new Date()
  const windowStart = floorWindowStart(now, input.windowMs)
  const retryAfterSeconds = Math.max(
    1,
    Math.ceil((windowStart.getTime() + input.windowMs - now.getTime()) / 1000),
  )
  const staleCutoff = new Date(now.getTime() - input.windowMs * 4)

  await db
    .delete(rateLimitWindows)
    .where(
      and(
        eq(rateLimitWindows.scope, input.scope),
        lt(rateLimitWindows.updatedAt, staleCutoff),
      ),
    )

  const [windowRow] = await db
    .insert(rateLimitWindows)
    .values({
      scope: input.scope,
      key: input.key,
      windowStart,
      count: 1,
      updatedAt: now,
    })
    .onConflictDoUpdate({
      target: [
        rateLimitWindows.scope,
        rateLimitWindows.key,
        rateLimitWindows.windowStart,
      ],
      set: {
        count: sql`${rateLimitWindows.count} + 1`,
        updatedAt: now,
      },
    })
    .returning({
      count: rateLimitWindows.count,
    })

  if ((windowRow?.count ?? 0) > input.limit) {
    throw new RateLimitExceededError(
      buildRateLimitMessage(input.scope),
      retryAfterSeconds,
    )
  }
}
