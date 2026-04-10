import type { Env } from "../env"
import { getWebCompanionSection, webCompanionSections } from "./sections"
import { synthesizeElevenLabsAudio } from "./tts"
import type {
  WebCompanionAction,
  WebCompanionGenerationInput,
  WebCompanionResponse,
} from "./types"

const REMOTE_TIMEOUT_MS = 12_000
const GATEWAY_PROTOCOL_VERSION = 3
const GATEWAY_REQUEST_TIMEOUT_MS = 15_000
const GATEWAY_RUN_TIMEOUT_MS = 130_000
const GATEWAY_SCOPES = ["operator.admin", "operator.read", "operator.write"] as const
const CLICKY_WEB_SHELL_ID_PREFIX = "clicky-web"

type PendingGatewayRequest = {
  reject: (error: Error) => void
  resolve: (payload: Record<string, unknown>) => void
  timeoutId: ReturnType<typeof setTimeout>
}

type OpenClawGatewayConfig = {
  agentId: string | null
  authToken: string | null
  gatewayUrl: string
  presentationName: string
  shellEnabled: boolean
  shellIdPrefix: string
  shellTransportScope: "local-gateway" | "remote-gateway"
}

type DeviceIdentity = {
  deviceIdentifier: string
  privateKey: CryptoKey
  publicKeyRawBase64Url: string
}

const allowedTargetIds = new Set(
  webCompanionSections.flatMap((section) => [section.id, ...section.allowedTargets]),
)

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null
}

function normalizeText(value: unknown) {
  return typeof value === "string" ? value.trim() : ""
}

function normalizeActions(value: unknown): WebCompanionAction[] {
  if (!Array.isArray(value)) {
    return []
  }

  return value.flatMap((action) => {
    if (!isRecord(action)) {
      return []
    }

    const type = normalizeText(action.type)
    const targetId = normalizeText(action.targetId) || normalizeText(action.sectionId)
    const label = normalizeText(action.label)

    if (
      type !== "highlight" &&
      type !== "pulse" &&
      type !== "scroll_to_section" &&
      type !== "open_companion" &&
      type !== "suggest_replies"
    ) {
      return []
    }

    return [
      {
        type,
        targetId: targetId || undefined,
        label: label || undefined,
      },
    ]
  })
}

function filterAllowedActions(actions: WebCompanionAction[]) {
  return actions.filter((action) => {
    if (!action.targetId) {
      return true
    }

    return allowedTargetIds.has(action.targetId)
  })
}

function normalizeSuggestedReplies(value: unknown) {
  if (!Array.isArray(value)) {
    return []
  }

  return value
    .map((entry) => (typeof entry === "string" ? entry.trim() : ""))
    .filter(Boolean)
    .slice(0, 3)
}

function normalizeBubble(
  value: unknown,
  fallbackText?: unknown,
): WebCompanionResponse["bubble"] {
  if (isRecord(value)) {
    const mode = normalizeText(value.mode)
    if (mode === "brief") {
      const text = normalizeText(value.text).replace(/\s+/g, " ").slice(0, 72)
      if (text) {
        return {
          mode: "brief",
          text,
        }
      }
    }

    return {
      mode: "hidden",
    }
  }

  const normalizedFallbackText =
    typeof fallbackText === "string"
      ? fallbackText.trim().replace(/\s+/g, " ").slice(0, 72)
      : ""

  if (normalizedFallbackText) {
    return {
      mode: "brief",
      text: normalizedFallbackText,
    }
  }

  return {
    mode: "hidden",
  }
}

function fallbackSuggestedReplies(
  currentSectionId: string | null,
  fallbackReplies: string[],
) {
  if (fallbackReplies.length > 0) {
    return fallbackReplies
  }

  return getWebCompanionSection(currentSectionId)?.suggestedQuestions.slice(0, 2) ?? []
}

function normalizeBooleanString(value: string | undefined) {
  return value?.trim().toLowerCase() === "true"
}

function inferShellTransportScope(gatewayUrl: string) {
  try {
    const url = new URL(gatewayUrl)
    const hostname = url.hostname.trim().toLowerCase()
    if (
      hostname === "127.0.0.1" ||
      hostname === "localhost" ||
      hostname === "::1"
    ) {
      return "local-gateway" as const
    }
  } catch {
    // Fall through to remote.
  }

  return "remote-gateway" as const
}

