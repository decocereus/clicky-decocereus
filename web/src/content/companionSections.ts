import { getCompanionTargetsForSection } from './companionTargetRegistry'

export interface CompanionSectionDefinition {
  id: string
  title: string
  summary: string
  suggestedReplies: string[]
  targetIds: string[]
}

const baseCompanionSections: Omit<CompanionSectionDefinition, 'targetIds'>[] = [
  {
    id: 'hero-section',
    title: 'Hero',
    summary:
      'Clicky is introduced as an organic layer of intelligence that feels present inside the work, not separate from it.',
    suggestedReplies: [
      'What makes Clicky different from a chatbot?',
      'What does Clicky actually do on my Mac?',
    ],
  },
  {
    id: 'sees-screen',
    title: 'Clicky sees your screen',
    summary:
      'This section explains the screen-context layer that helps Clicky respond to what you are already doing.',
    suggestedReplies: [
      'What does screen awareness mean here?',
      'Does Clicky just read screenshots?',
    ],
  },
  {
    id: 'points-way',
    title: 'Clicky points the way',
    summary:
      'This section focuses on guided attention: Clicky should be able to show you where to go, not only tell you.',
    suggestedReplies: [
      'How does the pointing behavior work?',
      'Is this like a guided walkthrough?',
    ],
  },
  {
    id: 'knows-apps',
    title: 'Clicky knows your apps',
    summary:
      'This section frames Clicky as grounded in the tools you already use rather than living in a detached assistant pane.',
    suggestedReplies: [
      'What apps is Clicky meant for?',
      'Does it work outside design tools too?',
    ],
  },
  {
    id: 'learns-video',
    title: 'Clicky learns from video',
    summary:
      'This part of the page turns tutorial content into guided, actionable knowledge instead of passive video watching.',
    suggestedReplies: [
      'Can Clicky turn tutorials into workflows?',
      'What other inputs can it use?',
    ],
  },
  {
    id: 'can-be-anything',
    title: 'Clicky can be anything',
    summary:
      'This section is about identity and presentation: the shell can adapt without erasing the upstream agent.',
    suggestedReplies: [
      'Can I use my own OpenClaw agent identity?',
      'How much of Clicky is customizable?',
    ],
  },
  {
    id: 'repeats-workflows',
    title: 'Clicky repeats workflows',
    summary:
      'This section is about repeatability. Clicky should help capture useful patterns, not only answer one-off questions.',
    suggestedReplies: [
      'Can Clicky automate recurring tasks?',
      'Is this more than a live assistant?',
    ],
  },
  {
    id: 'pricing',
    title: 'Pricing',
    summary:
      'This section explains the single launch plan and what the current Clicky offer includes.',
    suggestedReplies: [
      'What do I get for the launch price?',
      'Who is Clicky a fit for?',
    ],
  },
  {
    id: 'footer',
    title: 'Footer',
    summary:
      'This is the close of the page: support paths, the final download prompt, and the last chance to ask a question.',
    suggestedReplies: [
      'Can you summarize Clicky in one minute?',
      'What should I know before downloading?',
    ],
  },
]

export const companionSections: CompanionSectionDefinition[] = baseCompanionSections.map(
  (section) => ({
    ...section,
    targetIds: getCompanionTargetsForSection(section.id).map((target) => target.id),
  })
)

export const companionSectionIds = companionSections.map((section) => section.id)

const companionSectionMap = new Map(
  companionSections.map((section) => [section.id, section])
)

export function getCompanionSection(sectionId: string | null | undefined) {
  if (!sectionId) {
    return null
  }

  return companionSectionMap.get(sectionId) ?? null
}
