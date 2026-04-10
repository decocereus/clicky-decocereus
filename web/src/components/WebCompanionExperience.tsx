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
  type WebCompanionSessionSnapshot,
  sendWebCompanionEvent,
  sendWebCompanionMessage,
} from '../lib/webCompanion'

const VISITOR_STORAGE_KEY = 'clicky:web-companion:visitor:v1'
const MAX_AUTOMATED_SPOKEN_MESSAGES = 4
const MIN_SPEECH_GAP_MS = 12_000
const SECTION_SETTLE_DELAY_MS = 1_600

interface BrowserSpeechRecognitionAlternative {
  transcript: string
}

interface BrowserSpeechRecognitionResult {
  0: BrowserSpeechRecognitionAlternative
  isFinal: boolean
  length: number
}

interface BrowserSpeechRecognitionEvent {
  resultIndex: number
  results: ArrayLike<BrowserSpeechRecognitionResult>
}

interface BrowserSpeechRecognition {
  continuous: boolean
  interimResults: boolean
  lang: string
  onend: (() => void) | null
  onerror: ((event: { error?: string }) => void) | null
  onresult: ((event: BrowserSpeechRecognitionEvent) => void) | null
  start: () => void
  stop: () => void
}

interface BrowserSpeechRecognitionConstructor {
  new (): BrowserSpeechRecognition
}

declare global {
  interface Window {
    __clickyVoiceDebugLog?: Array<Record<string, unknown>>
    SpeechRecognition?: BrowserSpeechRecognitionConstructor
    webkitSpeechRecognition?: BrowserSpeechRecognitionConstructor
  }
}

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

interface WebCompanionExperienceValue {
  backendMode: BackendMode
  bubbleText: string | null
  companionVisualState: CompanionVisualState
  currentSectionId: string | null
  errorMessage: string | null
  guidanceTarget: CompanionGuidanceTarget | null
  isListening: boolean
  isSpeaking: boolean
  status: ExperienceStatus
  startExperience: () => Promise<void>
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

function getSpeechRecognitionConstructor() {
  if (typeof window === 'undefined') {
    return null
  }

  return window.SpeechRecognition ?? window.webkitSpeechRecognition ?? null
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

export function useWebCompanionExperience() {
  const context = useContext(WebCompanionExperienceContext)
  if (!context) {
    throw new Error(
      'useWebCompanionExperience must be used within WebCompanionExperienceProvider.'
    )
  }

  return context
}

function useOptionalWebCompanionExperience() {
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
  const sessionRef = useRef<WebCompanionSessionSnapshot | null>(null)
  const statusRef = useRef<ExperienceStatus>('idle')
  const visitedSectionIdsRef = useRef<string[]>([])
  const introHasRunRef = useRef(false)
  const lastAutoSpokenAtRef = useRef(0)
  const autoSpokenMessageCountRef = useRef(0)
  const announcedSectionsRef = useRef<Set<string>>(new Set())
  const bubbleTimeoutRef = useRef<number | null>(null)
  const sectionAnnouncementTimeoutRef = useRef<number | null>(null)
  const guidanceTargetSequenceRef = useRef(0)
  const highlightedTargetRef = useRef<string | null>(null)
  const voiceTurnPhaseTimeoutRef = useRef<number | null>(null)
  const recognitionStopTimeoutRef = useRef<number | null>(null)
  const audioElementRef = useRef<HTMLAudioElement | null>(null)
  const audioObjectUrlRef = useRef<string | null>(null)
  const isListeningRef = useRef(false)
  const isReadyForVoiceRef = useRef(false)
  const isProcessingVoiceTurnRef = useRef(false)
  const recognitionSessionActiveRef = useRef(false)
  const recognitionStopRequestedRef = useRef(false)
  const shortcutPressedRef = useRef(false)
  const recognitionRef = useRef<BrowserSpeechRecognition | null>(null)
  const speechActiveRef = useRef(false)
  const transcriptDraftRef = useRef('')
  const interimTranscriptRef = useRef('')
  const activeSectionIdRef = useRef<string | null>(activeSectionId)

  const activeSection = useMemo(
    () => getCompanionSection(activeSectionId),
    [activeSectionId]
  )

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
    isListeningRef.current = isListening
  }, [isListening])

  useEffect(() => {
    isReadyForVoiceRef.current = isReadyForVoice
  }, [isReadyForVoice])

  useEffect(() => {
    isReadyForVoiceRef.current = isReadyForVoice
  }, [isReadyForVoice])

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

      if (recognitionStopTimeoutRef.current !== null) {
        window.clearTimeout(recognitionStopTimeoutRef.current)
      }

