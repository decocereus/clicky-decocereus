import type { Context } from "hono"

import type { Env } from "../env"
import {
  bootstrapWebCompanionSession,
  endWebCompanionSession,
  getWebCompanionSessionSnapshot,
  recordWebCompanionEvent,
  sendWebCompanionMessage,
} from "./service"
import { transcribeWebCompanionAudio } from "./transcribe"

function getUserAgent(c: Context<{ Bindings: Env }>) {
  return c.req.header("user-agent") ?? null
}

export async function handleCreateWebCompanionSession(
  c: Context<{ Bindings: Env }>,
) {
  const body = (await c.req.json().catch(() => null)) as
    | {
        visitorId?: unknown
        path?: unknown
        currentSectionId?: unknown
        referrerSource?: unknown
        locale?: unknown
      }
    | null

  const result = await bootstrapWebCompanionSession(c.env, {
    visitorId: body?.visitorId,
    path: body?.path,
    currentSectionId: body?.currentSectionId,
    referrerSource: body?.referrerSource,
    locale: body?.locale,
    userAgent: getUserAgent(c),
  })

  return c.json(result)
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
  const result = await getWebCompanionSessionSnapshot(c.env, sessionId)

  if (!result) {
    return c.json(
      {
        error: "Unknown web companion session.",
      },
      404,
    )
  }

  return c.json(result)
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

  const result = await recordWebCompanionEvent(c.env, sessionId, {
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
    const body = (await c.req.json().catch(() => null)) as
      | {
          message?: unknown
          path?: unknown
          sectionId?: unknown
          visitedSectionIds?: unknown
          screenContext?: unknown
        }
      | null

    const result = await sendWebCompanionMessage(c.env, sessionId, {
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
  const result = await endWebCompanionSession(c.env, sessionId)

  if (!result) {
    return c.json(
      {
        error: "Unknown web companion session.",
      },
      404,
    )
  }

  return c.json(result)
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
