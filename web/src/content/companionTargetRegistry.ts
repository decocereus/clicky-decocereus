import type { Position } from '../components/ui/smooth-cursor'

export type CompanionBubblePlacement =
  | 'right-below'
  | 'left-below'
  | 'right-above'
  | 'left-above'

type CompanionTargetAnchor =
  | 'center'
  | 'top-center'
  | 'bottom-center'
  | 'left-center'
  | 'right-center'
  | 'top-left'
  | 'top-right'
  | 'bottom-left'
  | 'bottom-right'

interface CompanionTargetDefinition {
  id: string
  label: string
  sectionId: string
  anchor: CompanionTargetAnchor
  bubblePlacement: CompanionBubblePlacement
  cursorOffset?: Position
  aliases?: string[]
  description?: string
  stateNotes?: string
}

const VIEWPORT_PADDING = 28

export const companionTargetRegistry: CompanionTargetDefinition[] = [
  {
    id: 'hero-section',
    label: 'Hero headline area',
    sectionId: 'hero-section',
    anchor: 'center',
    bubblePlacement: 'right-below',
    cursorOffset: { x: 0, y: -24 },
    aliases: ['hero', 'main hero', 'headline'],
    description: 'Main opening section that frames Clicky and contains the two primary hero CTAs.',
  },
  {
    id: 'hero-download-cta',
    label: 'Hero download button',
    sectionId: 'hero-section',
    anchor: 'right-center',
    bubblePlacement: 'left-below',
    cursorOffset: { x: -26, y: 0 },
    aliases: ['download button', 'download for macOS', 'hero download'],
    description: 'Primary hero CTA for downloading the macOS app.',
    stateNotes: 'Static CTA in the hero row.',
  },
  {
    id: 'hero-try-clicky-cta',
    label: 'Hero Try Clicky button',
    sectionId: 'hero-section',
    anchor: 'right-center',
    bubblePlacement: 'left-below',
    cursorOffset: { x: 30, y: 0 },
    aliases: ['try clicky', 'live demo button', 'hero try clicky'],
    description: 'Primary hero CTA that opens the live website companion flow.',
    stateNotes:
      'States include Try Clicky, Starting Clicky..., and Upgrade Clicky depending on companion state.',
  },
  {
    id: 'nav-how-it-works-cta',
    label: 'Navigation how it works button',
    sectionId: 'hero-section',
    anchor: 'bottom-center',
    bubblePlacement: 'right-below',
    cursorOffset: { x: 0, y: 22 },
    aliases: ['how it works', 'top nav how it works'],
    description: 'Top navigation link that scrolls to the Clicky sees your screen section.',
  },
  {
    id: 'nav-apps-cta',
    label: 'Navigation apps button',
    sectionId: 'hero-section',
    anchor: 'bottom-center',
    bubblePlacement: 'right-below',
    cursorOffset: { x: 0, y: 22 },
    aliases: ['apps', 'top nav apps'],
    description: 'Top navigation link that scrolls to the apps section.',
  },
  {
    id: 'nav-pricing-cta',
    label: 'Navigation pricing button',
    sectionId: 'hero-section',
    anchor: 'bottom-center',
    bubblePlacement: 'left-below',
    cursorOffset: { x: 0, y: 22 },
    aliases: ['pricing', 'top nav pricing'],
    description: 'Top navigation link that scrolls to the pricing section.',
  },
  {
    id: 'nav-download-cta',
    label: 'Navigation download button',
    sectionId: 'hero-section',
    anchor: 'right-center',
    bubblePlacement: 'left-below',
    cursorOffset: { x: 28, y: 0 },
    aliases: ['nav download', 'top nav download'],
    description: 'Top navigation CTA for downloading the macOS app.',
  },
  {
    id: 'nav-mobile-how-it-works-cta',
    label: 'Mobile navigation how it works button',
    sectionId: 'hero-section',
    anchor: 'right-center',
    bubblePlacement: 'left-below',
    cursorOffset: { x: 28, y: 0 },
    aliases: ['mobile how it works'],
    description: 'Mobile navigation link that scrolls to the Clicky sees your screen section.',
  },
  {
    id: 'nav-mobile-apps-cta',
    label: 'Mobile navigation apps button',
    sectionId: 'hero-section',
    anchor: 'right-center',
    bubblePlacement: 'left-below',
    cursorOffset: { x: 28, y: 0 },
    aliases: ['mobile apps'],
    description: 'Mobile navigation link that scrolls to the apps section.',
  },
  {
    id: 'nav-mobile-pricing-cta',
    label: 'Mobile navigation pricing button',
    sectionId: 'hero-section',
    anchor: 'right-center',
    bubblePlacement: 'left-below',
    cursorOffset: { x: 28, y: 0 },
    aliases: ['mobile pricing'],
    description: 'Mobile navigation link that scrolls to the pricing section.',
  },
  {
    id: 'nav-mobile-download-cta',
    label: 'Mobile navigation download button',
    sectionId: 'hero-section',
    anchor: 'right-center',
    bubblePlacement: 'left-below',
    cursorOffset: { x: 28, y: 0 },
    aliases: ['mobile download'],
    description: 'Mobile navigation CTA for downloading the macOS app.',
  },
  {
    id: 'sees-screen',
    label: 'Reads the context section',
    sectionId: 'sees-screen',
    anchor: 'center',
    bubblePlacement: 'right-below',
    cursorOffset: { x: 0, y: -20 },
    aliases: ['reads the context section', 'screen awareness section'],
    description: 'Section explaining how Clicky stays grounded in what is on screen.',
  },
  {
    id: 'points-way',
    label: 'Shows where to look section',
    sectionId: 'points-way',
    anchor: 'center',
    bubblePlacement: 'left-below',
    cursorOffset: { x: 0, y: -20 },
    aliases: ['shows where to look section', 'guidance section'],
    description: 'Section explaining how Clicky points at things instead of only describing them.',
  },
  {
    id: 'knows-apps',
    label: 'Learns your tools section',
    sectionId: 'knows-apps',
    anchor: 'center',
    bubblePlacement: 'right-below',
    cursorOffset: { x: 0, y: -20 },
    aliases: ['learns your tools section', 'apps section'],
    description: 'Section about Clicky being grounded in the tools you already use.',
  },
  {
    id: 'learns-video',
    label: 'Turns tutorials into guidance section',
    sectionId: 'learns-video',
    anchor: 'center',
    bubblePlacement: 'right-above',
    cursorOffset: { x: 0, y: -20 },
    aliases: ['turns tutorials into guidance section', 'video section'],
    description: 'Section about turning tutorial videos into actionable guidance.',
  },
  {
    id: 'can-be-anything',
    label: 'Adapts to the moment section',
    sectionId: 'can-be-anything',
    anchor: 'center',
    bubblePlacement: 'left-above',
    cursorOffset: { x: 0, y: -20 },
    aliases: ['adapts to the moment section', 'identity section'],
    description: 'Section about adapting Clicky presentation without rewriting the upstream agent identity.',
  },
  {
    id: 'repeats-workflows',
    label: 'Keeps the useful parts section',
    sectionId: 'repeats-workflows',
    anchor: 'center',
    bubblePlacement: 'right-below',
    cursorOffset: { x: 0, y: -20 },
    aliases: ['keeps the useful parts section', 'workflow section'],
    description: 'Section about capturing and replaying useful workflows.',
  },
  {
    id: 'pricing',
    label: 'Pricing section',
    sectionId: 'pricing',
    anchor: 'center',
    bubblePlacement: 'left-above',
    cursorOffset: { x: 0, y: -18 },
    aliases: ['pricing section', 'plans'],
    description: 'Pricing overview section.',
  },
  {
    id: 'pricing-download-cta',
    label: 'Pricing download button',
    sectionId: 'pricing',
    anchor: 'right-center',
    bubblePlacement: 'left-below',
    cursorOffset: { x: 28, y: 0 },
    aliases: ['pricing download', 'download on pricing'],
    description: 'Primary CTA inside the pricing card for downloading the macOS app.',
  },
  {
    id: 'footer',
    label: 'Footer section',
    sectionId: 'footer',
    anchor: 'center',
    bubblePlacement: 'left-above',
    cursorOffset: { x: 0, y: -16 },
    aliases: ['footer section'],
    description: 'Closing footer section with support links and final CTA.',
  },
  {
    id: 'footer-email-support-cta',
    label: 'Footer email support link',
    sectionId: 'footer',
    anchor: 'top-center',
    bubblePlacement: 'right-above',
    cursorOffset: { x: 0, y: -18 },
    aliases: ['email support', 'footer email support', 'support email'],
    description: 'Footer contact link for emailing the Clicky team.',
  },
  {
    id: 'footer-download-cta',
    label: 'Footer download button',
    sectionId: 'footer',
    anchor: 'right-center',
    bubblePlacement: 'left-above',
    cursorOffset: { x: 28, y: 0 },
    aliases: ['footer download', 'download in footer'],
    description: 'Final footer CTA for downloading the macOS app.',
  },
  {
    id: 'footer-pricing-link',
    label: 'Footer pricing link',
    sectionId: 'footer',
    anchor: 'top-center',
    bubblePlacement: 'left-above',
    cursorOffset: { x: 0, y: -18 },
    aliases: ['footer pricing', 'pricing in footer'],
    description: 'Footer link back to the pricing section.',
  },
  {
    id: 'footer-support-link',
    label: 'Footer support link',
    sectionId: 'footer',
    anchor: 'top-center',
    bubblePlacement: 'left-above',
    cursorOffset: { x: 0, y: -18 },
    aliases: ['footer support', 'support in footer'],
    description: 'Footer link for contacting support.',
  },
  {
    id: 'footer-try-clicky-link',
    label: 'Footer Try Clicky link',
    sectionId: 'footer',
    anchor: 'top-center',
    bubblePlacement: 'left-above',
    cursorOffset: { x: 0, y: -18 },
    aliases: ['footer try clicky', 'try clicky in footer'],
    description: 'Footer link back to the hero so visitors can re-enter the live demo.',
  },
]

