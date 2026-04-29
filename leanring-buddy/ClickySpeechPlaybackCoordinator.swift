//
//  ClickySpeechPlaybackCoordinator.swift
//  leanring-buddy
//
//  Owns spoken-response playback and runtime fallback behavior.
//

import Foundation

enum ClickySpeechPlaybackPurpose: String {
    case assistantResponse = "assistant-response"
    case systemMessage = "system-message"
    case preview = "preview"

    var logLabel: String { rawValue }
}

struct ClickySpeechPlaybackOutcome {
    let finalProviderDisplayName: String
    let fallbackMessage: String?
    let encounteredElevenLabsFailure: Bool
}

@MainActor
final class ClickySpeechPlaybackCoordinator {
    private let preferences: ClickyPreferencesStore
    private let controller: ClickySpeechProviderController
    private let ttsClient: ElevenLabsTTSClient
    private let speechRoutingProvider: () -> ClickySpeechRouting
    private let voicePresetProvider: () -> ClickyVoicePreset

    init(
        preferences: ClickyPreferencesStore,
        controller: ClickySpeechProviderController,
        ttsClient: ElevenLabsTTSClient,
        speechRoutingProvider: @escaping () -> ClickySpeechRouting,
        voicePresetProvider: @escaping () -> ClickyVoicePreset
    ) {
        self.preferences = preferences
        self.controller = controller
        self.ttsClient = ttsClient
        self.speechRoutingProvider = speechRoutingProvider
        self.voicePresetProvider = voicePresetProvider
    }

