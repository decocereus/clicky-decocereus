import type { Context } from "hono"

import type { Env } from "../env"
import {
  enforceRateLimit,
  isRateLimitExceededError,
} from "../rate-limit/service"
import {
  assertWebCompanionSessionAccess,
  bootstrapWebCompanionSession,
  endWebCompanionSession,
  getWebCompanionSessionSnapshot,
  isWebCompanionAccessError,
  recordWebCompanionEvent,
  sendWebCompanionMessage,
} from "./service"
import { transcribeWebCompanionAudio } from "./transcribe"

function getUserAgent(c: Context<{ Bindings: Env }>) {
  return c.req.header("user-agent") ?? null
}

function getSessionToken(c: Context<{ Bindings: Env }>) {
  return c.req.header("x-clicky-session-token") ?? null
}

function getClientIp(c: Context<{ Bindings: Env }>) {
  const forwardedIp =
    c.req.header("cf-connecting-ip") ??
    c.req.header("x-forwarded-for")?.split(",")[0]?.trim() ??
    null

  return forwardedIp || "unknown"
}

function buildRateLimitKey(c: Context<{ Bindings: Env }>, sessionId?: string) {
  const userAgent = getUserAgent(c)?.slice(0, 160) ?? "unknown"
  const ipAddress = getClientIp(c)

  return sessionId ? `${ipAddress}:${sessionId}` : `${ipAddress}:${userAgent}`
}

export async function handleCreateWebCompanionSession(
  c: Context<{ Bindings: Env }>,
) {
  try {
    await enforceRateLimit(c.env, {
      scope: "web_companion_sessions",
      key: buildRateLimitKey(c),
      limit: 20,
      windowMs: 10 * 60 * 1000,
    })

    const body = (await c.req.json().catch(() => null)) as
      | {
        visitorId?: unknown
        sessionId?: unknown
        sessionToken?: unknown
        path?: unknown
        currentSectionId?: unknown
        referrerSource?: unknown
        locale?: unknown
      }
    | null

    const result = await bootstrapWebCompanionSession(c.env, {
      visitorId: body?.visitorId,
      sessionId: body?.sessionId,
      sessionToken: body?.sessionToken,
      path: body?.path,
      currentSectionId: body?.currentSectionId,
      referrerSource: body?.referrerSource,
      locale: body?.locale,
      userAgent: getUserAgent(c),
    })

    return c.json(result)
  } catch (error) {
    if (isRateLimitExceededError(error)) {
      c.header("Retry-After", String(error.retryAfterSeconds))
      return c.json({ error: error.message }, 429)
    }

    throw error
  }
}

export async function handleGetWebCompanionSession(
  c: Context<{ Bindings: Env }>,
) {
  const sessionId = c.req.param("sessionId")
  if (!sessionId) {
    return c.json(
      {
        error: "Missing web companion session id.",
      },
      400,
    )
  }
  try {
    const result = await getWebCompanionSessionSnapshot(
      c.env,
      sessionId,
      getSessionToken(c),
    )

    if (!result) {
      return c.json(
        {
          error: "Unknown web companion session.",
        },
        404,
      )
    }

    return c.json(result)
  } catch (error) {
    if (isWebCompanionAccessError(error)) {
      return c.json({ error: error.message }, error.status as 401 | 403)
    }

    throw error
  }
}

export async function handleRecordWebCompanionEvent(
  c: Context<{ Bindings: Env }>,
) {
  const sessionId = c.req.param("sessionId")
  if (!sessionId) {
    return c.json(
      {
        error: "Missing web companion session id.",
      },
      400,
    )
  }
  const body = (await c.req.json().catch(() => null)) as
      | {
          type?: unknown
          path?: unknown
          sectionId?: unknown
          ctaId?: unknown
          visitedSectionIds?: unknown
          dwellMs?: unknown
          screenContext?: unknown
      }
    | null

  try {
    await enforceRateLimit(c.env, {
      scope: "web_companion_events",
      key: buildRateLimitKey(c, sessionId),
      limit: 120,
      windowMs: 5 * 60 * 1000,
    })

    const result = await recordWebCompanionEvent(c.env, sessionId, getSessionToken(c), {
      type: body?.type,
      path: body?.path,
      sectionId: body?.sectionId,
      ctaId: body?.ctaId,
      visitedSectionIds: body?.visitedSectionIds,
      dwellMs: body?.dwellMs,
      screenContext: body?.screenContext,
    })

    if (!result) {
      return c.json(
        {
          error: "Unknown web companion session.",
        },
        404,
      )
    }

    return c.json(result)
  } catch (error) {
    if (isRateLimitExceededError(error)) {
      c.header("Retry-After", String(error.retryAfterSeconds))
      return c.json({ error: error.message }, 429)
    }

    if (isWebCompanionAccessError(error)) {
      return c.json({ error: error.message }, error.status as 401 | 403)
    }

    throw error
  }
}

