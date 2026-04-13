//
//  ClickySpeechProviderController.swift
//  leanring-buddy
//
//  Observable display and transient state for speech provider configuration.
//

import Combine
import Foundation

@MainActor
final class ClickySpeechProviderController: ObservableObject {
    @Published var elevenLabsAPIKeyDraft: String = ClickySecrets.load(account: "elevenlabs_api_key") ?? ""
    @Published var elevenLabsImportVoiceIDDraft: String = ""
    @Published var elevenLabsAvailableVoices: [ElevenLabsVoiceOption] = []
    @Published var elevenLabsVoiceFetchStatus: ElevenLabsVoiceFetchStatus = .idle
    @Published var elevenLabsVoiceImportStatus: ElevenLabsVoiceImportStatus = .idle
    @Published var speechPreviewStatus: ClickySpeechPreviewStatus = .idle
    @Published var lastSpeechFallbackMessage: String?
    @Published var isElevenLabsCreditExhausted = false
    @Published var isElevenLabsAPIKeyRejected = false
    @Published var isElevenLabsBackendVoiceUnavailable = false
}
