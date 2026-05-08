//
//  CompanionPanelPrimaryContentCard.swift
//  leanring-buddy
//
//  Primary narrative card for the menu-bar companion panel.
//

import SwiftUI

struct CompanionPanelPrimaryContentCard: View {
    let screen: CompanionPanelScreen
    let tutorialPlaybackTitle: String

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .welcome:
            copyCard(
                title: "A companion that sees what you see and helps while you work.",
                body: "Hold Control+Option, ask naturally, and let Clicky understand your screen, answer in voice, and guide your attention when it matters."
            )
        case .signIn:
            copyCard(
                title: "Sign in so Clicky can stay with you.",
                body: "You get a free taste first. Upgrade only after you've felt the value. Sign-in keeps your credits, restore access, and purchase state attached to you."
            )
        case .permissions:
            copyCard(
                title: "Give Clicky the access it needs to help in context.",
                body: "These permissions let Clicky listen, understand what's on screen, guide your attention, and act when you approve it. Only show what still needs attention."
            )
        case .ready:
            copyCard(
                title: "Clicky is ready to join you in the work.",
                body: "From here on, the product should teach itself through use. Hold Control+Option whenever you want help."
            )
        case .active:
            activeHeroCard
        case .locked:
            copyCard(
                title: "You've felt what Clicky can do.",
                body: "Unlock it to keep this companion with you while you work.",
                tone: .subtle
            )
        case .repair:
            copyCard(
                title: "Clicky lost some of the access it uses to help.",
                body: "This is a quick repair moment. Restore what's missing and Clicky can keep guiding you in context."
            )
        case .tutorialEntry:
            copyCard(
                title: "Hold Control+Option whenever you want Clicky with you.",
                body: "The everyday state stays quiet, but Clicky can also turn a YouTube tutorial into something you can follow step by step."
            )
        case .tutorialImportEntry, .tutorialImportMissingSetup:
            copyCard(
                title: "Learn from YouTube",
                body: "Paste a tutorial URL and Clicky will turn it into a guided flow beside your cursor."
            )
        case .tutorialExtracting:
            copyCard(
                title: "Pulling out the useful parts of the tutorial.",
                body: "Clicky is extracting transcript, timestamps, and visual evidence so it can guide you later instead of just dumping a video on you."
            )
        case .tutorialCompiling:
            copyCard(
                title: "Turning the tutorial into a guided lesson.",
                body: "The selected backend is compiling the evidence bundle into clear steps that Clicky can teach through, not just quote back."
            )
        case .tutorialReady:
            copyCard(
                title: "Your guided lesson is ready.",
                body: "Clicky has turned the tutorial into a step-by-step lesson you can follow beside your cursor."
            )
        case .tutorialPlayback:
            copyCard(
                title: tutorialPlaybackTitle,
                body: "Clicky can explain this step, answer questions, or point you at the right part of the UI."
            )
        case .tutorialFailed:
            copyCard(
                title: "Clicky couldn't turn this tutorial into a lesson yet.",
                body: "The import draft is still safe locally, so you can retry, switch sources, or inspect what failed in Studio.",
                tone: .subtle
            )
        }
    }

    private func copyCard(title: String, body: String, tone: ClickyPanelContentTone = .hero) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(ClickyTypography.section(size: 22))
                .foregroundColor(contentTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(body)
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(contentTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .modifier(ClickyPanelContentCardStyle(tone: tone, padding: 18))
    }

    private var activeHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Hold")
                    .font(ClickyTypography.section(size: 21))
                    .foregroundColor(contentTheme.textPrimary)

                CompanionPanelShortcutKeycap("⌃")
                CompanionPanelShortcutKeycap("⌥")

                Text("to talk.")
                    .font(ClickyTypography.section(size: 21))
                    .foregroundColor(contentTheme.textPrimary)
            }

            Text("Ask naturally and Clicky will guide your attention, answer in voice, and keep your place.")
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(contentTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .modifier(ClickyPanelContentCardStyle(tone: .hero, padding: 18))
    }
}
