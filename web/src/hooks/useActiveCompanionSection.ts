import { useDeferredValue, useEffect, useState } from 'react'

function findNearestSection(sectionIds: string[]) {
  const viewportFocusLine = window.innerHeight * 0.42
  let nearestSectionId: string | null = null
  let nearestDistance = Number.POSITIVE_INFINITY

  for (const sectionId of sectionIds) {
    const element = document.getElementById(sectionId)
    if (!element) {
      continue
    }

    const rect = element.getBoundingClientRect()
    const distance =
      rect.top > viewportFocusLine
        ? rect.top - viewportFocusLine
        : viewportFocusLine - rect.bottom

    if (distance < nearestDistance) {
      nearestDistance = distance
      nearestSectionId = sectionId
    }
  }

  return nearestSectionId
}

export function useActiveCompanionSection(sectionIds: string[]) {
  const [activeSectionId, setActiveSectionId] = useState<string | null>(null)
  const deferredSectionId = useDeferredValue(activeSectionId)

  useEffect(() => {
    if (sectionIds.length === 0) {
      return undefined
    }

    let frameId = 0

    const updateActiveSection = () => {
      frameId = 0
      const nextSectionId = findNearestSection(sectionIds)
      setActiveSectionId((currentSectionId) =>
        currentSectionId === nextSectionId ? currentSectionId : nextSectionId
      )
    }

    const queueUpdate = () => {
      if (frameId !== 0) {
        return
      }

      frameId = window.requestAnimationFrame(updateActiveSection)
    }

    updateActiveSection()

    window.addEventListener('scroll', queueUpdate, { passive: true })
    window.addEventListener('resize', queueUpdate)

    return () => {
      if (frameId !== 0) {
        window.cancelAnimationFrame(frameId)
      }

      window.removeEventListener('scroll', queueUpdate)
      window.removeEventListener('resize', queueUpdate)
    }
  }, [sectionIds])

  return deferredSectionId
}
