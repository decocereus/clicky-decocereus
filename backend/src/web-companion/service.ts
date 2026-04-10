import { and, desc, eq, gt } from "drizzle-orm"

import { createDb } from "../db/client"
import {
  webCompanionEvents,
  webCompanionSessions,
  webCompanionTurns,
  webVisitors,
} from "../db/schema"
import type { Env } from "../env"
import { isKnownWebCompanionSection } from "./sections"
import { generateWebCompanionReply } from "./openclaw"
import type {
  WebCompanionGenerationInput,
  WebCompanionImageAttachment,
  WebCompanionResponse,
  WebCompanionScreenContext,
  WebCompanionSessionMetadata,
} from "./types"

const ACTIVE_SESSION_WINDOW_MS = 30 * 60 * 1000
const PROACTIVE_MUTE_WINDOW_MS = 2 * 60 * 1000
const MAX_RECENT_TURNS = 10
const MAX_PROACTIVE_NUDGES_PER_SESSION = 3
const MAX_MESSAGE_LENGTH = 800
const MAX_SCREEN_ATTACHMENTS = 2
const MAX_SCREEN_ATTACHMENT_BASE64_LENGTH = 3_000_000

type WebCompanionSessionRow = typeof webCompanionSessions.$inferSelect
type WebCompanionTurnRow = typeof webCompanionTurns.$inferSelect

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null
}

function normalizeVisitorId(visitorId: unknown) {
  if (typeof visitorId !== "string") {
    return `visitor_${crypto.randomUUID()}`
  }

  const trimmed = visitorId.trim()
  if (!trimmed) {
    return `visitor_${crypto.randomUUID()}`
  }

  return trimmed.slice(0, 128)
}

function normalizePath(path: unknown) {
  if (typeof path !== "string") {
    return "/"
  }

  const trimmed = path.trim()
  return trimmed || "/"
}

function normalizeStringArray(value: unknown) {
  if (!Array.isArray(value)) {
    return []
  }

  return value
    .map((entry) => (typeof entry === "string" ? entry.trim() : ""))
    .filter(Boolean)
}

function normalizeScreenAttachment(raw: unknown): WebCompanionImageAttachment | null {
  if (!isRecord(raw)) {
    return null
  }

  const contentBase64 =
    typeof raw.contentBase64 === "string" ? raw.contentBase64.trim() : ""
  if (!contentBase64 || contentBase64.length > MAX_SCREEN_ATTACHMENT_BASE64_LENGTH) {
    return null
  }

  const label =
    typeof raw.label === "string" && raw.label.trim()
      ? raw.label.trim().slice(0, 160)
      : "Shared screen capture"
  const mimeType =
    typeof raw.mimeType === "string" && raw.mimeType.trim()
      ? raw.mimeType.trim().slice(0, 64)
      : "image/jpeg"

  if (!/^image\/(jpeg|jpg|png|webp)$/i.test(mimeType)) {
    return null
  }

  return {
    contentBase64,
    label,
    mimeType,
  }
}

function normalizeScreenContext(raw: unknown): WebCompanionScreenContext | null {
  if (!isRecord(raw)) {
    return null
  }

  const source =
    typeof raw.source === "string" &&
    (raw.source.trim() === "display-media" ||
      raw.source.trim() === "site-layout-reference")
      ? (raw.source.trim() as "display-media" | "site-layout-reference")
      : null
  if (!source) {
    return null
  }

  const attachments = Array.isArray(raw.attachments)
    ? raw.attachments
        .map(normalizeScreenAttachment)
        .filter((attachment): attachment is WebCompanionImageAttachment => Boolean(attachment))
        .slice(0, MAX_SCREEN_ATTACHMENTS)
    : []

  if (!attachments.length) {
    return null
  }

  return {
    attachments,
    source,
  }
}

function normalizeSessionMetadata(raw: unknown): WebCompanionSessionMetadata {
  if (!isRecord(raw)) {
    return {
      visitedSectionIds: [],
      nudgedSectionIds: [],
      mutedUntil: null,
    }
  }

  return {
    visitedSectionIds: normalizeStringArray(raw.visitedSectionIds).filter((sectionId) =>
      isKnownWebCompanionSection(sectionId),
    ),
    nudgedSectionIds: normalizeStringArray(raw.nudgedSectionIds).filter((sectionId) =>
      isKnownWebCompanionSection(sectionId),
    ),
    mutedUntil:
      typeof raw.mutedUntil === "string" && raw.mutedUntil.trim()
        ? raw.mutedUntil
        : null,
  }
}