function stripCodeFence(text: string) {
  const trimmed = text.trim()
  if (!trimmed.startsWith("```")) {
    return trimmed
  }

  const withoutOpeningFence = trimmed.replace(/^```(?:json)?\s*/i, "")
  return withoutOpeningFence.replace(/\s*```$/, "").trim()
}

function parseStructuredAssistantText(
  rawText: string,
  provider: WebCompanionResponse["provider"],
  input: WebCompanionGenerationInput,
  openClawThreadId: string,
): WebCompanionResponse {
  const normalizedText = rawText.trim()
  const jsonCandidate = stripCodeFence(normalizedText)

  if (jsonCandidate.startsWith("{")) {
    try {
      const parsed = JSON.parse(jsonCandidate) as unknown
      if (isRecord(parsed) && normalizeText(parsed.text)) {
        return {
          mode:
            normalizeText(parsed.mode) === "nudge" && input.trigger.type === "event"
              ? "nudge"
              : "message",
          bubble: normalizeBubble(
            parsed.bubble,
            isRecord(parsed.bubble) ? undefined : parsed.bubbleText,
          ),
          text: normalizeText(parsed.text),
          suggestedReplies: fallbackSuggestedReplies(
            input.currentSectionId,
            normalizeSuggestedReplies(parsed.suggestedReplies),
          ),
          actions: filterAllowedActions(normalizeActions(parsed.actions)),
          voice: {
            shouldSpeak:
              isRecord(parsed.voice) && parsed.voice.shouldSpeak === true,
          },
          provider,
          openClawThreadId,
        }
      }
    } catch {
      // Fall back to plain-text handling.
    }
  }

  return {
    bubble: {
      mode: "hidden",
    },
    mode: input.trigger.type === "event" ? "nudge" : "message",
    text: normalizedText || "Clicky did not return a response.",
    suggestedReplies: fallbackSuggestedReplies(input.currentSectionId, []),
    actions: [],
    voice: {
      shouldSpeak: false,
    },
    provider,
    openClawThreadId,
  }
}

function extractGatewayTalkAudio(payload: Record<string, unknown>) {
  const audioBase64 = normalizeText(payload.audioBase64)
  if (!audioBase64) {
    return null
  }

  return {
    audioBase64,
    fileExtension: normalizeText(payload.fileExtension) || undefined,
    mimeType: normalizeText(payload.mimeType) || undefined,
    provider: normalizeText(payload.provider) || undefined,
  }
}

function inferIntent(message: string) {
  const normalizedMessage = message.toLowerCase()

  if (
    normalizedMessage.includes("price") ||
    normalizedMessage.includes("pricing") ||
    normalizedMessage.includes("cost") ||
    normalizedMessage.includes("worth")
  ) {
    return "pricing"
  }

  if (
    normalizedMessage.includes("youtube") ||
    normalizedMessage.includes("video") ||
    normalizedMessage.includes("tutorial")
  ) {
    return "video"
  }

  if (
    normalizedMessage.includes("screen") ||
    normalizedMessage.includes("see") ||
    normalizedMessage.includes("context")
  ) {
    return "screen"
  }

  if (
    normalizedMessage.includes("point") ||
    normalizedMessage.includes("guide") ||
    normalizedMessage.includes("show me where")
  ) {
    return "guidance"
  }

  if (
    normalizedMessage.includes("openclaw") ||
    normalizedMessage.includes("agent") ||
    normalizedMessage.includes("identity")
  ) {
    return "identity"
  }

  if (
    normalizedMessage.includes("workflow") ||
    normalizedMessage.includes("repeat") ||
    normalizedMessage.includes("automation")
  ) {
    return "workflow"
  }

  return "general"
}

