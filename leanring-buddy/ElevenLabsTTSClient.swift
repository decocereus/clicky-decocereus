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
    private var systemSpeechSynthesizer: NSSpeechSynthesizer?
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
        let speechSynthesizer = NSSpeechSynthesizer()
        let systemSpeechDelegate = SystemSpeechDelegate()

        self.systemSpeechSynthesizer = speechSynthesizer
        self.systemSpeechDelegate = systemSpeechDelegate
        speechSynthesizer.delegate = systemSpeechDelegate
        speechSynthesizer.rate = voicePreset.systemSpeechRate
        guard speechSynthesizer.startSpeaking(text) else {
            throw NSError(
                domain: "SystemSpeechTTS",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "macOS could not start system speech playback."]
            )
        }
        ClickyLogger.debug(.audio, "System speech started rate=\(Int(voicePreset.systemSpeechRate))")

        await systemSpeechDelegate.waitUntilFinishedSpeaking()

        if self.systemSpeechSynthesizer === speechSynthesizer {
            self.systemSpeechSynthesizer = nil
            self.systemSpeechDelegate = nil
        }
    }

    /// Whether TTS audio is currently playing back.
    var isPlaying: Bool {
        (audioPlayer?.isPlaying ?? false) || (systemSpeechSynthesizer?.isSpeaking ?? false)
    }

    /// Stops any in-progress playback immediately.
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        systemSpeechSynthesizer?.stopSpeaking()
        systemSpeechDelegate?.cancel()
        systemSpeechSynthesizer = nil
        systemSpeechDelegate = nil
        ClickyLogger.debug(.audio, "Stopped active speech playback")
    }
}

@MainActor
private final class SystemSpeechDelegate: NSObject, NSSpeechSynthesizerDelegate {
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

    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        finishedSpeakingContinuation?.resume()
        finishedSpeakingContinuation = nil
    }
}
