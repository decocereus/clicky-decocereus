//
//  ElevenLabsTTSClient.swift
//  leanring-buddy
//
//  Streams text-to-speech audio from ElevenLabs and plays it back
//  through the system audio output. Uses the streaming endpoint so
//  playback begins before the full audio has been generated.
//

import AppKit
import AVFoundation
import Foundation

@MainActor
final class ElevenLabsTTSClient {
    private let proxyURL: URL
    private let session: URLSession

    /// The audio player for the current TTS playback. Kept alive so the
    /// audio finishes playing even if the caller doesn't hold a reference.
    private var audioPlayer: AVAudioPlayer?
    private let systemSpeechSynthesizer = AVSpeechSynthesizer()
    private var systemSpeechDelegate: SystemSpeechDelegate?

    init(proxyURL: String) {
        self.proxyURL = URL(string: proxyURL)!

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    /// Sends `text` to ElevenLabs TTS and plays the resulting audio.
    /// Throws on network or decoding errors. Cancellation-safe.
    func speakText(
        _ text: String,
        voicePreset: ClickyVoicePreset = .balanced,
        outputMode: ClickySpeechOutputMode = .system
    ) async throws {
        switch outputMode {
        case .system:
            try await speakTextWithSystemSpeech(text, voicePreset: voicePreset)
            return
        case .elevenLabsBYO(let configuration):
            try await speakTextDirectlyWithElevenLabs(text, voicePreset: voicePreset, configuration: configuration)
            return
        }
    }

    private func speakTextDirectlyWithElevenLabs(
        _ text: String,
        voicePreset: ClickyVoicePreset,
        configuration: ElevenLabsDirectConfiguration
    ) async throws {
        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(configuration.voiceID)")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(configuration.apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_flash_v2_5",
            "voice_settings": [
                "stability": voicePreset.elevenLabsStability,
                "similarity_boost": voicePreset.elevenLabsSimilarityBoost
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ElevenLabsTTS",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Clicky could not read the ElevenLabs audio response."]
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "ElevenLabsTTS",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: ElevenLabsService.userFacingErrorMessage(statusCode: httpResponse.statusCode, errorBody: errorBody, context: .tts)]
            )
        }

        try Task.checkCancellation()

        let player = try AVAudioPlayer(data: data)
        self.audioPlayer = player
        player.play()
        ClickyLogger.debug(.audio, "ElevenLabs direct audio prepared sizeKB=\(data.count / 1024)")
    }

    func speakTextViaProxy(_ text: String, voicePreset: ClickyVoicePreset = .balanced) async throws {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_flash_v2_5",
            "voice_settings": [
                "stability": voicePreset.elevenLabsStability,
                "similarity_boost": voicePreset.elevenLabsSimilarityBoost
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ElevenLabsTTS",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Clicky could not read the proxied ElevenLabs audio response."]
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "ElevenLabsTTS",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: ElevenLabsService.userFacingErrorMessage(statusCode: httpResponse.statusCode, errorBody: errorBody, context: .tts)]
            )
        }

        try Task.checkCancellation()

        let player = try AVAudioPlayer(data: data)
        self.audioPlayer = player
        player.play()
        ClickyLogger.debug(.audio, "ElevenLabs proxy audio prepared sizeKB=\(data.count / 1024)")
    }

    private func speakTextWithSystemSpeech(_ text: String, voicePreset: ClickyVoicePreset) async throws {
        let systemSpeechDelegate = SystemSpeechDelegate()

        self.systemSpeechDelegate = systemSpeechDelegate
        systemSpeechSynthesizer.delegate = systemSpeechDelegate
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = voicePreset.avSpeechRate
        utterance.pitchMultiplier = voicePreset.avSpeechPitchMultiplier
        utterance.voice = preferredSystemVoice(for: voicePreset)
        systemSpeechSynthesizer.speak(utterance)
        ClickyLogger.debug(
            .audio,
            "System speech started rate=\(Int(voicePreset.systemSpeechRate)) voice=\(utterance.voice?.name ?? "default")"
        )

        await systemSpeechDelegate.waitUntilFinishedSpeaking()

        if self.systemSpeechDelegate === systemSpeechDelegate {
            systemSpeechSynthesizer.delegate = nil
            self.systemSpeechDelegate = nil
        }
    }

    /// Whether TTS audio is currently playing back.
    var isPlaying: Bool {
        (audioPlayer?.isPlaying ?? false) || systemSpeechSynthesizer.isSpeaking
    }

    /// Stops any in-progress playback immediately.
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        systemSpeechSynthesizer.stopSpeaking(at: .immediate)
        systemSpeechDelegate?.cancel()
        systemSpeechSynthesizer.delegate = nil
        systemSpeechDelegate = nil
        ClickyLogger.debug(.audio, "Stopped active speech playback")
    }

    private func preferredSystemVoice(for voicePreset: ClickyVoicePreset) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        let preferredNames: [String]
        switch voicePreset {
        case .balanced:
            preferredNames = ["Samantha", "Allison", "Ava"]
        case .clear:
            preferredNames = ["Daniel", "Alex", "Nathan", "Tom"]
        case .warm:
            preferredNames = ["Ava", "Samantha", "Allison", "Serena"]
        }

        for preferredName in preferredNames {
            if let voice = voices.first(where: {
                $0.language.hasPrefix("en")
                    && $0.name.localizedCaseInsensitiveContains(preferredName)
            }) {
                return voice
            }
        }

        if let usEnglishVoice = voices.first(where: { $0.language == "en-US" }) {
            return usEnglishVoice
        }

        if let englishVoice = voices.first(where: { $0.language.hasPrefix("en") }) {
            return englishVoice
        }

        return AVSpeechSynthesisVoice(language: "en-US")
    }
}

@MainActor
private final class SystemSpeechDelegate: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
    private var finishedSpeakingContinuation: CheckedContinuation<Void, Never>?

    func waitUntilFinishedSpeaking() async {
        await withCheckedContinuation { continuation in
            finishedSpeakingContinuation = continuation
        }
    }

    func cancel() {
        finishedSpeakingContinuation?.resume()
        finishedSpeakingContinuation = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finishedSpeakingContinuation?.resume()
        finishedSpeakingContinuation = nil
    }
}

private extension ClickyVoicePreset {
    var avSpeechRate: Float {
        let normalized = max(120, min(systemSpeechRate, 260))
        let ratio = (normalized - 120) / 140
        return AVSpeechUtteranceMinimumSpeechRate
            + Float(ratio) * (AVSpeechUtteranceDefaultSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
    }

    var avSpeechPitchMultiplier: Float {
        switch self {
        case .balanced:
            return 1.0
        case .clear:
            return 1.04
        case .warm:
            return 0.94
        }
    }
}