function buildLocalFallbackResponse(
  input: WebCompanionGenerationInput,
): WebCompanionResponse {
  const currentSection = getWebCompanionSection(input.currentSectionId)
  const defaultThreadId = input.openClawThreadId ?? `local-fallback:${input.sessionId}`

  if (input.trigger.type === "event") {
    if (
      input.trigger.eventType === "companion_opened" ||
      input.trigger.eventType === "experience_activated"
    ) {
      const text = currentSection
        ? `Welcome to Clicky. You're in "${currentSection.title}". ${currentSection.summary} Right now my job is to give you a lightweight live demo of how Clicky guides from the cursor, and to invite you to hold Control-Option when you're ready to talk.`
        : "Welcome to Clicky. Right now my job is to give you a lightweight live demo from the cursor and guide you into holding Control-Option when you're ready to talk."

      return {
        bubble: {
          mode: "brief",
          text: "Hold Ctrl-Option",
        },
        mode: "message",
        text,
        suggestedReplies:
          currentSection?.suggestedQuestions.slice(0, 2) ?? [
            "What makes Clicky different?",
            "How does this work with OpenClaw?",
          ],
        actions: currentSection
          ? [{ type: "highlight", targetId: currentSection.id }]
          : [],
        voice: {
          shouldSpeak: false,
        },
        provider: "local-fallback",
        openClawThreadId: defaultThreadId,
      }
    }

    if (input.trigger.eventType === "section_entered" && currentSection) {
      return {
        mode: "nudge",
        text: currentSection.proactiveNudge,
        suggestedReplies: currentSection.suggestedQuestions.slice(0, 2),
        actions: [{ type: "highlight", targetId: currentSection.id }],
        voice: {
          shouldSpeak: false,
        },
        provider: "local-fallback",
        openClawThreadId: defaultThreadId,
      }
    }

    if (
      input.trigger.eventType === "cta_hovered" &&
      input.trigger.ctaId === "hero-download-cta"
    ) {
      return {
        bubble: {
          mode: "brief",
          text: "Download starts here",
        },
        mode: "nudge",
        text:
          "If you're hovering here, the short version is that Clicky is meant to be a living shell around your agent, not just another chatbot tab.",
        suggestedReplies: [
          "What happens after I download?",
          "How does this work with OpenClaw?",
        ],
        actions: [{ type: "highlight", targetId: "hero-download-cta" }],
        voice: {
          shouldSpeak: false,
        },
        provider: "local-fallback",
        openClawThreadId: defaultThreadId,
      }
    }

    if (
      input.trigger.eventType === "cta_hovered" &&
      input.trigger.ctaId === "pricing-download-cta"
    ) {
      return {
        bubble: {
          mode: "brief",
          text: "Pricing is here",
        },
        mode: "nudge",
        text:
          "This plan is framed as the full Clicky launch experience at an early supporter price. I can break down what is included before you commit.",
        suggestedReplies: [
          "What do I get for the launch price?",
          "Who is Clicky for right now?",
        ],
        actions: [{ type: "highlight", targetId: "pricing-download-cta" }],
        voice: {
          shouldSpeak: false,
        },
        provider: "local-fallback",
        openClawThreadId: defaultThreadId,
      }
    }

    return {
      bubble: {
        mode: "brief",
        text: "Need the short version?",
      },
      mode: "nudge",
      text: "I’m here if you want the short version of what Clicky is doing in this part of the page.",
      suggestedReplies: [
        "Give me the short version",
        "How is this different from a chatbot?",
      ],
      actions: [],
      voice: {
        shouldSpeak: false,
      },
      provider: "local-fallback",
      openClawThreadId: defaultThreadId,
    }
  }

  const message = input.trigger.message
  const intent = inferIntent(message)

  if (intent === "pricing") {
    return {
      bubble:
        input.currentSectionId === "pricing"
          ? {
              mode: "brief",
              text: "Pricing details",
            }
          : {
              mode: "brief",
              text: "Let me show pricing",
            },
      mode: "message",
      text:
        "Right now the site presents one launch plan at $49 per year, positioned as an early supporter price. The page frames it as the full Clicky experience rather than a confusing tier grid.",
      suggestedReplies: [
        "Who is Clicky a fit for?",
        "What happens after I download?",
      ],
      actions:
        input.currentSectionId === "pricing"
          ? [{ type: "highlight", targetId: "pricing" }]
          : [{ type: "scroll_to_section", targetId: "pricing" }],
      voice: {
        shouldSpeak: false,
      },
      provider: "local-fallback",
      openClawThreadId: defaultThreadId,
    }
  }

  if (intent === "video") {
    return {
      mode: "message",
      text:
        "The video story is that Clicky can turn tutorial material into something more actionable than passive playback. Instead of leaving knowledge inside the video, the product aims to pull out steps you can actually follow and reuse.",
      suggestedReplies: [
        "Can it turn tutorials into workflows?",
        "What other inputs can it use?",
      ],
      actions: [{ type: "scroll_to_section", targetId: "learns-video" }],
      voice: {
        shouldSpeak: false,
      },
      provider: "local-fallback",
      openClawThreadId: defaultThreadId,
    }
  }

  if (intent === "screen") {
    return {
      mode: "message",
      text:
        "Screen awareness is what makes Clicky feel grounded. The idea is that the agent doesn't answer in a vacuum. It reacts to what you're already looking at, which is why the Mac app can guide instead of just chat.",
      suggestedReplies: [
        "How does Clicky point at things?",
        "Does OpenClaw stay the agent?",
      ],
      actions: [{ type: "scroll_to_section", targetId: "sees-screen" }],
      voice: {
        shouldSpeak: false,
      },
      provider: "local-fallback",
      openClawThreadId: defaultThreadId,
    }
  }

  if (intent === "guidance") {
    return {
      mode: "message",
      text:
        "The guiding idea is that Clicky should show, not only tell. On desktop that means cursor-side guidance and pointing. On the website, the first version mirrors that with contextual explanations and section-aware highlighting.",
      suggestedReplies: [
        "How is the website version different from the Mac app?",
        "Can Clicky automate workflows too?",
      ],
      actions: [{ type: "scroll_to_section", targetId: "points-way" }],
      voice: {
        shouldSpeak: false,
      },
      provider: "local-fallback",
      openClawThreadId: defaultThreadId,
    }
  }

  if (intent === "identity") {
    return {
      mode: "message",
      text:
        "The product line here is consistent with the desktop app: OpenClaw remains the upstream agent, and Clicky is the shell around it. That means you can keep your own agent identity while Clicky owns the presentation layer.",
      suggestedReplies: [
        "What does Clicky add on top of OpenClaw?",
        "Can I use my own agent in production?",
      ],
      actions: [{ type: "scroll_to_section", targetId: "can-be-anything" }],
      voice: {
        shouldSpeak: false,
      },
      provider: "local-fallback",
      openClawThreadId: defaultThreadId,
    }
  }

  if (intent === "workflow") {
    return {
      mode: "message",
      text:
        "The workflow angle is that Clicky shouldn't only help once. It should help you repeat useful patterns once a task becomes clear enough to capture and replay.",
      suggestedReplies: [
        "Can Clicky learn from tutorials too?",
        "What is the first version of the website companion doing?",
      ],
      actions: [{ type: "scroll_to_section", targetId: "repeats-workflows" }],
      voice: {
        shouldSpeak: false,
      },
      provider: "local-fallback",
      openClawThreadId: defaultThreadId,
    }
  }

  if (currentSection) {
    return {
      mode: "message",
      text: `${currentSection.summary} If you want, I can unpack the promise on this section or connect it back to the real Clicky desktop behavior.`,
      suggestedReplies: currentSection.suggestedQuestions.slice(0, 2),
      actions: [{ type: "highlight", targetId: currentSection.id }],
      voice: {
        shouldSpeak: false,
      },
      provider: "local-fallback",
      openClawThreadId: defaultThreadId,
    }
  }

  return {
    mode: "message",
    text:
      "Clicky is the shell layer around an agent. On Mac that means voice, screen context, and pointing. On the site, this companion is the first browser version of that same idea.",
    suggestedReplies: [
      "What makes Clicky different?",
      "How does it work with OpenClaw?",
    ],
    actions: [],
    voice: {
      shouldSpeak: false,
    },
    provider: "local-fallback",
    openClawThreadId: defaultThreadId,
  }
}

