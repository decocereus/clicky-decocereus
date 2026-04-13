import { useEffect, useMemo, useRef, useState } from 'react'
import { createPortal } from 'react-dom'

import {
  getCompanionTargetDefinition,
  resolveCompanionTargetGeometry,
  type CompanionBubblePlacement,
} from '../content/companionTargetRegistry'
import { useOptionalCursorCompanionExperience } from './WebCompanionExperience'
import { type Position, SmoothFollower } from './ui/smooth-cursor'

type CompanionRenderState =
  | 'idle'
  | 'listening'
  | 'transcribing'
  | 'thinking'
  | 'responding'
type NavigationPhase = 'following' | 'navigating' | 'pointing' | 'returning'
type BubblePlacement = CompanionBubblePlacement

const FOLLOW_OFFSET = {
  x: 35,
  y: 25,
}
const RETURN_SETTLE_MS = 620

const LISTENING_BAR_HEIGHTS = [6, 10, 14, 10, 6]
const RESPONDING_BAR_HEIGHTS = [7, 11, 15, 11, 7]

declare global {
  interface Window {
    __clickyGuidanceDebugEnabled?: boolean
    __clickyGuidanceDebugLog?: Array<Record<string, unknown>>
    __clickyGuidanceLastResolved?: Record<string, unknown>
  }
}

function logGuidanceDebug(
  event: string,
  details: Record<string, unknown> = {}
) {
  const payload = {
    details,
    event,
    ts: new Date().toISOString(),
  }

  if (typeof window !== 'undefined') {
    const log = window.__clickyGuidanceDebugLog ?? []
    log.push(payload)
    window.__clickyGuidanceDebugLog = log.slice(-150)
  }

  console.debug('[clicky-guidance]', event, details)
}

function TriangleGlyph({ color }: { color: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width="18"
      height="18"
      style={{ transform: 'rotate(-35deg)' }}
    >
      <path d="M12 2L22 20H2L12 2Z" fill={color} />
    </svg>
  )
}

function ListeningGlyph({ color }: { color: string }) {
  return (
    <div className="flex items-center gap-[2px]">
      {LISTENING_BAR_HEIGHTS.map((height, index) => (
        <span
          key={`listen-${height}-${index}`}
          className="companion-listen-bar block w-[2.5px] rounded-full"
          style={{
            height,
            backgroundColor: color,
            animationDelay: `${index * 90}ms`,
          }}
        />
      ))}
    </div>
  )
}

function TranscribingGlyph({ color }: { color: string }) {
  return (
    <span
      className="companion-spinner-ring block h-[14px] w-[14px] rounded-full"
      style={{
        borderColor: `${color}33`,
        borderTopColor: color,
      }}
    />
  )
}

function ThinkingGlyph({ color }: { color: string }) {
  return (
    <div className="flex items-center gap-[3px]">
      {Array.from({ length: 3 }).map((_, index) => (
        <span
          key={`processing-${index}`}
          className="companion-processing-dot block h-[4px] w-[4px] rounded-full"
          style={{
            backgroundColor: color,
            animationDelay: `${index * 120}ms`,
          }}
        />
      ))}
    </div>
  )
}

function RespondingGlyph({ color }: { color: string }) {
  return (
    <div className="flex items-center gap-[2px]">
      {RESPONDING_BAR_HEIGHTS.map((height, index) => (
        <span
          key={`speak-${height}-${index}`}
          className="companion-speak-bar block w-[2.5px] rounded-full"
          style={{
            height,
            backgroundColor: color,
            animationDelay: `${index * 80}ms`,
          }}
        />
      ))}
    </div>
  )
}

function CompanionGlyph({
  color,
  state,
}: {
  color: string
  state: CompanionRenderState
}) {
  switch (state) {
    case 'listening':
      return <ListeningGlyph color={color} />
    case 'transcribing':
      return <TranscribingGlyph color={color} />
    case 'thinking':
      return <ThinkingGlyph color={color} />
    case 'responding':
      return <RespondingGlyph color={color} />
    case 'idle':
    default:
      return <TriangleGlyph color={color} />
  }
}

