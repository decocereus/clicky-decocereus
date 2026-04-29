//
//  ClickySpeechProviderCoordinator.swift
//  leanring-buddy
//
//  Manages speech provider settings, ElevenLabs voices, and preview state.
//

import Foundation

@MainActor
final class ClickySpeechProviderCoordinator {
    static let previewSampleText = "hey, this is clicky. here is how your current voice sounds."

    private let preferences: ClickyPreferencesStore
    private let controller: ClickySpeechProviderController
    private let stopPlayback: @MainActor () -> Void
    private let playPreview: @MainActor (String) async -> ClickySpeechPlaybackOutcome

    init(
        preferences: ClickyPreferencesStore,
        controller: ClickySpeechProviderController,
        stopPlayback: @escaping @MainActor () -> Void,
        playPreview: @escaping @MainActor (String) async -> ClickySpeechPlaybackOutcome
    ) {
        self.preferences = preferences
        self.controller = controller
        self.stopPlayback = stopPlayback
        self.playPreview = playPreview
    }

    var hasStoredElevenLabsAPIKey: Bool {
        !(ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var effectiveVoiceOutputDisplayName: String {
        switch effectiveSpeechRouting.outputMode {
        case .system:
            return "System Speech · \(preferences.clickyVoicePreset.displayName)"
        case .elevenLabsBYO:
            let label = effectiveSpeechRouting.selectedVoiceNameLabel
            return "ElevenLabs · \(label)"
        }
    }

    var effectiveSpeechRouting: ClickySpeechRouting {
        let selectedVoiceID = preferences.elevenLabsSelectedVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedVoiceName = preferences.elevenLabsSelectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)

        switch preferences.clickySpeechProviderMode {
        case .system:
            return ClickySpeechRouting(
                selectedProvider: .system,
                outputMode: .system,
                selectedVoiceID: selectedVoiceID,
                selectedVoiceName: selectedVoiceName,
                configurationFallbackMessage: nil
            )
        case .elevenLabsBYO:
            let apiKey = (ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if apiKey.isEmpty {
                return ClickySpeechRouting(
                    selectedProvider: .elevenLabsBYO,
                    outputMode: .system,
                    selectedVoiceID: selectedVoiceID,
                    selectedVoiceName: selectedVoiceName,
                    configurationFallbackMessage: "Add your ElevenLabs API key. Clicky stores it only in Keychain on this Mac."
                )
            }

            if selectedVoiceID.isEmpty {
                let message: String
                if case .loaded = controller.elevenLabsVoiceFetchStatus, controller.elevenLabsAvailableVoices.isEmpty {
                    message = "This ElevenLabs account does not have any voices available yet."
                } else {
                    message = "Load voices and choose the one you want Clicky to use."
                }

                return ClickySpeechRouting(
                    selectedProvider: .elevenLabsBYO,
                    outputMode: .system,
                    selectedVoiceID: selectedVoiceID,
                    selectedVoiceName: selectedVoiceName,
                    configurationFallbackMessage: message
                )
            }

            if controller.isElevenLabsCreditExhausted {
                return ClickySpeechRouting(
                    selectedProvider: .elevenLabsBYO,
                    outputMode: .system,
                    selectedVoiceID: selectedVoiceID,
                    selectedVoiceName: selectedVoiceName,
                    configurationFallbackMessage: "Your ElevenLabs credits are exhausted right now, so Clicky is using System Speech until you top up or switch voices."
                )
            }

            return ClickySpeechRouting(
                selectedProvider: .elevenLabsBYO,
                outputMode: .elevenLabsBYO(ElevenLabsDirectConfiguration(apiKey: apiKey, voiceID: selectedVoiceID)),
                selectedVoiceID: selectedVoiceID,
                selectedVoiceName: selectedVoiceName,
                configurationFallbackMessage: nil
            )
        }
    }

    var speechFallbackSummary: String? {
        if let lastSpeechFallbackMessage = controller.lastSpeechFallbackMessage {
            return lastSpeechFallbackMessage
        }

        guard let configurationFallbackMessage = effectiveSpeechRouting.configurationFallbackMessage else {
            return nil
        }

        return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. \(configurationFallbackMessage)"
    }

    var speechPreviewStatusLabel: String {
        switch controller.speechPreviewStatus {
        case .idle:
            return "Preview ready"
        case .previewing:
            return "Playing preview"
        case .succeeded:
            return "Preview played"
        case .failed:
            return "Preview failed"
        }
    }

    var speechPreviewStatusMessage: String? {
        switch controller.speechPreviewStatus {
        case .idle:
            return nil
        case .previewing:
            return "Clicky is playing the current voice sample now."
        case .succeeded(let message), .failed(let message):
            return message
        }
    }

    var isSpeechPreviewInFlight: Bool {
        if case .previewing = controller.speechPreviewStatus {
            return true
        }

        return false
    }

    func setProviderMode(_ mode: ClickySpeechProviderMode) {
        guard preferences.clickySpeechProviderMode != mode else { return }
        preferences.clickySpeechProviderMode = mode
        ClickyLogger.notice(.audio, "Speech provider selected provider=\(mode.displayName)")

        Task { @MainActor [weak self] in
            guard let self else { return }
            controller.speechPreviewStatus = .idle
            controller.lastSpeechFallbackMessage = nil

            if mode == .system {
                resetRuntimeFailureFlags()
            } else if hasStoredElevenLabsAPIKey && controller.elevenLabsAvailableVoices.isEmpty {
                refreshVoices()
            }
        }
    }

    func saveAPIKey() {
        let trimmedAPIKey = controller.elevenLabsAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        resetPreviewAndFailures()

        if trimmedAPIKey.isEmpty {
            ClickySecrets.delete(account: "elevenlabs_api_key")
            controller.elevenLabsAvailableVoices = []
            controller.elevenLabsVoiceFetchStatus = .idle
            controller.elevenLabsVoiceImportStatus = .idle
            preferences.elevenLabsSelectedVoiceID = ""
            preferences.elevenLabsSelectedVoiceName = ""
            preferences.clickySpeechProviderMode = .system
            ClickyLogger.notice(.audio, "Removed ElevenLabs API key from local Keychain storage")
            return
        }

        do {
            try ClickySecrets.save(key: trimmedAPIKey, account: "elevenlabs_api_key")
            controller.elevenLabsVoiceFetchStatus = .idle
            controller.elevenLabsVoiceImportStatus = .idle
            ClickyLogger.notice(.audio, "Saved ElevenLabs API key to local Keychain storage")
        } catch {
            controller.elevenLabsVoiceFetchStatus = .failed(message: "Could not save API key")
            ClickyLogger.error(.audio, "Failed to save ElevenLabs API key locally error=\(error.localizedDescription)")
        }
    }

    func deleteAPIKey() {
        controller.elevenLabsAPIKeyDraft = ""
        saveAPIKey()
    }

    func refreshVoices() {
        let apiKey = (ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            controller.elevenLabsVoiceFetchStatus = .failed(message: "Add an API key first")
            ClickyLogger.error(.audio, "Voice refresh blocked because no ElevenLabs API key is saved locally")
            return
        }

        controller.elevenLabsVoiceFetchStatus = .loading
        controller.elevenLabsVoiceImportStatus = .idle
        resetPreviewAndFailures()
        ClickyLogger.info(.audio, "Refreshing ElevenLabs voice list")

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let voices = try await ElevenLabsService.fetchVoices(apiKey: apiKey)
                controller.elevenLabsAvailableVoices = voices
                controller.elevenLabsVoiceFetchStatus = .loaded

                if voices.isEmpty {
                    preferences.elevenLabsSelectedVoiceID = ""
                    preferences.elevenLabsSelectedVoiceName = ""
                    ClickyLogger.notice(.audio, "ElevenLabs voice refresh succeeded with zero available voices")
                } else if preferences.elevenLabsSelectedVoiceID.isEmpty, let firstVoice = voices.first {
                    preferences.elevenLabsSelectedVoiceID = firstVoice.id
                    preferences.elevenLabsSelectedVoiceName = firstVoice.name
                } else if let selectedVoice = voices.first(where: { $0.id == self.preferences.elevenLabsSelectedVoiceID }) {
                    preferences.elevenLabsSelectedVoiceName = selectedVoice.name
                } else if let firstVoice = voices.first {
                    preferences.elevenLabsSelectedVoiceID = firstVoice.id
                    preferences.elevenLabsSelectedVoiceName = firstVoice.name
                }

                ClickyLogger.notice(.audio, "ElevenLabs voice refresh succeeded count=\(voices.count)")
            } catch {
                controller.elevenLabsVoiceFetchStatus = .failed(message: error.localizedDescription)
                ClickyLogger.error(.audio, "ElevenLabs voice refresh failed error=\(error.localizedDescription)")
            }
        }
    }