function resolveGatewayConfig(env: Env): OpenClawGatewayConfig | null {
  const candidateUrl = env.OPENCLAW_GATEWAY_URL?.trim() || ""

  if (!candidateUrl || (!candidateUrl.startsWith("ws://") && !candidateUrl.startsWith("wss://"))) {
    return null
  }

  return {
    agentId: normalizeText(env.OPENCLAW_AGENT_ID) || null,
    authToken: normalizeText(env.OPENCLAW_GATEWAY_AUTH_TOKEN) || null,
    gatewayUrl: candidateUrl,
    presentationName:
      normalizeText(env.OPENCLAW_CLICKY_WEB_PRESENTATION_NAME) ||
      "Clicky Website Companion",
    shellEnabled: normalizeBooleanString(env.OPENCLAW_CLICKY_WEB_SHELL_ENABLED),
    shellIdPrefix: CLICKY_WEB_SHELL_ID_PREFIX,
    shellTransportScope: inferShellTransportScope(candidateUrl),
  }
}

function ctaHintForTrigger(ctaId: string | null | undefined) {
  if (ctaId === "hero-download-cta") {
    return "The visitor is evaluating the main hero download CTA."
  }

  if (ctaId === "pricing-download-cta") {
    return "The visitor is evaluating the pricing download CTA."
  }

  if (ctaId === "footer-download-cta") {
    return "The visitor is evaluating the footer download CTA."
  }

  if (ctaId === "nav-download-cta" || ctaId === "nav-mobile-download-cta") {
    return "The visitor is hovering a navigation download CTA."
  }

  return null
}