      if (audioElementRef.current) {
        audioElementRef.current.pause()
      }

      if (audioObjectUrlRef.current) {
        URL.revokeObjectURL(audioObjectUrlRef.current)
      }

      recognitionRef.current?.stop()
    }
  }, [])

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
      }, action.type === 'pulse' ? 1600 : 2200)

      // Website companion guidance should never auto-scroll the page.
      // Highlighting is allowed; navigation stays user-driven.
    }
  }

  const hideBubble = () => {
    if (bubbleTimeoutRef.current !== null) {
      window.clearTimeout(bubbleTimeoutRef.current)
      bubbleTimeoutRef.current = null
    }

    setBubbleText(null)
  }

  const showTemporaryBubble = (text: string, delayMs = 2_400) => {
    const nextText = stripMarkdownArtifacts(text).slice(0, 72)
    if (!nextText) {
      hideBubble()
      return
    }

    setBubbleText(nextText)

    if (bubbleTimeoutRef.current !== null) {
      window.clearTimeout(bubbleTimeoutRef.current)
    }

    bubbleTimeoutRef.current = window.setTimeout(() => {
      setBubbleText(null)
      bubbleTimeoutRef.current = null
    }, delayMs)
  }

  const applyResponseBubble = (bubble: WebCompanionReply['bubble']) => {
    if (!bubble || bubble.mode !== 'brief') {
      hideBubble()
      return
    }

    showTemporaryBubble(bubble.text ?? '', 2_800)
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
    const payload = await sendWebCompanionEvent(currentSession.id, input)
    setSession(payload.session)

    if (payload.response) {
      setBackendMode(payload.response.provider)
      executeActions(payload.response.actions)
      applyResponseBubble(payload.response.bubble)
      if (options?.shouldSpeak === true) {
        await playOpenClawAudio(payload.response.audio)
      } else if (!payload.response.bubble || payload.response.bubble.mode === 'hidden') {
        hideBubble()
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
    hideBubble()

    const currentSession = await ensureSession()
    const payload = await sendWebCompanionMessage(currentSession.id, {
      message: transcript,
      path: window.location.pathname,
      sectionId: activeSectionIdRef.current,
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
        if (!payload.response.bubble || payload.response.bubble.mode === 'hidden') {
          hideBubble()
        }
      }
    }
    logVoiceDebug('voice-message:done', {
      hasAudio: Boolean(payload.response?.audio?.audioBase64),
    })
  }

  const requestMicPermission = async () => {
    if (
      typeof navigator === 'undefined' ||
      !navigator.mediaDevices ||
      !navigator.mediaDevices.getUserMedia
    ) {
      throw new Error('Microphone access is not supported in this browser.')
    }

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    for (const track of stream.getTracks()) {
      track.stop()
    }
  }

  const ensureRecognition = () => {
    if (recognitionRef.current) {
      return recognitionRef.current
    }

    const RecognitionConstructor = getSpeechRecognitionConstructor()
    if (!RecognitionConstructor) {
      throw new Error(
        'Push-to-talk needs browser speech recognition support. Try Chrome or Safari for this demo.'
      )
    }

    const recognition = new RecognitionConstructor()
    recognition.continuous = false
    recognition.interimResults = true
    recognition.lang = navigator.language || 'en-US'

    recognition.onresult = (event) => {
      let finalTranscript = ''
      let interimTranscript = ''

      for (let index = event.resultIndex; index < event.results.length; index += 1) {
        const result = event.results[index]
        const transcript = result[0]?.transcript?.trim() ?? ''

        if (!transcript) {
          continue
        }

        if (result.isFinal) {
          finalTranscript = `${finalTranscript} ${transcript}`.trim()
        } else {
          interimTranscript = `${interimTranscript} ${transcript}`.trim()
        }
      }

      if (finalTranscript) {
        transcriptDraftRef.current = finalTranscript
      }

      if (interimTranscript) {
        interimTranscriptRef.current = interimTranscript
      }

      logVoiceDebug('recognition:result', {
        finalTranscriptLength: finalTranscript.length,
        interimTranscriptLength: interimTranscript.length,
      })
    }

    recognition.onerror = (event) => {
      recognitionSessionActiveRef.current = false
      setIsListening(false)
      setVoiceTurnPhase('idle')

      const hasTranscript =
        transcriptDraftRef.current.trim().length > 0 ||
        interimTranscriptRef.current.trim().length > 0
      const wasManualStop = recognitionStopRequestedRef.current

      if (event.error === 'network' && (wasManualStop || hasTranscript)) {
        logVoiceDebug('recognition:error-ignored', {
          error: event.error,
          hasTranscript,
          wasManualStop,
        })
        return
      }

      logVoiceDebug('recognition:error', {
        error: event.error ?? 'unknown',
        hasTranscript,
        wasManualStop,
      })
      setErrorMessage(
        event.error
          ? `Voice demo error: ${event.error}.`
          : 'Voice demo error while listening.'
      )
      showTemporaryBubble('Voice input failed', 2_400)
    }

    recognition.onend = () => {
      recognitionSessionActiveRef.current = false
      setIsListening(false)
      recognitionStopRequestedRef.current = false

      const transcript =
        transcriptDraftRef.current.trim() || interimTranscriptRef.current.trim()
      transcriptDraftRef.current = ''
      interimTranscriptRef.current = ''

      if (!transcript) {
        setVoiceTurnPhase('idle')
        logVoiceDebug('recognition:end-empty', {})
        if (statusRef.current === 'active') {
          showTemporaryBubble('Try that again', 2_400)
        }
        return
      }

      setIsProcessingVoiceTurn(true)
      setVoiceTurnPhase('transcribing')
      hideBubble()
      logVoiceDebug('recognition:end-transcript', {
        transcriptLength: transcript.length,
      })

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

    recognitionRef.current = recognition
    return recognition
  }

  const startListening = () => {
    if (
      !isReadyForVoiceRef.current ||
      isListeningRef.current ||
      isProcessingVoiceTurnRef.current ||
      speechActiveRef.current ||
      recognitionSessionActiveRef.current
    ) {
      logVoiceDebug('recognition:start-blocked', {
        isListening: isListeningRef.current,
        isProcessing: isProcessingVoiceTurnRef.current,
        isReady: isReadyForVoiceRef.current,
        recognitionActive: recognitionSessionActiveRef.current,
        speechActive: speechActiveRef.current,
      })
      if (!isReadyForVoiceRef.current) {
        showTemporaryBubble('Getting ready', 1_800)
      }
      return
    }

    if (recognitionStopTimeoutRef.current !== null) {
      window.clearTimeout(recognitionStopTimeoutRef.current)
      recognitionStopTimeoutRef.current = null
    }

    const recognition = ensureRecognition()

    transcriptDraftRef.current = ''
    interimTranscriptRef.current = ''
    recognitionStopRequestedRef.current = false
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

    try {
      recognitionSessionActiveRef.current = true
      recognition.start()
      logVoiceDebug('recognition:start', {})
    } catch (error) {
      recognitionSessionActiveRef.current = false
      setIsListening(false)
      setVoiceTurnPhase('idle')
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Voice demo could not start listening.'
      )
      logVoiceDebug('recognition:start-failed', {
        message: error instanceof Error ? error.message : String(error),
      })
    }
  }

  const stopListening = () => {
    if (!recognitionSessionActiveRef.current) {
      return
    }

    recognitionStopRequestedRef.current = true
    logVoiceDebug('recognition:stop-requested', {})
    recognitionRef.current?.stop()
  }

  const startExperience = async () => {
    if (status === 'requesting-permission' || status === 'active') {
      return
    }

    try {
      setStatus('requesting-permission')
      setErrorMessage(null)
      setIsReadyForVoice(false)
      ensureRecognition()
      await requestMicPermission()
      await ensureSession()
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
      setStatus('error')
      setErrorMessage(
        error instanceof Error
          ? error.message
          : 'Clicky could not start the guided experience.'
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
      if (status !== 'active') {
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
        if (recognitionStopTimeoutRef.current !== null) {
          window.clearTimeout(recognitionStopTimeoutRef.current)
        }

        recognitionStopTimeoutRef.current = window.setTimeout(() => {
          stopListening()
        }, 260)
      }
    }

    const handleBlur = () => {
      shortcutPressedRef.current = false
      if (recognitionStopTimeoutRef.current !== null) {
        window.clearTimeout(recognitionStopTimeoutRef.current)
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

    if (isSpeaking) {
      return 'responding'
    }

    if (voiceTurnPhase === 'transcribing') {
      return 'transcribing'
    }

    if (voiceTurnPhase === 'thinking' || isProcessingVoiceTurn) {
      return 'thinking'
    }

    return 'idle'
  }, [isListening, isProcessingVoiceTurn, isSpeaking, status, voiceTurnPhase])

  const value = useMemo<WebCompanionExperienceValue>(
    () => ({
      backendMode,
      bubbleText,
      companionVisualState,
      currentSectionId: activeSectionId,
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

export function useOptionalCursorCompanionExperience() {
  return useOptionalWebCompanionExperience()
}