function mergeVisitedSectionIds(
  metadata: WebCompanionSessionMetadata,
  incomingVisitedSectionIds: string[],
  currentSectionId: string | null,
) {
  const merged = new Set(metadata.visitedSectionIds)

  for (const sectionId of incomingVisitedSectionIds) {
    if (isKnownWebCompanionSection(sectionId)) {
      merged.add(sectionId)
    }
  }

  if (currentSectionId && isKnownWebCompanionSection(currentSectionId)) {
    merged.add(currentSectionId)
  }

  return Array.from(merged)
}

function serializeJsonDate(value: Date | null | undefined) {
  return value ? value.toISOString() : null
}

function serializeSession(
  session: WebCompanionSessionRow,
  visitorAnonymousId: string,
) {
  const metadata = normalizeSessionMetadata(session.metadata)

  return {
    id: session.id,
    visitorId: visitorAnonymousId,
    path: session.path,
    entrySectionId: session.entrySectionId,
    currentSectionId: session.currentSectionId,
    openClawThreadId: session.openclawThreadId,
    status: session.status,
    startedAt: session.startedAt.toISOString(),
    lastActiveAt: session.lastActiveAt.toISOString(),
    endedAt: serializeJsonDate(session.endedAt),
    visitedSectionIds: metadata.visitedSectionIds,
  }
}

function serializeTurn(turn: WebCompanionTurnRow) {
  return {
    id: turn.id,
    role: turn.role,
    text: turn.text,
    actions: Array.isArray(turn.actions) ? turn.actions : [],
    createdAt: turn.createdAt.toISOString(),
  }
}

async function listRecentTurns(env: Env, sessionId: string) {
  const db = createDb(env)
  const turns = await db
    .select()
    .from(webCompanionTurns)
    .where(eq(webCompanionTurns.sessionId, sessionId))
    .orderBy(desc(webCompanionTurns.createdAt))
    .limit(MAX_RECENT_TURNS)

  return turns.reverse()
}

async function getSessionBundle(env: Env, sessionId: string) {
  const db = createDb(env)
  const [session] = await db
    .select()
    .from(webCompanionSessions)
    .where(eq(webCompanionSessions.id, sessionId))
    .limit(1)

  if (!session) {
    return null
  }

  const [visitor] = await db
    .select()
    .from(webVisitors)
    .where(eq(webVisitors.id, session.visitorId))
    .limit(1)

  if (!visitor) {
    return null
  }

  return {
    session,
    visitor,
  }
}

async function storeAssistantTurn(
  env: Env,
  sessionId: string,
  response: WebCompanionResponse,
  currentSectionId: string | null,
  triggerType: "event" | "message" | "bootstrap" | "fallback",
) {
  const db = createDb(env)

  await db.insert(webCompanionTurns).values({
    sessionId,
    role: "assistant",
    triggerType,
    currentSectionId,
    text: response.text,
    actions: response.actions,
    metadata: {
      provider: response.provider,
      mode: response.mode,
      suggestedReplies: response.suggestedReplies,
      sectionId: currentSectionId,
    },
  })
}

function buildGenerationInput(
  session: WebCompanionSessionRow,
  visitorAnonymousId: string,
  metadata: WebCompanionSessionMetadata,
  history: Awaited<ReturnType<typeof listRecentTurns>>,
  trigger: WebCompanionGenerationInput["trigger"],
  screenContext: WebCompanionScreenContext | null,
): WebCompanionGenerationInput {
  return {
    visitorId: visitorAnonymousId,
    sessionId: session.id,
    openClawThreadId: session.openclawThreadId,
    path: session.path,
    currentSectionId: session.currentSectionId,
    visitedSectionIds: metadata.visitedSectionIds,
    screenContext,
    history: history
      .filter((turn) => turn.role === "user" || turn.role === "assistant")
      .map((turn) => ({
        role: turn.role as "user" | "assistant",
        text: turn.text,
      })),
    trigger,
  }
}