function buildGatewayMessageBody(input: WebCompanionGenerationInput) {
  const currentSection = getWebCompanionSection(input.currentSectionId)
  const visitedSectionTitles = input.visitedSectionIds
    .map((sectionId) => getWebCompanionSection(sectionId)?.title ?? sectionId)
    .join(", ")
  const currentAllowedTargets = currentSection?.allowedTargets.join(", ") ?? "none"
  const allAllowedTargets = [...allowedTargetIds].join(", ")
  const triggerSummary =
    input.trigger.type === "message"
      ? `Visitor message:\n${input.trigger.message}`
      : [
          `Visitor event: ${input.trigger.eventType}`,
          input.trigger.sectionId ? `Section: ${input.trigger.sectionId}` : null,
          ctaHintForTrigger(input.trigger.ctaId) ?? null,
        ]
          .filter(Boolean)
          .join("\n")

  return [
    "Runtime instructions for this reply:",
    [
      "You are Clicky, the companion layered onto the public Clicky marketing site.",
      "Return a single JSON object only. Do not use markdown, code fences, or explanatory text outside JSON.",
      'JSON schema: {"text": string, "bubble": {"mode": "hidden" | "brief", "text"?: string}, "suggestedReplies": string[], "actions": [{"type": "highlight" | "pulse" | "scroll_to_section" | "open_companion", "targetId": string}], "voice": {"shouldSpeak": false}}.',
      "Keep text concise, helpful, and product-accurate.",
      "The text field is the full companion reply. Do not assume it will be shown in the cursor bubble.",
      "Use bubble.mode='hidden' by default.",
      "Only use bubble.mode='brief' when a tiny cursor-side cue would materially help, like pointing out what to click, confirming a short step, or giving a very short nudge.",
      "Bubble text must stay short, ideally under 5 words and never more than one short sentence.",
      "Never copy the full reply into bubble.text.",
      "Only use targetId values from the allowed target list.",
      "Use at most two suggested replies and at most one action.",
      "Do not auto-scroll or navigate the page on the visitor's behalf.",
      "Use highlights and cursor-adjacent cues instead of forcing page movement.",
      "If the trigger is a passive event, keep the tone like a subtle nudge, not a hard sell.",
      "Do not invent unsupported features, pricing, or roadmap promises.",
      "Voice should remain disabled in this web surface unless explicitly instructed elsewhere.",
      "You are integrated into the current Clicky website. Your job is to present Clicky in a strong light, explain what it does, and surface compelling benefits and use cases unlocked by the product.",
      "The cursor companion can present text bubble information separately from spoken audio, so keep bubble text distinct from the main reply when you use it.",
      "For an experience_activated event, welcome the visitor briefly, explain that Clicky is currently demonstrating the website cursor-guidance experience, and remind them they can hold Control-Option to talk.",
    ].join(" "),
    currentSection
      ? `Current section:\n- id: ${currentSection.id}\n- title: ${currentSection.title}\n- summary: ${currentSection.summary}\n- section targets: ${currentAllowedTargets}`
      : "Current section: none",
    visitedSectionTitles
      ? `Visited sections so far:\n${visitedSectionTitles}`
      : "Visited sections so far: none",
    `Allowed target ids across the page:\n${allAllowedTargets}`,
    `Session path:\n${input.path}`,
    triggerSummary,
  ].join("\n\n")
}

function base64UrlEncode(data: ArrayBuffer | Uint8Array) {
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data)
  let binary = ""
  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "")
}

async function createEphemeralDeviceIdentity(): Promise<DeviceIdentity> {
  const keyPair = (await crypto.subtle.generateKey(
    { name: "Ed25519" } as never,
    true,
    ["sign", "verify"],
  )) as CryptoKeyPair

  const publicKeyRaw = (await crypto.subtle.exportKey(
    "raw",
    keyPair.publicKey,
  )) as ArrayBuffer
  const publicKeyHash = await crypto.subtle.digest("SHA-256", publicKeyRaw)
  const deviceIdentifier = Array.from(new Uint8Array(publicKeyHash))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")

  return {
    deviceIdentifier,
    privateKey: keyPair.privateKey,
    publicKeyRawBase64Url: base64UrlEncode(publicKeyRaw),
  }
}