export function CursorCompanion() {
  const companionExperience = useOptionalCursorCompanionExperience()
  const [isMounted] = useState(() => typeof window !== 'undefined')
  const [isVisible, setIsVisible] = useState(false)
  const [bubblePlacement, setBubblePlacement] =
    useState<BubblePlacement>('right-below')
  const [debugTargetGeometry, setDebugTargetGeometry] = useState<{
    elementRect: { height: number; left: number; top: number; width: number }
    position: Position
    targetPoint: Position
  } | null>(null)
  const [manualTargetPosition, setManualTargetPosition] = useState<Position | null>(
    null
  )
  const [navigationPhase, setNavigationPhase] =
    useState<NavigationPhase>('following')
  const pointerPositionRef = useRef<Position>({ x: 0, y: 0 })

  const companionStatus = companionExperience?.status ?? 'idle'
  const companionVisualState =
    companionExperience?.companionVisualState ?? 'idle'
  const bubbleText = companionExperience?.bubbleText ?? null
  const guidanceTarget = companionExperience?.guidanceTarget ?? null
  const isActive = companionStatus === 'active'
  const isGuidanceDebugEnabled =
    typeof window !== 'undefined' &&
    (window.__clickyGuidanceDebugEnabled === true ||
      window.localStorage.getItem('clicky-guidance-debug') === 'true')

  useEffect(() => {
    if (typeof window !== 'undefined') {
      pointerPositionRef.current = {
        x: window.innerWidth / 2,
        y: window.innerHeight / 2,
      }
    }
  }, [])

  useEffect(() => {
    if (!isMounted) {
      return undefined
    }

    const timer = window.setTimeout(() => {
      setIsVisible(true)
    }, 600)

    return () => {
      window.clearTimeout(timer)
    }
  }, [isMounted])

  const shellColors = useMemo(() => {
    if (!isActive) {
      return {
        core: '#92A4BE',
        outerGlow: 'rgba(146, 164, 190, 0.22)',
        innerGlow: 'rgba(146, 164, 190, 0.14)',
        ring: 'rgba(146, 164, 190, 0.3)',
      }
    }

    switch (companionVisualState) {
      case 'listening':
        return {
          core: '#7A9BC4',
          outerGlow: 'rgba(122, 155, 196, 0.74)',
          innerGlow: 'rgba(122, 155, 196, 0.5)',
          ring: 'rgba(122, 155, 196, 0.52)',
        }
      case 'transcribing':
        return {
          core: '#88A3CB',
          outerGlow: 'rgba(136, 163, 203, 0.68)',
          innerGlow: 'rgba(136, 163, 203, 0.42)',
          ring: 'rgba(136, 163, 203, 0.5)',
        }
      case 'thinking':
        return {
          core: '#8F96BC',
          outerGlow: 'rgba(143, 150, 188, 0.62)',
          innerGlow: 'rgba(143, 150, 188, 0.38)',
          ring: 'rgba(143, 150, 188, 0.48)',
        }
      case 'responding':
        return {
          core: '#6E8CC4',
          outerGlow: 'rgba(110, 140, 196, 0.78)',
          innerGlow: 'rgba(110, 140, 196, 0.52)',
          ring: 'rgba(110, 140, 196, 0.56)',
        }
      case 'idle':
      default:
        return {
          core: '#7A9BC4',
          outerGlow: 'rgba(122, 155, 196, 0.44)',
          innerGlow: 'rgba(122, 155, 196, 0.28)',
          ring: 'rgba(122, 155, 196, 0.4)',
        }
    }
  }, [companionVisualState, isActive])

  const shellScale = useMemo(() => {
    if (navigationPhase === 'navigating') {
      return 1.13
    }

    if (navigationPhase === 'returning') {
      return 1.03
    }

    switch (companionVisualState) {
      case 'listening':
        return 1.08
      case 'transcribing':
        return 1.06
      case 'thinking':
        return 1.04
      case 'responding':
        return 1.12
      case 'idle':
      default:
        return 1
    }
  }, [companionVisualState, navigationPhase])

  const bubblePositionStyles = useMemo(() => {
    switch (bubblePlacement) {
      case 'left-above':
        return {
          bottom: '18px',
          right: 'calc(100% - 10px)',
        }
      case 'left-below':
        return {
          right: 'calc(100% - 10px)',
          top: '18px',
        }
      case 'right-above':
        return {
          bottom: '18px',
          left: '10px',
        }
      case 'right-below':
      default:
        return {
          left: '10px',
          top: '18px',
        }
    }
  }, [bubblePlacement])

  const shouldShowBubble =
    Boolean(bubbleText) &&
    navigationPhase !== 'navigating' &&
    navigationPhase !== 'returning' &&
    companionVisualState !== 'thinking' &&
    companionVisualState !== 'transcribing'
  const effectiveDebugTargetGeometry = guidanceTarget ? debugTargetGeometry : null
  const effectiveNavigationPhase = guidanceTarget ? navigationPhase : 'following'
  const effectiveManualTargetPosition = guidanceTarget ? manualTargetPosition : null
  const followerTargetPosition =
    effectiveNavigationPhase === 'following' ? null : effectiveManualTargetPosition
  const followerRotationMode = 'none'

  useEffect(() => {
    if (!guidanceTarget || !isMounted) {
      return
    }

    const initialGeometry = resolveCompanionTargetGeometry(guidanceTarget.id)
    if (!initialGeometry) {
      logGuidanceDebug('guidance:geometry-missing', {
        actionType: guidanceTarget.actionType,
        targetId: guidanceTarget.id,
      })
      return
    }

    const descriptor = getCompanionTargetDefinition(guidanceTarget.id)

    pointerPositionRef.current = {
      x: Math.max(pointerPositionRef.current.x, 0),
      y: Math.max(pointerPositionRef.current.y, 0),
    }

    const travelDistance = Math.hypot(
      initialGeometry.position.x - pointerPositionRef.current.x,
      initialGeometry.position.y - pointerPositionRef.current.y
    )
    const navigationDurationMs = Math.min(
      Math.max(380 + travelDistance * 0.24, 460),
      840
    )
    const pointingHoldMs =
      guidanceTarget.actionType === 'pulse' ? 1100 : 1550

    let navigationTimer: number | null = null
    let returnTimer: number | null = null
    let resumeTimer: number | null = null

    logGuidanceDebug('guidance:start', {
      actionType: guidanceTarget.actionType,
      anchor: initialGeometry.anchor,
      bubblePlacement: initialGeometry.placement,
      cursorOffset: initialGeometry.cursorOffset,
      elementRect: initialGeometry.elementRect,
      label: descriptor?.label ?? initialGeometry.label ?? guidanceTarget.id,
      pointerPosition: pointerPositionRef.current,
      resolvedPosition: initialGeometry.position,
      sectionId: initialGeometry.sectionId,
      targetId: guidanceTarget.id,
      targetPoint: initialGeometry.targetPoint,
      travelDistance,
    })
    window.__clickyGuidanceLastResolved = {
      actionType: guidanceTarget.actionType,
      anchor: initialGeometry.anchor,
      bubblePlacement: initialGeometry.placement,
      cursorOffset: initialGeometry.cursorOffset,
      elementRect: initialGeometry.elementRect,
      label: descriptor?.label ?? initialGeometry.label ?? guidanceTarget.id,
      pointerPosition: pointerPositionRef.current,
      resolvedPosition: initialGeometry.position,
      sectionId: initialGeometry.sectionId,
      targetId: guidanceTarget.id,
      targetPoint: initialGeometry.targetPoint,
      travelDistance,
    }
    // This effect coordinates a short-lived pointer animation in response to a guidance target.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setDebugTargetGeometry({
      elementRect: initialGeometry.elementRect,
      position: initialGeometry.position,
      targetPoint: initialGeometry.targetPoint,
    })

    setBubblePlacement(initialGeometry.placement)
    setManualTargetPosition({
      x: initialGeometry.position.x - FOLLOW_OFFSET.x,
      y: initialGeometry.position.y - FOLLOW_OFFSET.y,
    })
    setNavigationPhase('navigating')

    navigationTimer = window.setTimeout(() => {
      logGuidanceDebug('guidance:pointing', {
        targetId: guidanceTarget.id,
      })
      setNavigationPhase('pointing')

      returnTimer = window.setTimeout(() => {
        const returnTarget = {
          x: pointerPositionRef.current.x,
          y: pointerPositionRef.current.y,
        }
        logGuidanceDebug('guidance:returning', {
          returnTarget,
          targetId: guidanceTarget.id,
        })
        setNavigationPhase('returning')
        setManualTargetPosition(returnTarget)

        resumeTimer = window.setTimeout(() => {
          logGuidanceDebug('guidance:complete', {
            targetId: guidanceTarget.id,
          })
          setNavigationPhase('following')
          setManualTargetPosition(null)
        }, RETURN_SETTLE_MS)
      }, pointingHoldMs)
    }, navigationDurationMs)

    return () => {
      logGuidanceDebug('guidance:cleanup', {
        targetId: guidanceTarget.id,
      })
      setDebugTargetGeometry(null)
      if (navigationTimer !== null) {
        window.clearTimeout(navigationTimer)
      }
      if (returnTimer !== null) {
        window.clearTimeout(returnTimer)
      }
      if (resumeTimer !== null) {
        window.clearTimeout(resumeTimer)
      }
    }
  }, [guidanceTarget, isMounted])

  if (typeof window === 'undefined' || !isMounted) {
    return null
  }

  return createPortal(
    <SmoothFollower
      desktopOnly
      offset={FOLLOW_OFFSET}
      onPointerMove={(position) => {
        pointerPositionRef.current = position
      }}
      rotationMode={followerRotationMode}
      scaleMode="none"
      targetPosition={followerTargetPosition}
      visible={isVisible}
      zIndex={9999}
    >
      <div className="relative isolate">
        {isGuidanceDebugEnabled && effectiveDebugTargetGeometry ? (
          <>
            <div
              className="pointer-events-none fixed rounded-[20px] border border-rose-400/70 bg-rose-200/10"
              style={{
                left: effectiveDebugTargetGeometry.elementRect.left,
                top: effectiveDebugTargetGeometry.elementRect.top,
                width: effectiveDebugTargetGeometry.elementRect.width,
                height: effectiveDebugTargetGeometry.elementRect.height,
                zIndex: 9997,
              }}
            />
            <div
              className="pointer-events-none fixed h-3 w-3 -translate-x-1/2 -translate-y-1/2 rounded-full border border-rose-500 bg-rose-400/90 shadow-[0_0_0_6px_rgba(251,113,133,0.18)]"
              style={{
                left: effectiveDebugTargetGeometry.targetPoint.x,
                top: effectiveDebugTargetGeometry.targetPoint.y,
                zIndex: 9998,
              }}
            />
            <div
              className="pointer-events-none fixed h-3 w-3 -translate-x-1/2 -translate-y-1/2 rounded-full border border-sky-600 bg-sky-400/90 shadow-[0_0_0_6px_rgba(56,189,248,0.18)]"
              style={{
                left: effectiveDebugTargetGeometry.position.x,
                top: effectiveDebugTargetGeometry.position.y,
                zIndex: 9998,
              }}
            />
          </>
        ) : null}

        {shouldShowBubble ? (
          <div
            className="absolute transition-all duration-300 ease-out"
            style={{
              ...bubblePositionStyles,
              opacity: shouldShowBubble ? 1 : 0,
              transform: shouldShowBubble
                ? 'translate3d(0,0,0) scale(1)'
                : 'translate3d(0,8px,0) scale(0.96)',
            }}
          >
            <div className="max-w-[min(220px,calc(100vw-3rem))] rounded-2xl border border-white/70 bg-white/96 px-3.5 py-2 shadow-[0_16px_42px_rgba(26,26,26,0.16)] backdrop-blur-md">
              <p className="text-[13px] font-medium leading-5 text-charcoal whitespace-pre-wrap">
                {bubbleText}
              </p>
            </div>
          </div>
        ) : null}

        <div
          className="relative flex h-8 w-8 items-center justify-center transition-transform duration-300 ease-out"
          style={{
            transform: `scale(${shellScale})`,
          }}
        >
          <div
            className="absolute inset-0 rounded-full transition-all duration-500"
            style={{
              background: `radial-gradient(circle, ${shellColors.outerGlow} 0%, transparent 72%)`,
              transform:
                companionVisualState === 'responding'
                  ? 'scale(3.4)'
                  : companionVisualState === 'listening'
                    ? 'scale(3.15)'
                    : companionVisualState === 'transcribing'
                      ? 'scale(3.02)'
                      : companionVisualState === 'thinking'
                      ? 'scale(2.9)'
                      : isActive
                        ? 'scale(2.75)'
                        : 'scale(2.3)',
              opacity:
                companionVisualState === 'responding'
                  ? 0.92
                  : companionVisualState === 'listening'
                    ? 0.82
                    : companionVisualState === 'transcribing'
                      ? 0.74
                      : companionVisualState === 'thinking'
                      ? 0.68
                      : isActive
                        ? 0.56
                        : 0.3,
              filter: 'blur(5px)',
            }}
          />

          <div
            className="absolute inset-0 rounded-full transition-all duration-500"
            style={{
              background: `radial-gradient(circle, ${shellColors.innerGlow} 0%, transparent 65%)`,
              transform:
                companionVisualState === 'responding'
                  ? 'scale(2.25)'
                  : companionVisualState === 'listening'
                    ? 'scale(2.1)'
                    : companionVisualState === 'transcribing'
                      ? 'scale(2.02)'
                      : companionVisualState === 'thinking'
                      ? 'scale(1.95)'
                      : 'scale(1.75)',
              opacity:
                companionVisualState === 'responding'
                  ? 0.96
                  : companionVisualState === 'listening'
                    ? 0.88
                    : companionVisualState === 'transcribing'
                      ? 0.78
                      : companionVisualState === 'thinking'
                      ? 0.7
                      : isActive
                        ? 0.64
                        : 0.2,
            }}
          />

          {isActive ? (
            <div
              className="absolute inset-0 rounded-full"
              style={{
                border: `1px solid ${shellColors.ring}`,
                transform:
                  companionVisualState === 'idle'
                    ? 'scale(1.25)'
                    : 'scale(1.38)',
                opacity: companionVisualState === 'responding' ? 0.78 : 0.62,
              }}
            />
          ) : null}

          <div
            className="relative flex h-7 w-7 items-center justify-center rounded-full"
            style={{
              filter: 'drop-shadow(0 3px 10px rgba(26,26,26,0.14))',
            }}
          >
            <CompanionGlyph
              color={shellColors.core}
              state={companionVisualState}
            />
          </div>
        </div>
      </div>
    </SmoothFollower>,
    document.body
  )
}

export default CursorCompanion
