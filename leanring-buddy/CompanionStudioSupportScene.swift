//
//  CompanionStudioSupportScene.swift
//  leanring-buddy
//
//  Backstage Studio surface for troubleshooting and support status.
//

import SwiftUI

struct CompanionStudioSupportScene: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    @ObservedObject private var backendRoutingController: ClickyBackendRoutingController
    @ObservedObject private var surfaceController: ClickySurfaceController
    @ObservedObject private var speechProviderController: ClickySpeechProviderController
    @Binding var isSupportModeEnabled: Bool
    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager, isSupportModeEnabled: Binding<Bool>) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
        _backendRoutingController = ObservedObject(wrappedValue: companionManager.backendRoutingController)
        _surfaceController = ObservedObject(wrappedValue: companionManager.surfaceController)
        _speechProviderController = ObservedObject(wrappedValue: companionManager.speechProviderController)
        _isSupportModeEnabled = isSupportModeEnabled
    }

    private var effectiveVoiceOutputDisplayName: String {
        switch preferences.clickySpeechProviderMode {
        case .system:
            return "System Speech · \(preferences.clickyVoicePreset.displayName)"
        case .elevenLabsBYO:
            let label = preferences.elevenLabsSelectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
            return "ElevenLabs · \(label.isEmpty ? "No voice selected" : label)"
        }
    }

    private var speechFallbackSummary: String? {
        if let lastSpeechFallbackMessage = speechProviderController.lastSpeechFallbackMessage {
            return lastSpeechFallbackMessage
        }

        guard preferences.clickySpeechProviderMode == .elevenLabsBYO else {
            return nil
        }

        if !companionManager.speechProviderCoordinator.hasStoredElevenLabsAPIKey {
            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Add your ElevenLabs API key. Clicky stores it only in Keychain on this Mac."
        }

        let selectedVoiceID = preferences.elevenLabsSelectedVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedVoiceID.isEmpty {
            if case .loaded = speechProviderController.elevenLabsVoiceFetchStatus,
               speechProviderController.elevenLabsAvailableVoices.isEmpty {
                return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. This ElevenLabs account does not have any voices available yet."
            }

            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Load voices and choose the one you want Clicky to use."
        }

        if speechProviderController.isElevenLabsCreditExhausted {
            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Your ElevenLabs credits are exhausted right now, so Clicky is using System Speech until you top up or switch voices."
        }

        return nil
    }

    private var clickyOpenClawPluginStatusLabel: String {
        companionManager.openClawStudioCoordinator.pluginStatusLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CompanionStudioReadableCard(
                eyebrow: "Support",
                title: "Backstage Tools"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This page is for troubleshooting and support work. It stays separate so the rest of Studio can stay calm and user-facing.")
                        .font(ClickyTypography.body(size: 14))
                        .foregroundColor(palette.cardSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle("Show support tools", isOn: $isSupportModeEnabled)
                        .toggleStyle(.switch)
                }
            }

            HStack(alignment: .top, spacing: 18) {
                CompanionStudioReadableCard(
                    eyebrow: "Current State",
                    title: "What Clicky Is Reporting"
                ) {
                    VStack(spacing: 12) {
                        CompanionStudioKeyValueRow(label: "Speech", value: effectiveVoiceOutputDisplayName)
                        CompanionStudioKeyValueRow(label: "Bridge", value: clickyOpenClawPluginStatusLabel)
                    }
                }

                CompanionStudioReadableCard(
                    eyebrow: "When To Use This",
                    title: "What Support Mode Is For"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use this when you are helping someone restore access, checking a connection issue, or confirming what Clicky is currently using behind the scenes.")
                            .font(.body)
                            .foregroundColor(palette.cardPrimaryText)

                        Text(speechFallbackSummary ?? "No voice fallback is active right now.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
