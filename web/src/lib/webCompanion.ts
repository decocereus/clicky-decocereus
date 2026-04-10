import { getBackendUrl } from './backend'

export type WebCompanionActionType =
  | 'highlight'
  | 'pulse'
  | 'scroll_to_section'
  | 'open_companion'
  | 'suggest_replies'

export interface WebCompanionAction {
  type: WebCompanionActionType
  targetId?: string
  label?: string
}

export interface WebCompanionBubble {
  mode: 'hidden' | 'brief'
  text?: string
}

export interface WebCompanionReply {
  audio?:
    | {
        audioBase64: string
        fileExtension?: string
        mimeType?: string
        provider?: string
      }
    | null
  bubble?: WebCompanionBubble
  mode: 'nudge' | 'message'
  text: string
  suggestedReplies: string[]
  actions: WebCompanionAction[]
  voice: {
    shouldSpeak: boolean
  }
  provider: 'openclaw-gateway' | 'local-fallback'
  openClawThreadId: string | null
}

export interface WebCompanionMessage {
  id: string
  role: 'user' | 'assistant'
  text: string
  actions: WebCompanionAction[]
  createdAt: string
}

export interface WebCompanionSessionSnapshot {
  id: string
  visitorId: string
  path: string
  entrySectionId: string | null
  currentSectionId: string | null
  openClawThreadId: string | null
  status: 'active' | 'ended' | 'expired'
  startedAt: string
  lastActiveAt: string
  endedAt: string | null
  visitedSectionIds: string[]
}

export interface WebCompanionSessionPayload {
  visitorId: string
  session: WebCompanionSessionSnapshot
  history: WebCompanionMessage[]
}

export interface WebCompanionEventPayload {
  visitorId: string
  session: WebCompanionSessionSnapshot
  response: WebCompanionReply | null
}

export interface WebCompanionImageAttachmentInput {
  contentBase64: string
  label: string
  mimeType: string
}

export interface WebCompanionScreenContextInput {
  attachments: WebCompanionImageAttachmentInput[]
  source: 'display-media' | 'site-layout-reference'
}

function normalizeErrorMessage(error: unknown) {
  if (error instanceof Error && error.message) {
    return error.message
  }

  return 'Something went wrong while talking to Clicky.'
}

async function requestJson<T>(path: string, init: RequestInit) {
  const response = await fetch(`${getBackendUrl()}${path}`, {
    ...init,
    credentials: 'include',
    headers: {
      'content-type': 'application/json',
      ...(init.headers ?? {}),
    },
  })

  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as
      | { error?: string }
      | null

    throw new Error(payload?.error ?? `Request failed with ${response.status}`)
  }

  return (await response.json()) as T
}

export async function bootstrapWebCompanionSession(input: {
  visitorId?: string | null
  path: string
  currentSectionId?: string | null
  referrerSource?: string
  locale?: string
}) {
  try {
    return await requestJson<WebCompanionSessionPayload>(
      '/v1/web-companion/sessions',
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    )
  } catch (error) {
    throw new Error(normalizeErrorMessage(error))
  }
}

export async function sendWebCompanionEvent(
  sessionId: string,
  input: {
    type: string
    path: string
    sectionId?: string | null
    ctaId?: string | null
    visitedSectionIds?: string[]
    dwellMs?: number
    screenContext?: WebCompanionScreenContextInput | null
  }
) {
  try {
    return await requestJson<WebCompanionEventPayload>(
      `/v1/web-companion/sessions/${sessionId}/events`,
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    )
  } catch (error) {
    throw new Error(normalizeErrorMessage(error))
  }
}

export async function sendWebCompanionMessage(
  sessionId: string,
  input: {
    message: string
    path: string
    sectionId?: string | null
    visitedSectionIds?: string[]
    screenContext?: WebCompanionScreenContextInput | null
  }
) {
  try {
    return await requestJson<WebCompanionEventPayload>(
      `/v1/web-companion/sessions/${sessionId}/messages`,
      {
        method: 'POST',
        body: JSON.stringify(input),
      }
    )
  } catch (error) {
    throw new Error(normalizeErrorMessage(error))
  }
}

export async function transcribeWebCompanionAudio(
  sessionId: string,
  input: {
    audioBlob: Blob
    filename?: string
  }
) {
  const formData = new FormData()
  formData.set(
    'audio',
    input.audioBlob,
    input.filename ?? `clicky-web-${Date.now()}.webm`
  )

  const response = await fetch(
    `${getBackendUrl()}/v1/web-companion/sessions/${sessionId}/transcribe`,
    {
      method: 'POST',
      body: formData,
      credentials: 'include',
    }
  )

  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as
      | { error?: string }
      | null

    throw new Error(payload?.error ?? `Request failed with ${response.status}`)
  }

  return (await response.json()) as { transcript: string }
}
