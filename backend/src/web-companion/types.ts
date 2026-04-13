export type WebCompanionActionType =
  | "highlight"
  | "pulse"
  | "scroll_to_section"
  | "open_companion"
  | "suggest_replies"

export interface WebCompanionAction {
  type: WebCompanionActionType
  targetId?: string
  label?: string
}

export interface WebCompanionBubble {
  mode: "hidden" | "brief"
  text?: string
}

export interface WebCompanionResponse {
  audio?:
    | {
        audioBase64: string
        fileExtension?: string
        mimeType?: string
        provider?: string
      }
    | null
  bubble?: WebCompanionBubble
  mode: "nudge" | "message"
  text: string
  suggestedReplies: string[]
  actions: WebCompanionAction[]
  voice: {
    shouldSpeak: boolean
  }
  provider: "openclaw-gateway" | "local-fallback"
  openClawThreadId: string | null
}

export interface WebCompanionHistoryTurn {
  role: "user" | "assistant"
  text: string
}

export interface WebCompanionImageAttachment {
  contentBase64: string
  label: string
  mimeType: string
}

export interface WebCompanionScreenContext {
  attachments: WebCompanionImageAttachment[]
  source: "display-media" | "site-layout-reference"
}

export interface WebCompanionGenerationInput {
  visitorId: string
  sessionId: string
  openClawThreadId: string | null
  path: string
  currentSectionId: string | null
  visitedSectionIds: string[]
  screenContext: WebCompanionScreenContext | null
  history: WebCompanionHistoryTurn[]
  trigger:
    | {
        type: "event"
        eventType: string
        sectionId: string | null
        ctaId?: string | null
        screenContext?: WebCompanionScreenContext | null
      }
    | {
        type: "message"
        message: string
        sectionId: string | null
        screenContext?: WebCompanionScreenContext | null
      }
}

export interface WebCompanionSection {
  id: string
  title: string
  summary: string
  proactiveNudge: string
  suggestedQuestions: string[]
  allowedTargets: string[]
}

export interface WebCompanionSessionMetadata {
  visitedSectionIds: string[]
  nudgedSectionIds: string[]
  mutedUntil: string | null
  sessionTokenHash?: string | null
}