export async function handleSendWebCompanionMessage(
  c: Context<{ Bindings: Env }>,
) {
  try {
    const sessionId = c.req.param("sessionId")
    if (!sessionId) {
      return c.json(
        {
          error: "Missing web companion session id.",
        },
        400,
      )
    }

    await enforceRateLimit(c.env, {
      scope: "web_companion_messages",
      key: buildRateLimitKey(c, sessionId),
      limit: 20,
      windowMs: 10 * 60 * 1000,
    })

    const body = (await c.req.json().catch(() => null)) as
      | {
          message?: unknown
          path?: unknown
          sectionId?: unknown
          visitedSectionIds?: unknown
          screenContext?: unknown
        }
      | null

    const result = await sendWebCompanionMessage(c.env, sessionId, getSessionToken(c), {
      message: body?.message,
      path: body?.path,
      sectionId: body?.sectionId,
      visitedSectionIds: body?.visitedSectionIds,
      screenContext: body?.screenContext,
    })

    if (!result) {
      return c.json(
        {
          error: "Unknown web companion session.",
        },
        404,
      )
    }

    return c.json(result)
  } catch (error) {
    if (isRateLimitExceededError(error)) {
      c.header("Retry-After", String(error.retryAfterSeconds))
      return c.json({ error: error.message }, 429)
    }

    if (isWebCompanionAccessError(error)) {
      return c.json({ error: error.message }, error.status as 401 | 403)
    }

    return c.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "Failed to send companion message.",
      },
      400,
    )
  }
}

export async function handleEndWebCompanionSession(
  c: Context<{ Bindings: Env }>,
) {
  const sessionId = c.req.param("sessionId")
  if (!sessionId) {
    return c.json(
      {
        error: "Missing web companion session id.",
      },
      400,
    )
  }
  try {
    const result = await endWebCompanionSession(c.env, sessionId, getSessionToken(c))

    if (!result) {
      return c.json(
        {
          error: "Unknown web companion session.",
        },
        404,
      )
    }

    return c.json(result)
  } catch (error) {
    if (isWebCompanionAccessError(error)) {
      return c.json({ error: error.message }, error.status as 401 | 403)
    }

    throw error
  }
}

export async function handleTranscribeWebCompanionAudio(
  c: Context<{ Bindings: Env }>,
) {
  const sessionId = c.req.param("sessionId")
  if (!sessionId) {
    return c.json(
      {
        error: "Missing web companion session id.",
      },
      400,
    )
  }

  try {
    await enforceRateLimit(c.env, {
      scope: "web_companion_transcribe",
      key: buildRateLimitKey(c, sessionId),
      limit: 12,
      windowMs: 10 * 60 * 1000,
    })

    const authorizedSession = await assertWebCompanionSessionAccess(
      c.env,
      sessionId,
      getSessionToken(c),
    )
    if (!authorizedSession) {
      return c.json(
        {
          error: "Unknown web companion session.",
        },
        404,
      )
    }

    const formData = await c.req.formData()
    const audioFile = formData.get("audio") as
      | {
          arrayBuffer: () => Promise<ArrayBuffer>
          size?: number
          type?: string
        }
      | null

    if (!audioFile || typeof audioFile.arrayBuffer !== "function") {
      return c.json(
        {
          error: "Audio file is required.",
        },
        400,
      )
    }

    console.info("[web-companion] transcribe:start", {
      sessionId,
      sizeBytes: audioFile.size ?? null,
      type: audioFile.type ?? null,
    })

    const transcript = await transcribeWebCompanionAudio(
      c.env,
      await audioFile.arrayBuffer(),
    )

    console.info("[web-companion] transcribe:done", {
      sessionId,
      transcriptLength: transcript.length,
    })

    return c.json({
      transcript,
    })
  } catch (error) {
    if (isRateLimitExceededError(error)) {
      c.header("Retry-After", String(error.retryAfterSeconds))
      return c.json({ error: error.message }, 429)
    }

    if (isWebCompanionAccessError(error)) {
      return c.json({ error: error.message }, error.status as 401 | 403)
    }

    console.error("[web-companion] transcribe:error", error)
    return c.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "Audio transcription failed.",
      },
      500,
    )
  }
}