async function updateSessionState(
  env: Env,
  sessionId: string,
  {
    currentSectionId,
    path,
    openClawThreadId,
    metadata,
    status,
    endedAt,
  }: {
    currentSectionId?: string | null
    path?: string
    openClawThreadId?: string | null
    metadata?: WebCompanionSessionMetadata
    status?: "active" | "ended" | "expired"
    endedAt?: Date | null
  },
) {
  const db = createDb(env)

  const [updatedSession] = await db
    .update(webCompanionSessions)
    .set({
      ...(currentSectionId !== undefined
        ? {
            currentSectionId,
          }
        : {}),
      ...(path !== undefined
        ? {
            path,
          }
        : {}),
      ...(openClawThreadId !== undefined
        ? {
            openclawThreadId: openClawThreadId,
          }
        : {}),
      ...(metadata !== undefined
        ? {
            metadata,
          }
        : {}),
      ...(status !== undefined
        ? {
            status,
          }
        : {}),
      ...(endedAt !== undefined
        ? {
            endedAt,
          }
        : {}),
      lastActiveAt: new Date(),
    })
    .where(eq(webCompanionSessions.id, sessionId))
    .returning()

  return updatedSession
}

async function ensureVisitor(
  env: Env,
  input: {
    visitorId?: unknown
    referrerSource?: unknown
    locale?: unknown
    userAgent?: unknown
  },
) {
  const db = createDb(env)
  const anonymousId = normalizeVisitorId(input.visitorId)
  const referrerSource =
    typeof input.referrerSource === "string" && input.referrerSource.trim()
      ? input.referrerSource.trim().slice(0, 160)
      : null
  const locale =
    typeof input.locale === "string" && input.locale.trim()
      ? input.locale.trim().slice(0, 32)
      : null
  const userAgent =
    typeof input.userAgent === "string" && input.userAgent.trim()
      ? input.userAgent.trim().slice(0, 512)
      : null

  const [existingVisitor] = await db
    .select()
    .from(webVisitors)
    .where(eq(webVisitors.anonymousId, anonymousId))
    .limit(1)

  if (existingVisitor) {
    const [updatedVisitor] = await db
      .update(webVisitors)
      .set({
        lastSeenAt: new Date(),
        ...(referrerSource
          ? {
              referrerSource,
            }
          : {}),
        ...(locale
          ? {
              locale,
            }
          : {}),
        ...(userAgent
          ? {
              userAgent,
            }
          : {}),
      })
      .where(eq(webVisitors.id, existingVisitor.id))
      .returning()

    return updatedVisitor
  }

  const [newVisitor] = await db
    .insert(webVisitors)
    .values({
      anonymousId,
      referrerSource,
      locale,
      userAgent,
      firstSeenAt: new Date(),
      lastSeenAt: new Date(),
    })
    .returning()

  return newVisitor
}

export async function bootstrapWebCompanionSession(
  env: Env,
  input: {
    visitorId?: unknown
    path?: unknown
    currentSectionId?: unknown
    referrerSource?: unknown
    locale?: unknown
    userAgent?: unknown
  },
) {
  console.info("[web-companion] bootstrap:start")
  const db = createDb(env)
  const visitor = await ensureVisitor(env, input)
  const path = normalizePath(input.path)
  const currentSectionId =
    typeof input.currentSectionId === "string" &&
    isKnownWebCompanionSection(input.currentSectionId)
      ? input.currentSectionId
      : null
  const activeCutoff = new Date(Date.now() - ACTIVE_SESSION_WINDOW_MS)

  const [existingSession] = await db
    .select()
    .from(webCompanionSessions)
    .where(
      and(
        eq(webCompanionSessions.visitorId, visitor.id),
        eq(webCompanionSessions.status, "active"),
        gt(webCompanionSessions.lastActiveAt, activeCutoff),
      ),
    )
    .orderBy(desc(webCompanionSessions.lastActiveAt))
    .limit(1)

  if (existingSession) {
    const history = await listRecentTurns(env, existingSession.id)
    console.info("[web-companion] bootstrap:resume", {
      sessionId: existingSession.id,
      visitorId: visitor.anonymousId,
    })
    return {
      visitorId: visitor.anonymousId,
      session: serializeSession(existingSession, visitor.anonymousId),
      history: history.map(serializeTurn),
    }
  }

  const initialMetadata: WebCompanionSessionMetadata = {
    visitedSectionIds: currentSectionId ? [currentSectionId] : [],
    nudgedSectionIds: [],
    mutedUntil: null,
  }

  const [newSession] = await db
    .insert(webCompanionSessions)
    .values({
      visitorId: visitor.id,
      path,
      entrySectionId: currentSectionId,
      currentSectionId,
      metadata: initialMetadata,
    })
    .returning()

  console.info("[web-companion] bootstrap:new", {
    sessionId: newSession.id,
    visitorId: visitor.anonymousId,
  })
  return {
    visitorId: visitor.anonymousId,
    session: serializeSession(newSession, visitor.anonymousId),
    history: [],
  }
}