const companionTargetMap = new Map(
  companionTargetRegistry.map((target) => [target.id, target])
)
const companionTargetsBySectionMap = new Map(
  companionTargetRegistry.reduce<Array<[string, CompanionTargetDefinition[]]>>(
    (entries, target) => {
      const existingEntry = entries.find(([sectionId]) => sectionId === target.sectionId)
      if (existingEntry) {
        existingEntry[1].push(target)
      } else {
        entries.push([target.sectionId, [target]])
      }
      return entries
    },
    []
  )
)

function resolveAnchorPoint(
  rect: DOMRect,
  anchor: CompanionTargetAnchor
): Position {
  switch (anchor) {
    case 'top-center':
      return { x: rect.left + rect.width / 2, y: rect.top }
    case 'bottom-center':
      return { x: rect.left + rect.width / 2, y: rect.bottom }
    case 'left-center':
      return { x: rect.left, y: rect.top + rect.height / 2 }
    case 'right-center':
      return { x: rect.right, y: rect.top + rect.height / 2 }
    case 'top-left':
      return { x: rect.left, y: rect.top }
    case 'top-right':
      return { x: rect.right, y: rect.top }
    case 'bottom-left':
      return { x: rect.left, y: rect.bottom }
    case 'bottom-right':
      return { x: rect.right, y: rect.bottom }
    case 'center':
    default:
      return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
  }
}

