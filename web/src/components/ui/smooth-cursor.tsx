import { type FC, type ReactNode, useEffect, useRef, useState } from 'react'
import { animate, motion, useMotionValue, useSpring } from 'framer-motion'

export interface Position {
  x: number
  y: number
}

type RotationMode = 'none' | 'velocity'
type ScaleMode = 'none' | 'velocity'

interface SpringConfig {
  damping: number
  stiffness: number
  mass: number
  restDelta: number
}

interface PlaybackControlsLike {
  stop: () => void
}

export interface SmoothCursorProps {
  children?: ReactNode
  cursor?: ReactNode
  desktopOnly?: boolean
  hideNativeCursor?: boolean
  onPointerMove?: (position: Position) => void
  offset?: Position
  rotationMode?: RotationMode
  scaleMode?: ScaleMode
  springConfig?: SpringConfig
  targetPosition?: Position | null
  visible?: boolean
  zIndex?: number
}

const DESKTOP_POINTER_QUERY = '(any-hover: hover) and (any-pointer: fine)'

const DEFAULT_OFFSET: Position = {
  x: 0,
  y: 0,
}

const DEFAULT_SPRING_CONFIG: SpringConfig = {
  damping: 45,
  stiffness: 400,
  mass: 1,
  restDelta: 0.001,
}

function isTrackablePointer(pointerType: string) {
  return pointerType !== 'touch'
}

const DefaultCursorSVG: FC = () => {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={50}
      height={54}
      viewBox="0 0 50 54"
      fill="none"
      style={{ scale: 0.5 }}
    >
      <g filter="url(#filter0_d_91_7928)">
        <path
          d="M42.6817 41.1495L27.5103 6.79925C26.7269 5.02557 24.2082 5.02558 23.3927 6.79925L7.59814 41.1495C6.75833 42.9759 8.52712 44.8902 10.4125 44.1954L24.3757 39.0496C24.8829 38.8627 25.4385 38.8627 25.9422 39.0496L39.8121 44.1954C41.6849 44.8902 43.4884 42.9759 42.6817 41.1495Z"
          fill="black"
        />
        <path
          d="M43.7146 40.6933L28.5431 6.34306C27.3556 3.65428 23.5772 3.69516 22.3668 6.32755L6.57226 40.6778C5.3134 43.4156 7.97238 46.298 10.803 45.2549L24.7662 40.109C25.0221 40.0147 25.2999 40.0156 25.5494 40.1082L39.4193 45.254C42.2261 46.2953 44.9254 43.4347 43.7146 40.6933Z"
          stroke="white"
          strokeWidth={2.25825}
        />
      </g>
      <defs>
        <filter
          id="filter0_d_91_7928"
          x={0.602397}
          y={0.952444}
          width={49.0584}
          height={52.428}
          filterUnits="userSpaceOnUse"
          colorInterpolationFilters="sRGB"
        >
          <feFlood floodOpacity={0} result="BackgroundImageFix" />
          <feColorMatrix
            in="SourceAlpha"
            type="matrix"
            values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0"
            result="hardAlpha"
          />
          <feOffset dy={2.25825} />
          <feGaussianBlur stdDeviation={2.25825} />
          <feComposite in2="hardAlpha" operator="out" />
          <feColorMatrix
            type="matrix"
            values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.08 0"
          />
          <feBlend
            mode="normal"
            in2="BackgroundImageFix"
            result="effect1_dropShadow_91_7928"
          />
          <feBlend
            mode="normal"
            in="SourceGraphic"
            in2="effect1_dropShadow_91_7928"
            result="shape"
          />
        </filter>
      </defs>
    </svg>
  )
}