class OpenClawGatewayClient {
  private readonly deviceIdentityPromise = createEphemeralDeviceIdentity()
  private readonly pendingResponses = new Map<string, PendingGatewayRequest>()

  private accumulatedAssistantText = ""
  private connectChallengeNonce: string | null = null
  private connectChallengeResolver: ((nonce: string) => void) | null = null
  private connectChallengeRejector: ((error: Error) => void) | null = null
  private lifecycleErrorMessage: string | null = null
  private openPromise: Promise<void> | null = null
  private socket: WebSocket | null = null
  private trackedRunId: string | null = null

  constructor(private readonly config: OpenClawGatewayConfig) {}

  async run(input: WebCompanionGenerationInput): Promise<WebCompanionResponse> {
    const sessionKey =
      normalizeText(input.openClawThreadId) ||
      `${this.config.shellIdPrefix}:${input.sessionId}`

    this.resetRunState()

    try {
      await this.connect()

      try {
        await this.request("sessions.patch", {
          key: sessionKey,
          execAsk: "off",
          execSecurity: "full",
        })
      } catch {
        // A session patch is useful, but not required to return a response.
      }

      if (this.config.shellEnabled) {
        try {
          await this.ensureShellRegistered(input, sessionKey)
        } catch (error) {
          console.warn("[web-companion] Clicky web shell registration failed.", error)
        }
      }

      const runId = crypto.randomUUID()
      const acceptedPayload = await this.request("agent", {
        ...(this.config.agentId
          ? {
              agentId: this.config.agentId,
            }
          : {}),
        idempotencyKey: runId,
        message: buildGatewayMessageBody(input),
        sessionKey,
        timeout: 120_000,
      })

      this.trackedRunId = normalizeText(acceptedPayload.runId) || runId

      const waitPayload = await this.request("agent.wait", {
        runId: this.trackedRunId,
        timeoutMs: 120_000,
      }, GATEWAY_RUN_TIMEOUT_MS)

      const waitStatus = normalizeText(waitPayload.status).toLowerCase()
      if (waitStatus === "timeout") {
        throw new Error("OpenClaw Gateway run timed out.")
      }

      if (waitStatus === "error") {
        throw new Error(
          normalizeText(waitPayload.error) ||
            this.lifecycleErrorMessage ||
            "OpenClaw Gateway run failed.",
        )
      }

      const replyText =
        this.accumulatedAssistantText.trim() ||
        normalizeText(waitPayload.text) ||
        normalizeText((waitPayload.data as Record<string, unknown> | undefined)?.text)

      if (!replyText) {
        throw new Error(
          this.lifecycleErrorMessage || "OpenClaw Gateway did not return assistant text.",
        )
      }

      return parseStructuredAssistantText(
        replyText,
        "openclaw-gateway",
        input,
        sessionKey,
      )
    } finally {
      this.close()
    }
  }

  private async connect() {
    if (!this.openPromise) {
      this.openPromise = new Promise<void>((resolve, reject) => {
        const socket = new WebSocket(this.config.gatewayUrl) as WebSocket & {
          addEventListener: (
            type: string,
            listener: (event: { data?: unknown }) => void,
          ) => void
        }
        this.socket = socket

        socket.addEventListener("open", () => {
          resolve()
        })

        socket.addEventListener("message", (event: { data?: unknown }) => {
          void this.handleIncomingMessage(
            typeof event.data === "string" ? event.data : "",
          )
        })

        socket.addEventListener("error", () => {
          const error = new Error("OpenClaw Gateway WebSocket connection failed.")
          reject(error)
          this.failAll(error)
        })

        socket.addEventListener("close", () => {
          const error = new Error("OpenClaw Gateway WebSocket closed.")
          this.failAll(error)
        })
      })
    }

    await withTimeout(this.openPromise, GATEWAY_REQUEST_TIMEOUT_MS)
    const challengeNonce = await withTimeout(
      this.waitForConnectChallenge(),
      GATEWAY_REQUEST_TIMEOUT_MS,
    )
    await this.request(
      "connect",
      await this.buildConnectParams(challengeNonce),
    )
  }

