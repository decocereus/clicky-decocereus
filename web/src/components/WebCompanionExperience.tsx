import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react'

import {
  companionSectionIds,
  getCompanionSection,
} from '../content/companionSections'
import { useActiveCompanionSection } from '../hooks/useActiveCompanionSection'
import {
  bootstrapWebCompanionSession,
  type WebCompanionAction,
  type WebCompanionReply,
  type WebCompanionScreenContextInput,
  type WebCompanionSessionSnapshot,
  sendWebCompanionEvent,
  sendWebCompanionMessage,
  transcribeWebCompanionAudio,
} from '../lib/webCompanion'

const VISITOR_STORAGE_KEY = 'clicky:web-companion:visitor:v1'
const MAX_AUTOMATED_SPOKEN_MESSAGES = 4
const MIN_SPEECH_GAP_MS = 12_000
const SECTION_SETTLE_DELAY_MS = 1_600
const SHORTCUT_RELEASE_GRACE_MS = 260
const SITE_LAYOUT_CONTEXT_WIDTH = 1200
const SITE_LAYOUT_CONTEXT_HEIGHT = 900

type ExperienceMode = 'mic-only' | 'demo-only' | null
type StartExperienceMode = Exclude<ExperienceMode, null>

type ExperienceStatus =
  | 'idle'
  | 'requesting-permission'
  | 'active'
  | 'error'

type BackendMode = 'openclaw-gateway' | 'local-fallback' | null
type CompanionVisualState =
  | 'idle'
  | 'listening'
  | 'transcribing'
  | 'thinking'
  | 'responding'
type VoiceTurnPhase = 'idle' | 'transcribing' | 'thinking'
type CompanionGuidanceTarget = {
  actionType: WebCompanionAction['type']
  id: string
  sequence: number
}

declare global {
  interface Window {
    __clickyVoiceDebugLog?: Array<Record<string, unknown>>
  }
}

interface WebCompanionExperienceValue {
  backendMode: BackendMode
  bubbleText: string | null
  companionVisualState: CompanionVisualState
  currentSectionId: string | null
  errorMessage: string | null
  experienceMode: ExperienceMode
  guidanceTarget: CompanionGuidanceTarget | null
  isListening: boolean
  isSpeaking: boolean
  status: ExperienceStatus
  startExperience: (options?: {
    mode?: StartExperienceMode
  }) => Promise<void>
}

const WebCompanionExperienceContext =
  createContext<WebCompanionExperienceValue | null>(null)

function readStoredVisitorId() {
  if (typeof window === 'undefined') {
    return null
  }

  return window.localStorage.getItem(VISITOR_STORAGE_KEY)
}

function writeStoredVisitorId(visitorId: string) {
  if (typeof window === 'undefined') {
    return
  }

  window.localStorage.setItem(VISITOR_STORAGE_KEY, visitorId)
}