function clampToViewport(position: Position): Position {
  if (typeof window === 'undefined') {
    return position
  }

  return {
    x: Math.max(
      VIEWPORT_PADDING,
      Math.min(position.x, window.innerWidth - VIEWPORT_PADDING)
    ),
    y: Math.max(
      VIEWPORT_PADDING,
      Math.min(position.y, window.innerHeight - VIEWPORT_PADDING)
    ),
  }
}

export function getCompanionTargetDefinition(targetId: string) {
  return companionTargetMap.get(targetId) ?? null
}

export function getCompanionTargetsForSection(sectionId: string) {
  return companionTargetsBySectionMap.get(sectionId) ?? []
}

export function resolveCompanionTargetGeometry(targetId: string) {
  if (typeof window === 'undefined') {
    return null
  }

  const element = document.getElementById(targetId)
  if (!element) {
    return null
  }

  const rect = element.getBoundingClientRect()
  if (rect.width <= 0 || rect.height <= 0) {
    return null
  }

  const definition = getCompanionTargetDefinition(targetId)
  if (!definition) {
    return null
  }

  const anchorPoint = resolveAnchorPoint(rect, definition.anchor)
  const cursorOffset = definition.cursorOffset ?? { x: 0, y: 0 }
  const resolvedPosition = clampToViewport({
    x: anchorPoint.x + cursorOffset.x,
    y: anchorPoint.y + cursorOffset.y,
  })

  return {
    anchor: definition.anchor,
    cursorOffset,
    elementRect: {
      height: rect.height,
      left: rect.left,
      top: rect.top,
      width: rect.width,
    },
    label: definition.label,
    placement: definition.bubblePlacement,
    position: resolvedPosition,
    sectionId: definition.sectionId,
    targetPoint: anchorPoint,
  }
}