export async function getWebCompanionSessionSnapshot(env: Env, sessionId: string) {
  const bundle = await getSessionBundle(env, sessionId)

  if (!bundle) {
    return null
  }

  const history = await listRecentTurns(env, sessionId)

  return {
    visitorId: bundle.visitor.anonymousId,
    session: serializeSession(bundle.session, bundle.visitor.anonymousId),
    history: history.map(serializeTurn),
  }
}

function shouldSendProactiveNudge(
  eventType: string,
  currentSectionId: string | null,
  metadata: WebCompanionSessionMetadata,
  ctaId: string | null,
) {
  if (eventType === "companion_opened" || eventType === "experience_activated") {
    return true
  }

  if (
    eventType === "cta_hovered" &&
    (ctaId === "hero-download-cta" || ctaId === "pricing-download-cta")
  ) {
    if (metadata.mutedUntil) {
      const mutedUntilTime = new Date(metadata.mutedUntil).getTime()
      if (!Number.isNaN(mutedUntilTime) && mutedUntilTime > Date.now()) {
        return false
      }
    }

    return true
  }

  if (eventType !== "section_entered" || !currentSectionId) {
    return false
  }

  if (metadata.nudgedSectionIds.length >= MAX_PROACTIVE_NUDGES_PER_SESSION) {
    return false
  }

  if (metadata.nudgedSectionIds.includes(currentSectionId)) {
    return false
  }

  if (metadata.mutedUntil) {
    const mutedUntilTime = new Date(metadata.mutedUntil).getTime()
    if (!Number.isNaN(mutedUntilTime) && mutedUntilTime > Date.now()) {
      return false
    }
  }

  return true
}

export async function recordWebCompanionEvent(
  env: Env,
  sessionId: string,
  input: {
    type?: unknown
    path?: unknown
    sectionId?: unknown
    ctaId?: unknown
    visitedSectionIds?: unknown
    dwellMs?: unknown
    screenContext?: unknown
  },
) {
  console.info("[web-companion] event:start", {
    sessionId,
    type: input.type,
  })
  const bundle = await getSessionBundle(env, sessionId)

  if (!bundle) {
    return null
  }

  const db = createDb(env)
  const eventType =
    typeof input.type === "string" && input.type.trim()
      ? input.type.trim().slice(0, 80)
      : "unknown"
  const sectionId =
    typeof input.sectionId === "string" &&
    isKnownWebCompanionSection(input.sectionId)
      ? input.sectionId
      : null
  const path = normalizePath(input.path ?? bundle.session.path)
  const ctaId =
    typeof input.ctaId === "string" && input.ctaId.trim()
      ? input.ctaId.trim().slice(0, 120)
      : null
  const screenContext = normalizeScreenContext(input.screenContext)
  const sessionMetadata = normalizeSessionMetadata(bundle.session.metadata)
  const nextMetadata: WebCompanionSessionMetadata = {
    ...sessionMetadata,
    visitedSectionIds: mergeVisitedSectionIds(
      sessionMetadata,
      normalizeStringArray(input.visitedSectionIds),
      sectionId,
    ),
  }

  if (eventType === "proactive_nudge_dismissed") {
    nextMetadata.mutedUntil = new Date(
      Date.now() + PROACTIVE_MUTE_WINDOW_MS,
    ).toISOString()
  }

  await db.insert(webCompanionEvents).values({
    sessionId,
    eventType,
    sectionId,
    payload: {
      path,
      ctaId,
      dwellMs: typeof input.dwellMs === "number" ? input.dwellMs : null,
      visitedSectionIds: nextMetadata.visitedSectionIds,
    },
  })

  const updatedSession = await updateSessionState(env, sessionId, {
    currentSectionId: sectionId ?? bundle.session.currentSectionId,
    path,
    metadata: nextMetadata,
  })

  if (!updatedSession) {
    return null
  }

  let response: WebCompanionResponse | null = null

  if (
    shouldSendProactiveNudge(
      eventType,
      sectionId ?? updatedSession.currentSectionId,
      nextMetadata,
      ctaId,
    )
  ) {
    const recentTurns = await listRecentTurns(env, sessionId)
    const generationInput = buildGenerationInput(
      updatedSession,
      bundle.visitor.anonymousId,
      nextMetadata,
      recentTurns,
      {
        type: "event",
        eventType,
        sectionId: sectionId ?? updatedSession.currentSectionId,
        ctaId,
      },
      screenContext,
    )

    response = await generateWebCompanionReply(env, generationInput)

    if (sectionId && !nextMetadata.nudgedSectionIds.includes(sectionId)) {
      nextMetadata.nudgedSectionIds = [...nextMetadata.nudgedSectionIds, sectionId]
    }

    await storeAssistantTurn(
      env,
      sessionId,
      response,
      sectionId ?? updatedSession.currentSectionId,
      "event",
    )

    await updateSessionState(env, sessionId, {
      openClawThreadId: response.openClawThreadId,
      metadata: nextMetadata,
    })
  }

  console.info("[web-companion] event:done", {
    hasResponse: Boolean(response),
    sessionId,
    type: eventType,
  })

  return {
    visitorId: bundle.visitor.anonymousId,
    session: serializeSession(updatedSession, bundle.visitor.anonymousId),
    response,
  }
}