  private async ensureShellRegistered(
    input: WebCompanionGenerationInput,
    sessionKey: string,
  ) {
    const shellId = `${this.config.shellIdPrefix}:${input.sessionId}`

    await this.request("clicky.shell.register", {
      agentIdentityName: this.config.agentId,
      bridgeVersion: "2026.04.10",
      capabilities: [
        "page_context",
        "text_reply",
        "element_highlight",
        "scroll_guidance",
      ],
      clickyPresentationName: this.config.presentationName,
      clickyShellCapabilityVersion: "2026.04.10",
      cursorPointingProtocol: "web-highlight-target:v1",
      personaScope: "openclaw-identity",
      registeredAt: Date.now(),
      runtimeMode: "web-production",
      screenContextTransport: "structured-page-context",
      sessionKey,
      shellId,
      shellLabel: this.config.presentationName,
      shellProtocolVersion: "2026.04.10",
      shellTransportScope: this.config.shellTransportScope,
      speechOutputMode: "optional-browser-audio",
      supportsInlineTextBubble: true,
    })

    await this.request("clicky.shell.bind_session", {
      shellId,
      sessionKey,
    })
  }

  private async buildConnectParams(challengeNonce: string) {
    const deviceIdentity = await this.deviceIdentityPromise
    const signedAtMilliseconds = Date.now()
    const deviceAuthPayload = [
      "v3",
      deviceIdentity.deviceIdentifier,
      "gateway-client",
      "backend",
      "operator",
      GATEWAY_SCOPES.join(","),
      String(signedAtMilliseconds),
      this.config.authToken ?? "",
      challengeNonce,
      "cloudflare",
      "workers",
    ].join("|")

    const deviceSignature = base64UrlEncode(
      (await crypto.subtle.sign(
        { name: "Ed25519" } as never,
        deviceIdentity.privateKey,
        new TextEncoder().encode(deviceAuthPayload),
      )) as ArrayBuffer,
    )

    const connectParams: Record<string, unknown> = {
      client: {
        deviceFamily: "workers",
        id: "gateway-client",
        mode: "backend",
        platform: "cloudflare",
        version: "clicky-web-companion",
      },
      device: {
        id: deviceIdentity.deviceIdentifier,
        nonce: challengeNonce,
        publicKey: deviceIdentity.publicKeyRawBase64Url,
        signature: deviceSignature,
        signedAt: signedAtMilliseconds,
      },
      maxProtocol: GATEWAY_PROTOCOL_VERSION,
      minProtocol: GATEWAY_PROTOCOL_VERSION,
      role: "operator",
      scopes: [...GATEWAY_SCOPES],
    }

    if (this.config.authToken) {
      connectParams.auth = {
        token: this.config.authToken,
      }
    }

    return connectParams
  }

  private waitForConnectChallenge() {
    if (this.connectChallengeNonce) {
      return Promise.resolve(this.connectChallengeNonce)
    }

    return new Promise<string>((resolve, reject) => {
      this.connectChallengeResolver = resolve
      this.connectChallengeRejector = reject
    })
  }

  private deliverConnectChallenge(nonce: string) {
    this.connectChallengeNonce = nonce
    if (this.connectChallengeResolver) {
      this.connectChallengeResolver(nonce)
      this.connectChallengeResolver = null
      this.connectChallengeRejector = null
    }
  }