    func play(
        _ text: String,
        purpose: ClickySpeechPlaybackPurpose
    ) async -> ClickySpeechPlaybackOutcome {
        if purpose == .systemMessage {
            return await playSystemMessage(text)
        }

        let routing = speechRoutingProvider()
        let selectedVoiceName = routing.selectedVoiceNameLabel
        let selectedVoiceID = routing.selectedVoiceIDLabel
        let configurationFallbackMessage = routing.configurationFallbackMessage ?? "none"

        ClickyLogger.info(
            .audio,
            "speech-routing purpose=\(purpose.logLabel) selected=\(routing.selectedProviderDisplayName) resolved=\(routing.resolvedProviderDisplayName) voiceName=\(selectedVoiceName) voiceID=\(selectedVoiceID) configFallback=\(configurationFallbackMessage)"
        )

        do {
            try await ttsClient.speakText(
                text,
                voicePreset: voicePresetProvider(),
                outputMode: routing.outputMode
            )

            if case .elevenLabsBYO = routing.outputMode {
                controller.isElevenLabsCreditExhausted = false
            }

            if let fallbackMessage = routing.configurationFallbackMessage {
                let summary = "ElevenLabs is selected, but this \(purpose.logLabel) used System Speech. \(fallbackMessage)"
                controller.lastSpeechFallbackMessage = summary
                ClickyLogger.notice(
                    .audio,
                    "speech-playback success purpose=\(purpose.logLabel) provider=System Speech reason=config-fallback"
                )
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "System Speech",
                    fallbackMessage: summary,
                    encounteredElevenLabsFailure: false
                )
            }

            controller.lastSpeechFallbackMessage = nil
            ClickyLogger.notice(
                .audio,
                "speech-playback success purpose=\(purpose.logLabel) provider=\(routing.resolvedProviderDisplayName)"
            )
            return ClickySpeechPlaybackOutcome(
                finalProviderDisplayName: routing.resolvedProviderDisplayName,
                fallbackMessage: nil,
                encounteredElevenLabsFailure: false
            )
        } catch {
            return await handlePrimaryPlaybackFailure(
                error,
                text: text,
                purpose: purpose,
                routing: routing,
                selectedVoiceName: selectedVoiceName,
                selectedVoiceID: selectedVoiceID
            )
        }
    }

    private func handlePrimaryPlaybackFailure(
        _ error: Error,
        text: String,
        purpose: ClickySpeechPlaybackPurpose,
        routing: ClickySpeechRouting,
        selectedVoiceName: String,
        selectedVoiceID: String
    ) async -> ClickySpeechPlaybackOutcome {
        switch routing.outputMode {
        case .system:
            let failureMessage = "Clicky could not play audio. \(error.localizedDescription)"
            controller.lastSpeechFallbackMessage = failureMessage
            ClickyLogger.error(
                .audio,
                "speech-playback failed purpose=\(purpose.logLabel) provider=System Speech error=\(error.localizedDescription)"
            )
            return ClickySpeechPlaybackOutcome(
                finalProviderDisplayName: "Unavailable",
                fallbackMessage: failureMessage,
                encounteredElevenLabsFailure: false
            )
        case .elevenLabsBYO:
            let isCreditExhaustion = ClickySpeechProviderCoordinator.isLikelyCreditExhaustion(error)
            if isCreditExhaustion {
                controller.isElevenLabsCreditExhausted = true
            }

            let fallbackMessage: String
            if isCreditExhaustion {
                fallbackMessage = "Your ElevenLabs credits are exhausted right now, so Clicky switched to System Speech and kept the conversation moving."
            } else {
                fallbackMessage = "ElevenLabs could not play audio, so Clicky fell back to System Speech. \(error.localizedDescription)"
            }
            controller.lastSpeechFallbackMessage = fallbackMessage
            ClickyLogger.error(
                .audio,
                "speech-playback failed purpose=\(purpose.logLabel) provider=ElevenLabs voiceName=\(selectedVoiceName) voiceID=\(selectedVoiceID) error=\(error.localizedDescription)"
            )

            do {
                try await ttsClient.speakText(
                    text,
                    voicePreset: voicePresetProvider(),
                    outputMode: .system
                )
            } catch {
                let failureMessage = "Clicky could not play audio. \(error.localizedDescription)"
                controller.lastSpeechFallbackMessage = failureMessage
                ClickyLogger.error(
                    .audio,
                    "speech-playback fallback failed purpose=\(purpose.logLabel) error=\(error.localizedDescription)"
                )
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "Unavailable",
                    fallbackMessage: failureMessage,
                    encounteredElevenLabsFailure: true
                )
            }

            ClickyLogger.notice(
                .audio,
                "speech-playback fallback purpose=\(purpose.logLabel) provider=System Speech reason=elevenlabs-runtime-failure"
            )
            return ClickySpeechPlaybackOutcome(
                finalProviderDisplayName: "System Speech",
                fallbackMessage: fallbackMessage,
                encounteredElevenLabsFailure: true
            )
        }
    }

    private func playSystemMessage(_ text: String) async -> ClickySpeechPlaybackOutcome {
        let selectedVoiceID = preferences.elevenLabsSelectedVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedVoiceName = preferences.elevenLabsSelectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedAPIKey = (ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !storedAPIKey.isEmpty && !selectedVoiceID.isEmpty && !controller.isElevenLabsCreditExhausted && !controller.isElevenLabsAPIKeyRejected {
            do {
                try await ttsClient.speakText(
                    text,
                    voicePreset: voicePresetProvider(),
                    outputMode: .elevenLabsBYO(
                        ElevenLabsDirectConfiguration(apiKey: storedAPIKey, voiceID: selectedVoiceID)
                    )
                )
                controller.isElevenLabsCreditExhausted = false
                controller.isElevenLabsAPIKeyRejected = false
                controller.lastSpeechFallbackMessage = nil
                ClickyLogger.notice(
                    .audio,
                    "speech-playback success purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=ElevenLabs source=user-key voiceName=\(selectedVoiceName)"
                )
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "ElevenLabs",
                    fallbackMessage: nil,
                    encounteredElevenLabsFailure: false
                )
            } catch {
                if ClickySpeechProviderCoordinator.isLikelyCreditExhaustion(error) {
                    controller.isElevenLabsCreditExhausted = true
                    controller.lastSpeechFallbackMessage = "Your ElevenLabs credits are exhausted right now, so Clicky is using its built-in voice for system messages and System Speech for spoken fallback."
                }
                if ClickySpeechProviderCoordinator.isLikelyUnauthorized(error) {
                    controller.isElevenLabsAPIKeyRejected = true
                    controller.lastSpeechFallbackMessage = "Your ElevenLabs API key was rejected, so Clicky will use backup voices until you update it."
                }
                ClickyLogger.error(
                    .audio,
                    "speech-playback failed purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=ElevenLabs source=user-key voiceName=\(selectedVoiceName) error=\(error.localizedDescription)"
                )
            }
        }

        if !controller.isElevenLabsBackendVoiceUnavailable {
            do {
                try await ttsClient.speakTextViaProxy(
                    text,
                    voicePreset: voicePresetProvider()
                )
                if controller.lastSpeechFallbackMessage == nil {
                    controller.lastSpeechFallbackMessage = "Clicky is handling system voice messages with its built-in ElevenLabs voice right now."
                }
                ClickyLogger.notice(
                    .audio,
                    "speech-playback success purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=ElevenLabs source=clicky-backend"
                )
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "ElevenLabs",
                    fallbackMessage: controller.lastSpeechFallbackMessage,
                    encounteredElevenLabsFailure: false
                )
            } catch {
                if ClickySpeechProviderCoordinator.isLikelyVoiceMissing(error) {
                    controller.isElevenLabsBackendVoiceUnavailable = true
                    controller.lastSpeechFallbackMessage = "Clicky's backup ElevenLabs voice is unavailable right now, so it is using System Speech for system messages."
                }
                ClickyLogger.error(
                    .audio,
                    "speech-playback failed purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=ElevenLabs source=clicky-backend error=\(error.localizedDescription)"
                )
            }
        }

        do {
            try await ttsClient.speakText(
                text,
                voicePreset: voicePresetProvider(),
                outputMode: .system
            )
            let fallbackMessage = controller.lastSpeechFallbackMessage ?? "Clicky is using System Speech for now."
            controller.lastSpeechFallbackMessage = fallbackMessage
            ClickyLogger.notice(
                .audio,
                "speech-playback fallback purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=System Speech"
            )
            return ClickySpeechPlaybackOutcome(
                finalProviderDisplayName: "System Speech",
                fallbackMessage: fallbackMessage,
                encounteredElevenLabsFailure: true
            )
        } catch {
            let failureMessage = "Clicky could not play this system message. \(error.localizedDescription)"
            controller.lastSpeechFallbackMessage = failureMessage
            ClickyLogger.error(
                .audio,
                "speech-playback failed purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=System Speech error=\(error.localizedDescription)"
            )
            return ClickySpeechPlaybackOutcome(
                finalProviderDisplayName: "Unavailable",
                fallbackMessage: failureMessage,
                encounteredElevenLabsFailure: true
            )
        }
    }
}