export async function sendWebCompanionMessage(
  env: Env,
  sessionId: string,
  input: {
    message?: unknown
    path?: unknown
    sectionId?: unknown
    visitedSectionIds?: unknown
    screenContext?: unknown
  },
) {
  console.info("[web-companion] message:start", {
    sessionId,
  })
  const bundle = await getSessionBundle(env, sessionId)

  if (!bundle) {
    return null
  }

  const db = createDb(env)
  const message =
    typeof input.message === "string" && input.message.trim()
      ? input.message.trim().slice(0, MAX_MESSAGE_LENGTH)
      : ""

  if (!message) {
    throw new Error("A companion message is required.")
  }

  const sectionId =
    typeof input.sectionId === "string" &&
    isKnownWebCompanionSection(input.sectionId)
      ? input.sectionId
      : bundle.session.currentSectionId
  const path = normalizePath(input.path ?? bundle.session.path)
  const screenContext = normalizeScreenContext(input.screenContext)
  const sessionMetadata = normalizeSessionMetadata(bundle.session.metadata)
  const nextMetadata: WebCompanionSessionMetadata = {
    ...sessionMetadata,
    visitedSectionIds: mergeVisitedSectionIds(
      sessionMetadata,
      normalizeStringArray(input.visitedSectionIds),
      sectionId,
    ),
  }

  const updatedSession = await updateSessionState(env, sessionId, {
    currentSectionId: sectionId,
    path,
    metadata: nextMetadata,
  })

  if (!updatedSession) {
    return null
  }

  await db.insert(webCompanionTurns).values({
    sessionId,
    role: "user",
    triggerType: "message",
    currentSectionId: sectionId,
    text: message,
    metadata: {
      path,
      sectionId,
      screenAttachmentCount: screenContext?.attachments.length ?? 0,
      screenContextSource: screenContext?.source ?? null,
    },
  })

  const recentTurns = await listRecentTurns(env, sessionId)
  const generationInput = buildGenerationInput(
    updatedSession,
    bundle.visitor.anonymousId,
    nextMetadata,
    recentTurns,
    {
      type: "message",
      message,
      sectionId,
    },
    screenContext,
  )

  const response = await generateWebCompanionReply(env, generationInput)

  await storeAssistantTurn(env, sessionId, response, sectionId, "message")

  const sessionAfterResponse = await updateSessionState(env, sessionId, {
    openClawThreadId: response.openClawThreadId,
    metadata: nextMetadata,
  })

  console.info("[web-companion] message:done", {
    hasAudio: Boolean(response.audio?.audioBase64),
    provider: response.provider,
    sessionId,
  })

  return {
    visitorId: bundle.visitor.anonymousId,
    session: serializeSession(
      sessionAfterResponse ?? updatedSession,
      bundle.visitor.anonymousId,
    ),
    response,
  }
}

export async function endWebCompanionSession(env: Env, sessionId: string) {
  const bundle = await getSessionBundle(env, sessionId)

  if (!bundle) {
    return null
  }

  const updatedSession = await updateSessionState(env, sessionId, {
    status: "ended",
    endedAt: new Date(),
  })

  if (!updatedSession) {
    return null
  }

  return {
    visitorId: bundle.visitor.anonymousId,
    session: serializeSession(updatedSession, bundle.visitor.anonymousId),
  }
}