  private async request(
    method: string,
    params: Record<string, unknown>,
    timeoutMs: number = GATEWAY_REQUEST_TIMEOUT_MS,
  ) {
    const requestId = crypto.randomUUID()

    return new Promise<Record<string, unknown>>((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        this.pendingResponses.delete(requestId)
        reject(new Error("OpenClaw Gateway request timed out."))
      }, timeoutMs)

      this.pendingResponses.set(requestId, {
        reject,
        resolve,
        timeoutId,
      })

      void this.sendFrame({
        id: requestId,
        method,
        params,
        type: "req",
      }).catch((error) => {
        const pendingRequest = this.pendingResponses.get(requestId)
        if (!pendingRequest) {
          return
        }

        clearTimeout(pendingRequest.timeoutId)
        this.pendingResponses.delete(requestId)
        reject(error instanceof Error ? error : new Error(String(error)))
      })
    })
  }

  private async sendFrame(frame: Record<string, unknown>) {
    await withTimeout(this.openPromise ?? Promise.resolve(), GATEWAY_REQUEST_TIMEOUT_MS)

    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      throw new Error("OpenClaw Gateway WebSocket is not connected.")
    }

    this.socket.send(JSON.stringify(frame))
  }

  private async handleIncomingMessage(messageText: string) {
    if (!messageText) {
      return
    }

    const frame = JSON.parse(messageText) as unknown
    if (!isRecord(frame)) {
      return
    }

    const frameType = normalizeText(frame.type)
    if (frameType === "event") {
      const eventName = normalizeText(frame.event)
      const payload = isRecord(frame.payload) ? frame.payload : {}

      if (eventName === "connect.challenge") {
        const nonce = normalizeText(payload.nonce)
        if (nonce) {
          this.deliverConnectChallenge(nonce)
        }
        return
      }

      if (eventName === "agent") {
        this.handleAgentEventPayload(payload)
      }

      return
    }

    if (frameType === "res") {
      const requestId = normalizeText(frame.id)
      if (!requestId) {
        return
      }

      const pendingRequest = this.pendingResponses.get(requestId)
      if (!pendingRequest) {
        return
      }

      clearTimeout(pendingRequest.timeoutId)
      this.pendingResponses.delete(requestId)

      if (frame.ok === true) {
        pendingRequest.resolve(isRecord(frame.payload) ? frame.payload : {})
        return
      }

      const errorPayload = isRecord(frame.error) ? frame.error : {}
      pendingRequest.reject(
        new Error(
          normalizeText(errorPayload.message) ||
            normalizeText(errorPayload.code) ||
            "OpenClaw Gateway request failed.",
        ),
      )
    }
  }

  private handleAgentEventPayload(payload: Record<string, unknown>) {
    const runId = normalizeText(payload.runId)
    if (!runId) {
      return
    }

    if (this.trackedRunId && this.trackedRunId !== runId) {
      return
    }

    if (!this.trackedRunId) {
      this.trackedRunId = runId
    }

    const stream = normalizeText(payload.stream).toLowerCase()
    const data = isRecord(payload.data) ? payload.data : {}

    if (stream === "assistant") {
      const delta = typeof data.delta === "string" ? data.delta : ""
      const text = typeof data.text === "string" ? data.text : ""

      if (delta) {
        this.accumulatedAssistantText += delta
        return
      }

      if (text) {
        this.accumulatedAssistantText = text
        return
      }
    }

    if (stream === "error") {
      this.lifecycleErrorMessage =
        normalizeText(data.error) ||
        normalizeText(data.message) ||
        this.lifecycleErrorMessage
    }

    if (stream === "lifecycle") {
      const phase = normalizeText(data.phase).toLowerCase()
      if (phase === "error" || phase === "failed" || phase === "cancelled") {
        this.lifecycleErrorMessage =
          normalizeText(data.error) ||
          normalizeText(data.message) ||
          this.lifecycleErrorMessage
      }
    }
  }

  private failAll(error: Error) {
    for (const [requestId, pendingRequest] of this.pendingResponses.entries()) {
      clearTimeout(pendingRequest.timeoutId)
      pendingRequest.reject(error)
      this.pendingResponses.delete(requestId)
    }

    if (this.connectChallengeRejector) {
      this.connectChallengeRejector(error)
      this.connectChallengeResolver = null
      this.connectChallengeRejector = null
    }
  }

  private resetRunState() {
    this.accumulatedAssistantText = ""
    this.connectChallengeNonce = null
    this.lifecycleErrorMessage = null
    this.trackedRunId = null
  }

  private close() {
    this.failAll(new Error("OpenClaw Gateway session closed."))

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.close(1000, "done")
    }

    this.socket = null
    this.openPromise = null
    this.resetRunState()
  }
}

function withTimeout<T>(promise: Promise<T>, timeoutMs: number) {
  return Promise.race<T>([
    promise,
    new Promise<T>((_, reject) => {
      const timeoutId = setTimeout(() => {
        clearTimeout(timeoutId)
        reject(new Error("OpenClaw Gateway request timed out."))
      }, timeoutMs)
    }),
  ])
}

async function attachElevenLabsAudio(
  env: Env,
  response: WebCompanionResponse,
) {
  try {
    const audio = await synthesizeElevenLabsAudio(env, response.text)
    if (audio) {
      response.audio = audio
    }
  } catch (error) {
    console.warn("[web-companion] ElevenLabs synthesis failed.", error)
  }

  return response
}

export async function generateWebCompanionReply(
  env: Env,
  input: WebCompanionGenerationInput,
) {
  const gatewayConfig = resolveGatewayConfig(env)
  if (gatewayConfig) {
    try {
      const gatewayClient = new OpenClawGatewayClient(gatewayConfig)
      return await attachElevenLabsAudio(env, await gatewayClient.run(input))
    } catch (error) {
      console.error("[web-companion] OpenClaw Gateway request failed, falling back.", error)
      return await attachElevenLabsAudio(env, buildLocalFallbackResponse(input))
    }
  }

  return await attachElevenLabsAudio(env, buildLocalFallbackResponse(input))
}