function stripMarkdownArtifacts(text: string) {
  return text
    .replace(/```json/gi, '')
    .replace(/```/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}

function logVoiceDebug(event: string, details: Record<string, unknown> = {}) {
  const payload = {
    details,
    event,
    ts: new Date().toISOString(),
  }

  if (typeof window !== 'undefined') {
    const log = window.__clickyVoiceDebugLog ?? []
    log.push(payload)
    window.__clickyVoiceDebugLog = log.slice(-200)
  }

  console.debug('[clicky-web-voice]', event, details)
}

function getSupportedRecordingMimeType() {
  if (typeof MediaRecorder === 'undefined') {
    return ''
  }

  const candidateMimeTypes = [
    'audio/webm;codecs=opus',
    'audio/webm',
    'audio/mp4',
    'audio/ogg;codecs=opus',
  ]

  return (
    candidateMimeTypes.find((mimeType) =>
      MediaRecorder.isTypeSupported(mimeType)
    ) ?? ''
  )
}

export function useWebCompanionExperience() {
  const context = useContext(WebCompanionExperienceContext)
  if (!context) {
    throw new Error(
      'useWebCompanionExperience must be used within WebCompanionExperienceProvider.'
    )
  }

  return context
}

export function useOptionalCursorCompanionExperience() {
  return useContext(WebCompanionExperienceContext)
}

export function WebCompanionExperienceProvider({
  children,
}: {
  children: ReactNode
}) {
  const [backendMode, setBackendMode] = useState<BackendMode>(null)
  const [bubbleText, setBubbleText] = useState<string | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [experienceMode, setExperienceMode] = useState<ExperienceMode>(null)
  const [guidanceTarget, setGuidanceTarget] =
    useState<CompanionGuidanceTarget | null>(null)
  const [isListening, setIsListening] = useState(false)
  const [isReadyForVoice, setIsReadyForVoice] = useState(false)
  const [isProcessingVoiceTurn, setIsProcessingVoiceTurn] = useState(false)
  const [isSpeaking, setIsSpeaking] = useState(false)
  const [status, setStatus] = useState<ExperienceStatus>('idle')
  const [session, setSession] = useState<WebCompanionSessionSnapshot | null>(null)
  const [voiceTurnPhase, setVoiceTurnPhase] = useState<VoiceTurnPhase>('idle')

  const activeSectionId = useActiveCompanionSection(companionSectionIds)
  const activeSection = useMemo(
    () => getCompanionSection(activeSectionId),
    [activeSectionId]
  )

  const sessionRef = useRef<WebCompanionSessionSnapshot | null>(null)
  const statusRef = useRef<ExperienceStatus>('idle')
  const activeSectionIdRef = useRef<string | null>(activeSectionId)
  const isReadyForVoiceRef = useRef(false)
  const isListeningRef = useRef(false)
  const isProcessingVoiceTurnRef = useRef(false)
  const speechActiveRef = useRef(false)
  const captureSessionActiveRef = useRef(false)
  const shortcutPressedRef = useRef(false)
  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const mediaRecorderChunksRef = useRef<Blob[]>([])
  const mediaStreamRef = useRef<MediaStream | null>(null)
  const audioElementRef = useRef<HTMLAudioElement | null>(null)
  const audioObjectUrlRef = useRef<string | null>(null)
  const bubbleTimeoutRef = useRef<number | null>(null)
  const sectionAnnouncementTimeoutRef = useRef<number | null>(null)
  const voiceTurnPhaseTimeoutRef = useRef<number | null>(null)
  const captureStopTimeoutRef = useRef<number | null>(null)
  const guidanceTargetSequenceRef = useRef(0)
  const highlightedTargetRef = useRef<string | null>(null)
  const visitedSectionIdsRef = useRef<string[]>([])
  const introHasRunRef = useRef(false)
  const lastAutoSpokenAtRef = useRef(0)
  const autoSpokenMessageCountRef = useRef(0)
  const announcedSectionsRef = useRef<Set<string>>(new Set())

  const drawRoundedRect = (
    context: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
    radius: number
  ) => {
    const nextRadius = Math.min(radius, width / 2, height / 2)
    context.beginPath()
    context.moveTo(x + nextRadius, y)
    context.arcTo(x + width, y, x + width, y + height, nextRadius)
    context.arcTo(x + width, y + height, x, y + height, nextRadius)
    context.arcTo(x, y + height, x, y, nextRadius)
    context.arcTo(x, y, x + width, y, nextRadius)
    context.closePath()
  }

  useEffect(() => {
    sessionRef.current = session
  }, [session])

  useEffect(() => {
    statusRef.current = status
  }, [status])

  useEffect(() => {
    activeSectionIdRef.current = activeSectionId
  }, [activeSectionId])

  useEffect(() => {
    isReadyForVoiceRef.current = isReadyForVoice
  }, [isReadyForVoice])

  useEffect(() => {
    isListeningRef.current = isListening
  }, [isListening])

  useEffect(() => {
    isProcessingVoiceTurnRef.current = isProcessingVoiceTurn
  }, [isProcessingVoiceTurn])

  useEffect(() => {
    return () => {
      if (bubbleTimeoutRef.current !== null) {
        window.clearTimeout(bubbleTimeoutRef.current)
      }

      if (sectionAnnouncementTimeoutRef.current !== null) {
        window.clearTimeout(sectionAnnouncementTimeoutRef.current)
      }

      if (voiceTurnPhaseTimeoutRef.current !== null) {
        window.clearTimeout(voiceTurnPhaseTimeoutRef.current)
      }

      if (captureStopTimeoutRef.current !== null) {
        window.clearTimeout(captureStopTimeoutRef.current)
      }

      if (audioElementRef.current) {
        audioElementRef.current.pause()
      }

      if (audioObjectUrlRef.current) {
        URL.revokeObjectURL(audioObjectUrlRef.current)
      }

      mediaRecorderRef.current?.stop()
      mediaStreamRef.current?.getTracks().forEach((track) => track.stop())
    }
  }, [])

  const hideBubble = () => {
    if (bubbleTimeoutRef.current !== null) {
      window.clearTimeout(bubbleTimeoutRef.current)
      bubbleTimeoutRef.current = null
    }

    setBubbleText(null)
  }

  const showTemporaryBubble = (text: string, delayMs = 2_400) => {
    setBubbleText(text)

    if (bubbleTimeoutRef.current !== null) {
      window.clearTimeout(bubbleTimeoutRef.current)
    }

    bubbleTimeoutRef.current = window.setTimeout(() => {
      hideBubble()
    }, delayMs)
  }

  const applyResponseBubble = (bubble: WebCompanionReply['bubble']) => {
    if (!bubble || bubble.mode !== 'brief' || !bubble.text?.trim()) {
      return
    }

    showTemporaryBubble(stripMarkdownArtifacts(bubble.text), 2_800)
  }

  const executeActions = (actions: WebCompanionAction[]) => {
    if (!actions.length) {
      return
    }

    for (const action of actions) {
      if (action.type === 'open_companion') {
        void startExperience()
        continue
      }

      if (!action.targetId) {
        continue
      }

      const element = document.getElementById(action.targetId)
      if (!element) {
        continue
      }

      if (highlightedTargetRef.current && highlightedTargetRef.current !== action.targetId) {
        document
          .getElementById(highlightedTargetRef.current)
          ?.removeAttribute('data-companion-highlight')
      }

      highlightedTargetRef.current = action.targetId
      const shouldGuideCursor = action.type === 'pulse'
      const nextGuidanceTarget = shouldGuideCursor
        ? ({
            actionType: action.type,
            id: action.targetId,
            sequence: guidanceTargetSequenceRef.current + 1,
          } satisfies CompanionGuidanceTarget)
        : null

      if (nextGuidanceTarget) {
        guidanceTargetSequenceRef.current = nextGuidanceTarget.sequence
        setGuidanceTarget(nextGuidanceTarget)
      }

      element.setAttribute(
        'data-companion-highlight',
        action.type === 'pulse' ? 'pulse' : 'true'
      )

      window.setTimeout(() => {
        const shouldClearGuidanceTarget =
          !nextGuidanceTarget ||
          guidanceTargetSequenceRef.current === nextGuidanceTarget.sequence

        if (
          highlightedTargetRef.current === action.targetId &&
          shouldClearGuidanceTarget
        ) {
          element.removeAttribute('data-companion-highlight')
          highlightedTargetRef.current = null
          if (nextGuidanceTarget) {
            setGuidanceTarget(null)
          }
        }
      }, action.type === 'pulse' ? 2900 : 2200)
    }
  }

  const showBubbleText = async (text: string) => {
    const nextText = stripMarkdownArtifacts(text)
    setBubbleText(nextText)

    if (bubbleTimeoutRef.current !== null) {
      window.clearTimeout(bubbleTimeoutRef.current)
    }

    bubbleTimeoutRef.current = window.setTimeout(() => {
      setBubbleText(null)
    }, 6_000)
  }

  const clearBubbleSoon = (delayMs: number) => {
    if (bubbleTimeoutRef.current !== null) {
      window.clearTimeout(bubbleTimeoutRef.current)
    }

    bubbleTimeoutRef.current = window.setTimeout(() => {
      setBubbleText(null)
    }, delayMs)
  }

  const playOpenClawAudio = async (
    audio:
      | {
          audioBase64: string
          fileExtension?: string
          mimeType?: string
          provider?: string
        }
      | null
      | undefined
  ) => {
    if (!audio?.audioBase64 || typeof window === 'undefined') {
      return false
    }

    try {
      if (audioElementRef.current) {
        audioElementRef.current.pause()
        audioElementRef.current = null
      }

      if (audioObjectUrlRef.current) {
        URL.revokeObjectURL(audioObjectUrlRef.current)
        audioObjectUrlRef.current = null
      }

      const binaryString = atob(audio.audioBase64)
      const bytes = Uint8Array.from(binaryString, (character) =>
        character.charCodeAt(0)
      )
      const blob = new Blob([bytes], {
        type: audio.mimeType || 'audio/mpeg',
      })
      const objectUrl = URL.createObjectURL(blob)
      audioObjectUrlRef.current = objectUrl

      await new Promise<void>((resolve, reject) => {
        const audioElement = new Audio(objectUrl)
        audioElementRef.current = audioElement
        setVoiceTurnPhase('idle')
        speechActiveRef.current = true
        setIsSpeaking(true)

        audioElement.onended = () => {
          speechActiveRef.current = false
          setIsSpeaking(false)
          resolve()
        }

        audioElement.onerror = () => {
          speechActiveRef.current = false
          setIsSpeaking(false)
          reject(new Error('Audio playback failed.'))
        }

        void audioElement.play().catch(reject)
      })

      return true
    } finally {
      if (audioObjectUrlRef.current) {
        URL.revokeObjectURL(audioObjectUrlRef.current)
        audioObjectUrlRef.current = null
      }

      audioElementRef.current = null
    }
  }

  const ensureSession = async () => {
    if (sessionRef.current) {
      return sessionRef.current
    }

    const payload = await bootstrapWebCompanionSession({
      visitorId: readStoredVisitorId(),
      path: window.location.pathname,
      currentSectionId: activeSectionId,
      referrerSource: document.referrer || undefined,
      locale: navigator.language,
    })

    writeStoredVisitorId(payload.visitorId)
    visitedSectionIdsRef.current = payload.session.visitedSectionIds
    setSession(payload.session)
    return payload.session
  }

  const buildSiteLayoutReferenceContext =
    (): WebCompanionScreenContextInput | null => {
      if (typeof document === 'undefined') {
        return null
      }

      const canvas = document.createElement('canvas')
      canvas.width = SITE_LAYOUT_CONTEXT_WIDTH
      canvas.height = SITE_LAYOUT_CONTEXT_HEIGHT
      const context = canvas.getContext('2d')
      if (!context) {
        return null
      }

      const width = canvas.width
      const height = canvas.height
      context.fillStyle = '#F6F2EC'
      context.fillRect(0, 0, width, height)

      context.fillStyle = '#1A1A1A'
      context.font = '600 42px ui-sans-serif, -apple-system, BlinkMacSystemFont, sans-serif'
      context.fillText('Clicky website layout reference', 72, 88)

      context.fillStyle = '#6E6A64'
      context.font = '24px ui-sans-serif, -apple-system, BlinkMacSystemFont, sans-serif'
      const modeLabel =
        experienceMode === 'mic-only'
          ? 'Mic is enabled. Live screen share is off, so this layout map stands in as visual context.'
          : 'This layout map stands in as visual context when live screen sharing is unavailable.'
      context.fillText(modeLabel, 72, 128)

      const frameX = 72
      const frameY = 172
      const frameWidth = width - 144
      const frameHeight = 608
      drawRoundedRect(context, frameX, frameY, frameWidth, frameHeight, 28)
      context.fillStyle = '#FFFCF8'
      context.fill()
      context.strokeStyle = 'rgba(26,26,26,0.08)'
      context.lineWidth = 2
      context.stroke()

      const pageHeight = Math.max(
        document.documentElement.scrollHeight,
        document.body.scrollHeight,
        window.innerHeight,
        1
      )

      const palette = ['#DDD4F1', '#E8D8C3', '#D6E5D6', '#F0D6DC', '#D5E3F2']
      const innerX = frameX + 36
      const innerY = frameY + 28
      const innerWidth = frameWidth - 72
      const innerHeight = frameHeight - 56

      companionSectionIds.forEach((sectionId, index) => {
        const section = getCompanionSection(sectionId)
        const element = document.getElementById(sectionId)
        const rect = element?.getBoundingClientRect()
        const absoluteTop = rect ? window.scrollY + rect.top : index * 640
        const absoluteHeight = element?.clientHeight || rect?.height || 640
        const blockY = innerY + (absoluteTop / pageHeight) * innerHeight
        const blockHeight = Math.max(
          72,
          Math.min(innerHeight * 0.24, (absoluteHeight / pageHeight) * innerHeight)
        )
        const isActiveSection = activeSectionIdRef.current === sectionId
        const isVisitedSection = visitedSectionIdsRef.current.includes(sectionId)

        drawRoundedRect(
          context,
          innerX,
          blockY,
          innerWidth,
          Math.min(blockHeight, innerY + innerHeight - blockY),
          22
        )
        context.fillStyle = palette[index % palette.length]
        context.globalAlpha = isVisitedSection ? 0.96 : 0.74
        context.fill()
        context.globalAlpha = 1

        if (isActiveSection) {
          context.strokeStyle = '#7A9BC4'
          context.lineWidth = 4
          context.stroke()
        }

        context.fillStyle = '#1A1A1A'
        context.font = '600 26px ui-sans-serif, -apple-system, BlinkMacSystemFont, sans-serif'
        context.fillText(section?.title ?? sectionId, innerX + 24, blockY + 40)

        context.fillStyle = '#5E5A55'
        context.font = '20px ui-sans-serif, -apple-system, BlinkMacSystemFont, sans-serif'
        context.fillText(
          isActiveSection
            ? 'Current focus'
            : isVisitedSection
              ? 'Visited'
              : 'Upcoming',
          innerX + 24,
          blockY + 72
        )
      })

      context.fillStyle = '#1A1A1A'
      context.font = '600 22px ui-sans-serif, -apple-system, BlinkMacSystemFont, sans-serif'
      context.fillText('Known live controls', 72, 834)

      context.fillStyle = '#6E6A64'
      context.font = '20px ui-sans-serif, -apple-system, BlinkMacSystemFont, sans-serif'
      context.fillText(
        'Hero: Download for macOS, Try Clicky. Pricing and footer also contain download CTAs.',
        72,
        870
      )

      const dataUrl = canvas.toDataURL('image/png')
      const [, contentBase64 = ''] = dataUrl.split(',', 2)
      if (!contentBase64) {
        return null
      }

      return {
        attachments: [
          {
            contentBase64,
            label: 'Clicky site layout reference',
            mimeType: 'image/png',
          },
        ],
        source: 'site-layout-reference',
      }
    }

  const captureScreenContext =
    async (): Promise<WebCompanionScreenContextInput | null> => {
      return buildSiteLayoutReferenceContext()
    }

  const dispatchEvent = async (
    input: {
      type: string
      path: string
      sectionId?: string | null
      ctaId?: string | null
      visitedSectionIds?: string[]
    },
    options?: {
      shouldSpeak?: boolean
    }
  ) => {
    logVoiceDebug('dispatch-event:start', {
      shouldSpeak: options?.shouldSpeak === true,
      type: input.type,
    })

    const currentSession = await ensureSession()
    const payload = await sendWebCompanionEvent(currentSession.id, {
      ...input,
      screenContext: await captureScreenContext(),
    })
    setSession(payload.session)

    if (payload.response) {
      setBackendMode(payload.response.provider)
      executeActions(payload.response.actions)
      applyResponseBubble(payload.response.bubble)

      if (options?.shouldSpeak === true) {
        const played = await playOpenClawAudio(payload.response.audio)
        if (!played) {
          await showBubbleText(payload.response.text)
        } else if (!payload.response.bubble || payload.response.bubble.mode !== 'brief') {
          setBubbleText(stripMarkdownArtifacts(payload.response.text))
          clearBubbleSoon(2_500)
        }
      } else {
        await showBubbleText(payload.response.text)
      }
    }

    logVoiceDebug('dispatch-event:done', {
      hasAudio: Boolean(payload.response?.audio?.audioBase64),
      type: input.type,
    })
  }

  const dispatchVoiceMessage = async (transcript: string) => {
    logVoiceDebug('voice-message:start', {
      transcriptLength: transcript.length,
    })
    setVoiceTurnPhase('thinking')

    const currentSession = await ensureSession()
    const payload = await sendWebCompanionMessage(currentSession.id, {
      message: transcript,
      path: window.location.pathname,
      sectionId: activeSectionIdRef.current,
      screenContext: await captureScreenContext(),
      visitedSectionIds: visitedSectionIdsRef.current,
    })

    setSession(payload.session)

    if (payload.response) {
      setBackendMode(payload.response.provider)
      executeActions(payload.response.actions)
      applyResponseBubble(payload.response.bubble)
      const played = await playOpenClawAudio(payload.response.audio)
      if (!played) {
        setVoiceTurnPhase('idle')
        await showBubbleText(payload.response.text)
      } else if (!payload.response.bubble || payload.response.bubble.mode !== 'brief') {
        setBubbleText(stripMarkdownArtifacts(payload.response.text))
        clearBubbleSoon(2_500)
      }
    }

    logVoiceDebug('voice-message:done', {
      hasAudio: Boolean(payload.response?.audio?.audioBase64),
    })
  }

  const ensureMicrophoneStream = async () => {
    if (
      typeof navigator === 'undefined' ||
      !navigator.mediaDevices ||
      !navigator.mediaDevices.getUserMedia
    ) {
      throw new Error('Microphone access is not supported in this browser.')
    }

    if (mediaStreamRef.current) {
      return mediaStreamRef.current
    }

    mediaStreamRef.current = await navigator.mediaDevices.getUserMedia({
      audio: {
        channelCount: 1,
        echoCancellation: true,
        noiseSuppression: true,
      },
    })

    return mediaStreamRef.current
  }

  const requestMicPermission = async () => {
    const stream = await ensureMicrophoneStream()
    if (!stream.getAudioTracks().length) {
      throw new Error('No microphone track is available.')
    }
  }

  const dispatchRecordedAudio = async (audioBlob: Blob) => {
    const currentSession = await ensureSession()
    setVoiceTurnPhase('transcribing')
    hideBubble()

    logVoiceDebug('transcribe:start', {
      mimeType: audioBlob.type,
      sizeBytes: audioBlob.size,
    })

    const transcription = await transcribeWebCompanionAudio(currentSession.id, {
      audioBlob,
      filename: `clicky-web-${Date.now()}.webm`,
    })

    const transcript = transcription.transcript.trim()

    logVoiceDebug('transcribe:done', {
      transcriptLength: transcript.length,
    })

    if (!transcript) {
      setVoiceTurnPhase('idle')
      showTemporaryBubble('Try that again', 2_400)
      return
    }

    setIsProcessingVoiceTurn(true)
    setVoiceTurnPhase('transcribing')

    if (voiceTurnPhaseTimeoutRef.current !== null) {
      window.clearTimeout(voiceTurnPhaseTimeoutRef.current)
    }

    voiceTurnPhaseTimeoutRef.current = window.setTimeout(() => {
      void dispatchVoiceMessage(transcript)
        .catch((error) => {
          setVoiceTurnPhase('idle')
          setErrorMessage(
            error instanceof Error
              ? error.message
              : 'Clicky could not send the voice message.'
          )
          showTemporaryBubble('Could not send that', 2_600)
        })
        .finally(() => {
          setIsProcessingVoiceTurn(false)
        })
    }, 260)
  }

  const ensureRecorder = async () => {
    if (typeof MediaRecorder === 'undefined') {
      throw new Error('MediaRecorder is not supported in this browser.')
    }

    const stream = await ensureMicrophoneStream()
    const mimeType = getSupportedRecordingMimeType()
    const recorder = mimeType
      ? new MediaRecorder(stream, { mimeType })
      : new MediaRecorder(stream)

    recorder.ondataavailable = (event) => {
      if (event.data.size > 0) {
        mediaRecorderChunksRef.current.push(event.data)
      }
    }

    recorder.onerror = (event) => {
      captureSessionActiveRef.current = false
      setIsListening(false)
      setVoiceTurnPhase('idle')
      setErrorMessage(
        event.error?.message || 'Voice recording failed while capturing audio.'
      )
      logVoiceDebug('recorder:error', {
        message: event.error?.message ?? 'unknown',
      })
      showTemporaryBubble('Voice input failed', 2_400)
    }

    recorder.onstop = () => {
      const audioBlob = new Blob(mediaRecorderChunksRef.current, {
        type: mediaRecorderChunksRef.current[0]?.type || recorder.mimeType || 'audio/webm',
      })
      mediaRecorderChunksRef.current = []
      captureSessionActiveRef.current = false
      setIsListening(false)

      logVoiceDebug('recorder:stop', {
        mimeType: audioBlob.type,
        sizeBytes: audioBlob.size,
      })

      if (audioBlob.size < 1024) {
        setVoiceTurnPhase('idle')
        showTemporaryBubble('Try that again', 2_400)
        return
      }

      void dispatchRecordedAudio(audioBlob).catch((error) => {
        setVoiceTurnPhase('idle')
        setErrorMessage(
          error instanceof Error
            ? error.message
            : 'Audio transcription failed.'
        )
        showTemporaryBubble('Voice input failed', 2_400)
      })
    }

    mediaRecorderRef.current = recorder
    return recorder
  }

  const startListening = () => {
    if (
      !isReadyForVoiceRef.current ||
      isListeningRef.current ||
      isProcessingVoiceTurnRef.current ||
      speechActiveRef.current ||
      captureSessionActiveRef.current
    ) {
      logVoiceDebug('capture:start-blocked', {
        isListening: isListeningRef.current,
        isProcessing: isProcessingVoiceTurnRef.current,
        isReady: isReadyForVoiceRef.current,
        recordingActive: captureSessionActiveRef.current,
        speechActive: speechActiveRef.current,
      })

      if (!isReadyForVoiceRef.current) {
        showTemporaryBubble('Getting ready', 1_800)
      }
      return
    }

    if (captureStopTimeoutRef.current !== null) {
      window.clearTimeout(captureStopTimeoutRef.current)
      captureStopTimeoutRef.current = null
    }

    mediaRecorderChunksRef.current = []
    setErrorMessage(null)
    setIsListening(true)
    setVoiceTurnPhase('idle')
    hideBubble()

    if (bubbleTimeoutRef.current !== null) {
      window.clearTimeout(bubbleTimeoutRef.current)
      bubbleTimeoutRef.current = null
    }

    if (voiceTurnPhaseTimeoutRef.current !== null) {
      window.clearTimeout(voiceTurnPhaseTimeoutRef.current)
      voiceTurnPhaseTimeoutRef.current = null
    }

    void ensureRecorder()
      .then((recorder) => {
        captureSessionActiveRef.current = true
        recorder.start()
        logVoiceDebug('recorder:start', {
          mimeType: recorder.mimeType,
        })
      })
      .catch((error) => {
        captureSessionActiveRef.current = false
        setIsListening(false)
        setVoiceTurnPhase('idle')
        setErrorMessage(
          error instanceof Error
            ? error.message
            : 'Voice demo could not start listening.'
        )
        logVoiceDebug('recorder:start-failed', {
          message: error instanceof Error ? error.message : String(error),
        })
      })
  }

  const stopListening = () => {
    if (!captureSessionActiveRef.current) {
      return
    }

    logVoiceDebug('recorder:stop-requested', {})
    mediaRecorderRef.current?.stop()
  }

  const startExperience = async (options?: {
    mode?: StartExperienceMode
  }) => {
    if (status === 'requesting-permission') {
      return
    }

    const requestedMode = options?.mode ?? 'full'

    try {
      setStatus('requesting-permission')
      setErrorMessage(null)
      setIsReadyForVoice(false)

      if (requestedMode === 'demo-only') {
        setExperienceMode('demo-only')
        setStatus('idle')
        return
      }

      await requestMicPermission()
      await ensureSession()
      setExperienceMode('mic-only')
      setStatus('active')
      await dispatchEvent(
        {
          type: 'experience_activated',
          path: window.location.pathname,
          sectionId: activeSectionId,
          visitedSectionIds: visitedSectionIdsRef.current,
        },
        {
          shouldSpeak: true,
        }
      )
      setIsReadyForVoice(true)
      logVoiceDebug('experience:ready', {})

      if (!introHasRunRef.current) {
        introHasRunRef.current = true
        autoSpokenMessageCountRef.current += 1
        lastAutoSpokenAtRef.current = Date.now()
      }
    } catch (error) {
      setExperienceMode('demo-only')
      setStatus('idle')
      setErrorMessage(
        error instanceof Error
          ? `${error.message} You can still watch the demo below and enable live permissions later.`
          : 'Clicky could not start the guided experience. You can still watch the demo below.'
      )
    }
  }

  useEffect(() => {
    if (activeSectionId && !visitedSectionIdsRef.current.includes(activeSectionId)) {
      visitedSectionIdsRef.current = [...visitedSectionIdsRef.current, activeSectionId]
    }
  }, [activeSectionId])

  useEffect(() => {
    if (!isReadyForVoice || status !== 'active' || !activeSectionId || !activeSection) {
      return
    }

    if (isListening || isProcessingVoiceTurn || isSpeaking) {
      return
    }

    if (announcedSectionsRef.current.has(activeSectionId)) {
      return
    }

    if (autoSpokenMessageCountRef.current >= MAX_AUTOMATED_SPOKEN_MESSAGES) {
      return
    }

    if (Date.now() - lastAutoSpokenAtRef.current < MIN_SPEECH_GAP_MS) {
      return
    }

    if (sectionAnnouncementTimeoutRef.current !== null) {
      window.clearTimeout(sectionAnnouncementTimeoutRef.current)
    }

    sectionAnnouncementTimeoutRef.current = window.setTimeout(() => {
      if (statusRef.current !== 'active') {
        return
      }

      announcedSectionsRef.current.add(activeSectionId)
      autoSpokenMessageCountRef.current += 1
      lastAutoSpokenAtRef.current = Date.now()

      void dispatchEvent(
        {
          type: 'section_entered',
          path: window.location.pathname,
          sectionId: activeSectionId,
          visitedSectionIds: visitedSectionIdsRef.current,
        },
        {
          shouldSpeak: true,
        }
      ).catch((error) => {
        setErrorMessage(
          error instanceof Error
            ? error.message
            : 'Clicky could not react to this section.'
        )
      })
    }, SECTION_SETTLE_DELAY_MS)

    return () => {
      if (sectionAnnouncementTimeoutRef.current !== null) {
        window.clearTimeout(sectionAnnouncementTimeoutRef.current)
        sectionAnnouncementTimeoutRef.current = null
      }
    }
  }, [activeSection, activeSectionId, isListening, isProcessingVoiceTurn, isReadyForVoice, isSpeaking, status])

  useEffect(() => {
    if (status !== 'active') {
      return undefined
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.ctrlKey && event.altKey && !shortcutPressedRef.current) {
        shortcutPressedRef.current = true
        logVoiceDebug('shortcut:keydown', {
          key: event.key,
        })
        startListening()
      }
    }

    const handleKeyUp = (event: KeyboardEvent) => {
      if ((!event.ctrlKey || !event.altKey) && shortcutPressedRef.current) {
        shortcutPressedRef.current = false
        logVoiceDebug('shortcut:keyup', {
          key: event.key,
        })
        if (captureStopTimeoutRef.current !== null) {
          window.clearTimeout(captureStopTimeoutRef.current)
        }

        captureStopTimeoutRef.current = window.setTimeout(() => {
          stopListening()
        }, SHORTCUT_RELEASE_GRACE_MS)
      }
    }

    const handleBlur = () => {
      shortcutPressedRef.current = false
      if (captureStopTimeoutRef.current !== null) {
        window.clearTimeout(captureStopTimeoutRef.current)
      }
      stopListening()
    }

    window.addEventListener('keydown', handleKeyDown)
    window.addEventListener('keyup', handleKeyUp)
    window.addEventListener('blur', handleBlur)

    return () => {
      window.removeEventListener('keydown', handleKeyDown)
      window.removeEventListener('keyup', handleKeyUp)
      window.removeEventListener('blur', handleBlur)
    }
  }, [status])

  const companionVisualState = useMemo<CompanionVisualState>(() => {
    if (status !== 'active') {
      return 'idle'
    }

    if (isListening) {
      return 'listening'
    }

    if (voiceTurnPhase === 'transcribing') {
      return 'transcribing'
    }

    if (voiceTurnPhase === 'thinking' || isProcessingVoiceTurn) {
      return 'thinking'
    }

    return 'idle'
  }, [isListening, isProcessingVoiceTurn, status, voiceTurnPhase])

  const value = useMemo<WebCompanionExperienceValue>(
    () => ({
      backendMode,
      bubbleText,
      companionVisualState,
      currentSectionId: activeSectionId,
      experienceMode,
      errorMessage,
      guidanceTarget,
      isListening,
      isSpeaking,
      startExperience,
      status,
    }),
    [
      activeSectionId,
      backendMode,
      bubbleText,
      companionVisualState,
      experienceMode,
      errorMessage,
      guidanceTarget,
      isListening,
      isSpeaking,
      status,
    ]
  )

  return (
    <WebCompanionExperienceContext.Provider value={value}>
      {children}
    </WebCompanionExperienceContext.Provider>
  )
}