export function SmoothCursor({
  children,
  cursor = <DefaultCursorSVG />,
  desktopOnly = true,
  hideNativeCursor = false,
  onPointerMove,
  offset = DEFAULT_OFFSET,
  rotationMode = 'none',
  scaleMode = 'none',
  springConfig = DEFAULT_SPRING_CONFIG,
  targetPosition = null,
  visible,
  zIndex = 100,
}: SmoothCursorProps) {
  const lastPointerPos = useRef<Position>({ x: 0, y: 0 })
  const velocity = useRef<Position>({ x: 0, y: 0 })
  const lastUpdateTime = useRef(Date.now())
  const previousAngle = useRef(0)
  const accumulatedRotation = useRef(0)
  const pointerMoveRaf = useRef<number | null>(null)
  const scaleResetTimeout = useRef<number | null>(null)
  const targetAnimationXRef = useRef<PlaybackControlsLike | null>(null)
  const targetAnimationYRef = useRef<PlaybackControlsLike | null>(null)
  const [isEnabled, setIsEnabled] = useState(!desktopOnly)
  const [hasTrackedPosition, setHasTrackedPosition] = useState(false)

  const cursorX = useMotionValue(0)
  const cursorY = useMotionValue(0)
  const rotation = useSpring(0, {
    ...springConfig,
    damping: 60,
    stiffness: 300,
  })
  const scale = useSpring(1, {
    ...springConfig,
    stiffness: 500,
    damping: 35,
  })

  useEffect(() => {
    if (!desktopOnly) {
      setIsEnabled(true)
      return undefined
    }

    const mediaQuery = window.matchMedia(DESKTOP_POINTER_QUERY)

    const updateEnabled = () => {
      const nextIsEnabled = mediaQuery.matches
      setIsEnabled(nextIsEnabled)

      if (!nextIsEnabled) {
        setHasTrackedPosition(false)
      }
    }

    updateEnabled()
    mediaQuery.addEventListener('change', updateEnabled)

    return () => {
      mediaQuery.removeEventListener('change', updateEnabled)
    }
  }, [desktopOnly])

  useEffect(() => {
    if (!isEnabled) {
      return
    }

    if (targetPosition === null) {
      targetAnimationXRef.current?.stop()
      targetAnimationYRef.current?.stop()
      targetAnimationXRef.current = null
      targetAnimationYRef.current = null
    }

    const updateMotion = (nextPosition: Position) => {
      const currentTime = Date.now()
      const deltaTime = currentTime - lastUpdateTime.current

      if (deltaTime > 0) {
        velocity.current = {
          x: (nextPosition.x - lastPointerPos.current.x) / deltaTime,
          y: (nextPosition.y - lastPointerPos.current.y) / deltaTime,
        }
      }

      lastUpdateTime.current = currentTime
      lastPointerPos.current = nextPosition
      onPointerMove?.(nextPosition)

      if (targetPosition !== null) {
        return
      }

      cursorX.set(nextPosition.x + offset.x)
      cursorY.set(nextPosition.y + offset.y)

      const speed = Math.hypot(velocity.current.x, velocity.current.y)

      if (rotationMode === 'velocity' && speed > 0.1) {
        const currentAngle =
          Math.atan2(velocity.current.y, velocity.current.x) * (180 / Math.PI) + 90

        let angleDiff = currentAngle - previousAngle.current
        if (angleDiff > 180) angleDiff -= 360
        if (angleDiff < -180) angleDiff += 360
        accumulatedRotation.current += angleDiff
        rotation.set(accumulatedRotation.current)
        previousAngle.current = currentAngle
      }

      if (scaleMode === 'velocity' && speed > 0.1) {
        scale.set(0.95)

        if (scaleResetTimeout.current !== null) {
          window.clearTimeout(scaleResetTimeout.current)
        }

        scaleResetTimeout.current = window.setTimeout(() => {
          scale.set(1)
        }, 150)
      }
    }

    const handlePointerMove = (event: PointerEvent) => {
      if (!isTrackablePointer(event.pointerType)) {
        return
      }

      setHasTrackedPosition(true)

      if (pointerMoveRaf.current !== null) {
        window.cancelAnimationFrame(pointerMoveRaf.current)
      }

      pointerMoveRaf.current = window.requestAnimationFrame(() => {
        updateMotion({
          x: event.clientX,
          y: event.clientY,
        })
        pointerMoveRaf.current = null
      })
    }

    window.addEventListener('pointermove', handlePointerMove, {
      passive: true,
    })

    return () => {
      window.removeEventListener('pointermove', handlePointerMove)
      if (pointerMoveRaf.current !== null) {
        window.cancelAnimationFrame(pointerMoveRaf.current)
        pointerMoveRaf.current = null
      }
      if (scaleResetTimeout.current !== null) {
        window.clearTimeout(scaleResetTimeout.current)
        scaleResetTimeout.current = null
      }
    }
  }, [
    cursorX,
    cursorY,
    isEnabled,
    onPointerMove,
    offset.x,
    offset.y,
    rotation,
    rotationMode,
    scale,
    scaleMode,
    targetPosition,
  ])

  useEffect(() => {
    if (!isEnabled || targetPosition === null) {
      return
    }

    targetAnimationXRef.current?.stop()
    targetAnimationYRef.current?.stop()

    const currentPosition = {
      x: cursorX.get() - offset.x,
      y: cursorY.get() - offset.y,
    }
    const deltaX = targetPosition.x - currentPosition.x
    const deltaY = targetPosition.y - currentPosition.y
    const distance = Math.hypot(deltaX, deltaY)
    const targetSpringConfig = {
      type: 'spring' as const,
      damping: Math.max(28, springConfig.damping * 0.76),
      stiffness: Math.max(200, springConfig.stiffness * 0.62),
      mass: springConfig.mass * 1.08,
      restDelta: springConfig.restDelta,
    }

    setHasTrackedPosition(true)
    targetAnimationXRef.current = animate(cursorX, targetPosition.x + offset.x, {
      ...targetSpringConfig,
    })
    targetAnimationYRef.current = animate(cursorY, targetPosition.y + offset.y, {
      ...targetSpringConfig,
    })

    if (rotationMode === 'velocity' && distance > 0.1) {
      const targetAngle = Math.atan2(deltaY, deltaX) * (180 / Math.PI) + 90
      rotation.set(targetAngle)
    }

    if (scaleMode === 'velocity') {
      scale.set(0.97)

      if (scaleResetTimeout.current !== null) {
        window.clearTimeout(scaleResetTimeout.current)
      }

      scaleResetTimeout.current = window.setTimeout(() => {
        scale.set(1)
      }, 150)
    }

    return () => {
      targetAnimationXRef.current?.stop()
      targetAnimationYRef.current?.stop()
      targetAnimationXRef.current = null
      targetAnimationYRef.current = null
    }
  }, [
    cursorX,
    cursorY,
    isEnabled,
    offset.x,
    offset.y,
    rotation,
    rotationMode,
    scale,
    scaleMode,
    springConfig,
    targetPosition,
  ])

  useEffect(() => {
    if (rotationMode !== 'none') {
      return
    }

    accumulatedRotation.current = 0
    previousAngle.current = 0
    rotation.set(0)
  }, [rotation, rotationMode])

  useEffect(() => {
    if (scaleMode !== 'none') {
      return
    }

    scale.set(1)
  }, [scale, scaleMode])

  useEffect(() => {
    if (!isEnabled || !hideNativeCursor) {
      return
    }

    const previousCursor = document.body.style.cursor
    document.body.style.cursor = 'none'

    return () => {
      document.body.style.cursor = previousCursor || 'auto'
    }
  }, [hideNativeCursor, isEnabled])

  if (!isEnabled) {
    return null
  }

  const renderedCursor = children ?? cursor
  const isVisible = visible ?? hasTrackedPosition

  return (
    <motion.div
      style={{
        position: 'fixed',
        left: cursorX,
        top: cursorY,
        translateX: '-50%',
        translateY: '-50%',
        rotate: rotation,
        scale: scale,
        zIndex,
        pointerEvents: 'none',
        willChange: 'transform',
        opacity: isVisible ? 1 : 0,
      }}
      initial={false}
      animate={{ opacity: isVisible ? 1 : 0 }}
      transition={{
        duration: 0.15,
      }}
    >
      {renderedCursor}
    </motion.div>
  )
}

export const SmoothFollower = SmoothCursor
