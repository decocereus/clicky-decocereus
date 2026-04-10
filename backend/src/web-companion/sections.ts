import type { WebCompanionSection } from "./types"

export const webCompanionSections: WebCompanionSection[] = [
  {
    id: "hero-section",
    title: "Hero",
    summary:
      "The hero introduces Clicky as a soft, fluid AI layer that lives with you while you work.",
    proactiveNudge:
      "This first screen is the thesis in one line: Clicky is meant to feel present, not bolted on. Want the quick explanation?",
    suggestedQuestions: [
      "What makes Clicky different from a chatbot?",
      "What does Clicky actually do on my Mac?",
    ],
    allowedTargets: [
      "hero-section",
      "hero-download-cta",
      "nav-download-cta",
      "nav-mobile-download-cta",
    ],
  },
  {
    id: "sees-screen",
    title: "Clicky sees your screen",
    summary:
      "Clicky uses screen context so the agent can respond to what is actually in front of you.",
    proactiveNudge:
      "This section is about context. Clicky is useful because it reacts to the software you're already in.",
    suggestedQuestions: [
      "What does screen awareness mean here?",
      "Does Clicky just read screenshots?",
    ],
    allowedTargets: ["sees-screen"],
  },
  {
    id: "points-way",
    title: "Clicky points the way",
    summary:
      "Clicky can visually direct attention to the next useful place on screen instead of only describing it in text.",
    proactiveNudge:
      "This is the guidance layer. Clicky should be able to show you where to look, not just tell you.",
    suggestedQuestions: [
      "How does the pointing behavior work?",
      "Is this like a guided walkthrough?",
    ],
    allowedTargets: ["points-way"],
  },
  {
    id: "knows-apps",
    title: "Clicky knows your apps",
    summary:
      "Clicky is designed to feel grounded in the tools you already use instead of living in a detached chat window.",
    proactiveNudge:
      "This section is about familiarity. Clicky should feel like it understands the app you're already in.",
    suggestedQuestions: [
      "What apps is Clicky meant for?",
      "Does it work outside design tools too?",
    ],
    allowedTargets: ["knows-apps"],
  },
  {
    id: "learns-video",
    title: "Clicky learns from video",
    summary:
      "Clicky can turn tutorial video inputs into guided, actionable steps instead of leaving knowledge trapped in playback.",
    proactiveNudge:
      "The interesting part here is transformation: video becomes steps you can actually follow and reuse.",
    suggestedQuestions: [
      "Can Clicky turn tutorials into workflows?",
      "What other inputs can Clicky use?",
    ],
    allowedTargets: ["learns-video"],
  },
  {
    id: "can-be-anything",
    title: "Clicky can be anything",
    summary:
      "Clicky can adapt presentation and personality without overwriting the upstream agent's identity.",
    proactiveNudge:
      "This section is about identity and flexibility. The shell can feel custom without pretending the upstream agent changed globally.",
    suggestedQuestions: [
      "Can I use my own OpenClaw agent identity?",
      "How much of Clicky is customizable?",
    ],
    allowedTargets: ["can-be-anything"],
  },
  {
    id: "repeats-workflows",
    title: "Clicky repeats workflows",
    summary:
      "Clicky is not just for one-off guidance. It can help capture and repeat useful patterns.",
    proactiveNudge:
      "This is the repeatability angle: once something is clear, it should be easier to reuse instead of relearn.",
    suggestedQuestions: [
      "Can Clicky automate recurring tasks?",
      "Is this more than just a live assistant?",
    ],
    allowedTargets: ["repeats-workflows"],
  },
  {
    id: "pricing",
    title: "Pricing",
    summary:
      "The pricing section explains the single launch plan and what is included in the current Clicky offer.",
    proactiveNudge:
      "You’re at pricing. I can give you the short version, who it’s for, or what’s included before you decide.",
    suggestedQuestions: [
      "What do I get for the launch price?",
      "Who is Clicky a fit for right now?",
    ],
    allowedTargets: ["pricing", "pricing-download-cta"],
  },
  {
    id: "footer",
    title: "Footer",
    summary:
      "The footer closes the page with support links and one last download invitation.",
    proactiveNudge:
      "If you made it to the footer, I can answer the last question that's still blocking you from trying Clicky.",
    suggestedQuestions: [
      "Can you summarize Clicky in one minute?",
      "What should I know before downloading?",
    ],
    allowedTargets: ["footer", "footer-download-cta"],
  },
]

const webCompanionSectionMap = new Map(
  webCompanionSections.map((section) => [section.id, section]),
)

export function getWebCompanionSection(sectionId: string | null | undefined) {
  if (!sectionId) {
    return null
  }

  return webCompanionSectionMap.get(sectionId) ?? null
}

export function isKnownWebCompanionSection(sectionId: string | null | undefined) {
  if (!sectionId) {
    return false
  }

  return webCompanionSectionMap.has(sectionId)
}