    func selectVoice(_ voice: ElevenLabsVoiceOption) {
        preferences.elevenLabsSelectedVoiceID = voice.id
        preferences.elevenLabsSelectedVoiceName = voice.name
        controller.elevenLabsImportVoiceIDDraft = voice.id
        resetPreviewAndFailures()
        ClickyLogger.notice(.audio, "Selected ElevenLabs voice name=\(voice.name) id=\(voice.id)")
    }

    func importVoiceByID() {
        let apiKey = (ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            controller.elevenLabsVoiceImportStatus = .failed(message: "Save your ElevenLabs API key first.")
            ClickyLogger.error(.audio, "Voice import blocked because no ElevenLabs API key is saved locally")
            return
        }

        let voiceID = controller.elevenLabsImportVoiceIDDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !voiceID.isEmpty else {
            controller.elevenLabsVoiceImportStatus = .failed(message: "Paste a voice ID first.")
            return
        }

        controller.elevenLabsVoiceImportStatus = .importing
        ClickyLogger.info(.audio, "Importing ElevenLabs voice by id=\(voiceID)")

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let importedVoice = try await ElevenLabsService.fetchVoice(apiKey: apiKey, voiceID: voiceID)
                upsertVoice(importedVoice)
                controller.elevenLabsVoiceFetchStatus = .loaded
                selectVoice(importedVoice)
                controller.elevenLabsVoiceImportStatus = .succeeded(message: "Imported \(importedVoice.name).")
                ClickyLogger.notice(.audio, "Imported ElevenLabs voice name=\(importedVoice.name) id=\(importedVoice.id)")
            } catch {
                controller.elevenLabsVoiceImportStatus = .failed(message: error.localizedDescription)
                ClickyLogger.error(.audio, "Failed to import ElevenLabs voice id=\(voiceID) error=\(error.localizedDescription)")
            }
        }
    }

    func previewCurrentOutput() {
        if case .previewing = controller.speechPreviewStatus {
            return
        }

        controller.speechPreviewStatus = .previewing
        stopPlayback()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await playPreview(Self.previewSampleText)

            if outcome.finalProviderDisplayName == "Unavailable" {
                controller.speechPreviewStatus = .failed(
                    message: outcome.fallbackMessage ?? "Clicky could not play the preview."
                )
                return
            }

            if let fallbackMessage = outcome.fallbackMessage {
                controller.speechPreviewStatus = .succeeded(message: fallbackMessage)
                return
            }

            controller.speechPreviewStatus = .succeeded(
                message: "Preview played through \(outcome.finalProviderDisplayName)."
            )
        }
    }

    func upsertVoice(_ voice: ElevenLabsVoiceOption) {
        var voicesByID: [String: ElevenLabsVoiceOption] = [:]
        for existingVoice in controller.elevenLabsAvailableVoices {
            voicesByID[existingVoice.id] = existingVoice
        }
        voicesByID[voice.id] = voice

        let otherVoices = voicesByID.values
            .filter { $0.id != voice.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        controller.elevenLabsAvailableVoices = [voice] + otherVoices
    }

    func resetPreviewAndFailures() {
        controller.speechPreviewStatus = .idle
        controller.lastSpeechFallbackMessage = nil
        resetRuntimeFailureFlags()
    }

    func resetRuntimeFailureFlags() {
        controller.isElevenLabsCreditExhausted = false
        controller.isElevenLabsAPIKeyRejected = false
        controller.isElevenLabsBackendVoiceUnavailable = false
    }

    static func isLikelyCreditExhaustion(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("credit")
            || message.contains("credits")
            || message.contains("balance")
            || message.contains("quota")
            || message.contains("insufficient")
    }

    static func isLikelyUnauthorized(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("api key was rejected")
            || message.contains("unauthorized")
            || message.contains("401")
    }

    static func isLikelyVoiceMissing(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("voice could not be found")
            || message.contains("voice not be found")
            || message.contains("voice not found")
            || message.contains("404")
    }
}
