//
//  CompanionStudioCompanionHeroCard.swift
//  leanring-buddy
//
//  Hero and journey cards for the Companion Studio scene.
//

import SwiftUI

struct CompanionStudioCompanionHeroCard: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var backendRoutingController: ClickyBackendRoutingController

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _backendRoutingController = ObservedObject(wrappedValue: companionManager.backendRoutingController)
    }

    private var selectedAgentBackend: CompanionAgentBackend {
        preferences.selectedAgentBackend
    }

    private var clickyVoicePreset: ClickyVoicePreset {
        preferences.clickyVoicePreset
    }

    private var clickySpeechProviderMode: ClickySpeechProviderMode {
        preferences.clickySpeechProviderMode
    }

    private var effectiveOpenClawAgentName: String {
        let manualName = preferences.openClawAgentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manualName.isEmpty {
            return manualName
        }

        let inferredName = backendRoutingController.inferredOpenClawAgentIdentityName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !inferredName.isEmpty {
            return inferredName
        }

        return "your OpenClaw agent"
    }

    private var effectiveClickyPresentationName: String {
        if selectedAgentBackend != .openClaw {
            let overrideName = preferences.clickyPersonaOverrideName.trimmingCharacters(in: .whitespacesAndNewlines)
            return overrideName.isEmpty ? "Clicky" : overrideName
        }

        if preferences.clickyPersonaScopeMode == .overrideInClicky {
            let overrideName = preferences.clickyPersonaOverrideName.trimmingCharacters(in: .whitespacesAndNewlines)
            return overrideName.isEmpty ? "Clicky" : overrideName
        }

        return effectiveOpenClawAgentName
    }

    private var effectiveVoiceOutputDisplayName: String {
        switch clickySpeechProviderMode {
        case .system:
            return "System Speech · \(clickyVoicePreset.displayName)"
        case .elevenLabsBYO:
            let label = preferences.elevenLabsSelectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
            return "ElevenLabs · \(label.isEmpty ? "No voice selected" : label)"
        }
    }

    private var assistantModeDetail: String {
        switch selectedAgentBackend {
        case .claude:
            return "Cloud companion"
        case .codex:
            return "Local Codex companion"
        case .openClaw:
            return "OpenClaw companion"
        }
    }

    var body: some View {
        CompanionStudioReadableCard(
            eyebrow: "Companion",
            title: "Your Everyday Copilot"
        ) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Clicky stays out of your way until you need it, then listens, thinks, speaks back, and helps point you in the right direction.")
                    .font(ClickyTypography.body(size: 14))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 14) {
                        openPanelButton

                        Text("Open the floating companion when you want the fastest way to talk to Clicky.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        openPanelButton

                        Text("Open the floating companion when you want the fastest way to talk to Clicky.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                    }
                }

                CompanionStudioHairline()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) {
                        signalColumn(
                            title: "Assistant",
                            value: effectiveClickyPresentationName,
                            detail: assistantModeDetail
                        )
                        signalColumn(
                            title: "Voice",
                            value: effectiveVoiceOutputDisplayName,
                            detail: clickyVoicePreset.displayName
                        )
                        signalColumn(
                            title: "Guidance",
                            value: preferences.isClickyCursorEnabled ? "Pointer guidance on" : "Pointer guidance off",
                            detail: "Screen help when needed"
                        )
                    }

                    VStack(spacing: 12) {
                        signalStack(
                            title: "Assistant",
                            value: effectiveClickyPresentationName,
                            detail: assistantModeDetail
                        )
                        signalStack(
                            title: "Voice",
                            value: effectiveVoiceOutputDisplayName,
                            detail: clickyVoicePreset.displayName
                        )
                        signalStack(
                            title: "Guidance",
                            value: preferences.isClickyCursorEnabled ? "Pointer guidance on" : "Pointer guidance off",
                            detail: "Screen help when needed"
                        )
                    }
                }
            }
        }
    }

    private var openPanelButton: some View {
        Button {
            NotificationCenter.default.post(name: .clickyShowPanel, object: nil)
        } label: {
            Label("Open Companion Panel", systemImage: "sparkles")
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .frame(minWidth: 180)
        }
        .modifier(CompanionStudioPrimaryButtonModifier())
        .pointerCursor()
    }

    private func signalColumn(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(value)
                .font(ClickyTypography.section(size: 22))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private func signalStack(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(value)
                .font(ClickyTypography.body(size: 16, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(2)
                .truncationMode(.tail)
                .minimumScaleFactor(0.90)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardAccent.opacity(0.40))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }
}

struct CompanionStudioCompanionJourneyCard: View {
    var body: some View {
        CompanionStudioReadableCard(
            eyebrow: "Flow",
            title: "How A Clicky Moment Works"
        ) {
            HStack(alignment: .top, spacing: 14) {
                CompanionStudioJourneyStep(
                    step: "01",
                    title: "Hold the shortcut",
                    copy: "Clicky starts listening the moment you hold Control + Option."
                )
                CompanionStudioJourneyStep(
                    step: "02",
                    title: "Ask naturally",
                    copy: "Say what you want help with in plain language, without opening a settings page first."
                )
                CompanionStudioJourneyStep(
                    step: "03",
                    title: "Get a spoken answer",
                    copy: "Clicky replies in your selected voice and can point at things on screen when it helps."
                )
            }
        }
    }
}
