export interface WebCompanionTargetDescriptor {
  aliases?: string[]
  description?: string
  id: string
  label: string
  sectionId: string
  stateNotes?: string
}

export const webCompanionTargetDescriptors: WebCompanionTargetDescriptor[] = [
  {
    id: "hero-section",
    label: "Hero headline area",
    sectionId: "hero-section",
    aliases: ["hero", "main hero", "headline"],
    description:
      "Main opening section that frames Clicky and contains the two primary hero CTAs.",
  },
  {
    id: "hero-download-cta",
    label: "Hero download button",
    sectionId: "hero-section",
    aliases: ["download button", "download for macOS", "hero download"],
    description: "Primary hero CTA for downloading the macOS app.",
    stateNotes: "Static CTA in the hero row.",
  },
  {
    id: "hero-try-clicky-cta",
    label: "Hero Try Clicky button",
    sectionId: "hero-section",
    aliases: ["try clicky", "live demo button", "hero try clicky"],
    description: "Primary hero CTA that opens the live website companion flow.",
    stateNotes:
      "States include Try Clicky, Starting Clicky..., and Upgrade Clicky depending on companion state.",
  },
  {
    id: "nav-how-it-works-cta",
    label: "Navigation how it works button",
    sectionId: "hero-section",
    aliases: ["how it works", "top nav how it works"],
    description: "Top navigation link that scrolls to the Clicky sees your screen section.",
  },
  {
    id: "nav-apps-cta",
    label: "Navigation apps button",
    sectionId: "hero-section",
    aliases: ["apps", "top nav apps"],
    description: "Top navigation link that scrolls to the apps section.",
  },
  {
    id: "nav-pricing-cta",
    label: "Navigation pricing button",
    sectionId: "hero-section",
    aliases: ["pricing", "top nav pricing"],
    description: "Top navigation link that scrolls to the pricing section.",
  },
  {
    id: "nav-download-cta",
    label: "Navigation download button",
    sectionId: "hero-section",
    aliases: ["nav download", "top nav download"],
    description: "Top navigation CTA for downloading the macOS app.",
  },
  {
    id: "nav-mobile-how-it-works-cta",
    label: "Mobile navigation how it works button",
    sectionId: "hero-section",
    aliases: ["mobile how it works"],
    description:
      "Mobile navigation link that scrolls to the Clicky sees your screen section.",
  },
  {
    id: "nav-mobile-apps-cta",
    label: "Mobile navigation apps button",
    sectionId: "hero-section",
    aliases: ["mobile apps"],
    description: "Mobile navigation link that scrolls to the apps section.",
  },
  {
    id: "nav-mobile-pricing-cta",
    label: "Mobile navigation pricing button",
    sectionId: "hero-section",
    aliases: ["mobile pricing"],
    description: "Mobile navigation link that scrolls to the pricing section.",
  },
  {
    id: "nav-mobile-download-cta",
    label: "Mobile navigation download button",
    sectionId: "hero-section",
    aliases: ["mobile download"],
    description: "Mobile navigation CTA for downloading the macOS app.",
  },
  {
    id: "sees-screen",
    label: "Sees your screen section",
    sectionId: "sees-screen",
    aliases: ["sees your screen section", "screen awareness section"],
    description: "Section explaining how Clicky uses screen context.",
  },
  {
    id: "points-way",
    label: "Points the way section",
    sectionId: "points-way",
    aliases: ["points the way section", "guidance section"],
    description:
      "Section explaining how Clicky points at things instead of only describing them.",
  },
  {
    id: "knows-apps",
    label: "Knows your apps section",
    sectionId: "knows-apps",
    aliases: ["knows your apps section", "apps section"],
    description: "Section about Clicky being grounded in the apps you already use.",
  },
  {
    id: "learns-video",
    label: "Learns from video section",
    sectionId: "learns-video",
    aliases: ["learns from video section", "video section"],
    description: "Section about turning tutorial videos into actionable guidance.",
  },
  {
    id: "can-be-anything",
    label: "Can be anything section",
    sectionId: "can-be-anything",
    aliases: ["can be anything section", "identity section"],
    description:
      "Section about adapting Clicky presentation without rewriting the upstream agent identity.",
  },
  {
    id: "repeats-workflows",
    label: "Repeats workflows section",
    sectionId: "repeats-workflows",
    aliases: ["repeats workflows section", "workflow section"],
    description: "Section about capturing and replaying useful workflows.",
  },
  {
    id: "pricing",
    label: "Pricing section",
    sectionId: "pricing",
    aliases: ["pricing section", "plans"],
    description: "Pricing overview section.",
  },
  {
    id: "pricing-download-cta",
    label: "Pricing download button",
    sectionId: "pricing",
    aliases: ["pricing download", "download on pricing"],
    description: "Primary CTA inside the pricing card for downloading the macOS app.",
  },
  {
    id: "footer",
    label: "Footer section",
    sectionId: "footer",
    aliases: ["footer section"],
    description: "Closing footer section with support links and final CTA.",
  },
  {
    id: "footer-twitter-cta",
    label: "Footer Twitter link",
    sectionId: "footer",
    aliases: ["twitter", "footer twitter"],
    description: "Footer social link for Twitter.",
  },
  {
    id: "footer-email-cta",
    label: "Footer email link",
    sectionId: "footer",
    aliases: ["email", "footer email"],
    description: "Footer contact link for email.",
  },
  {
    id: "footer-download-cta",
    label: "Footer download button",
    sectionId: "footer",
    aliases: ["footer download", "download in footer"],
    description: "Final footer CTA for downloading the macOS app.",
  },
]

const webCompanionTargetDescriptorMap = new Map(
  webCompanionTargetDescriptors.map((target) => [target.id, target]),
)
const webCompanionTargetsBySectionMap = new Map(
  webCompanionTargetDescriptors.reduce<Array<[string, WebCompanionTargetDescriptor[]]>>(
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

export function getWebCompanionTargetDescriptor(targetId: string) {
  return webCompanionTargetDescriptorMap.get(targetId) ?? null
}

export function getWebCompanionTargetsForSection(sectionId: string) {
  return webCompanionTargetsBySectionMap.get(sectionId) ?? []
}
