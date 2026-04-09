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
    func speakText(_ text: String, voicePreset: ClickyVoicePreset = .balanced) async throws {
        if !CompanionRuntimeConfiguration.isWorkerConfigured {
            await speakTextWithSystemSpeech(text, voicePreset: voicePreset)
            return
        }

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
            throw NSError(domain: "ElevenLabsTTS", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ElevenLabsTTS", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "TTS API error (\(httpResponse.statusCode)): \(errorBody)"])
        }

        try Task.checkCancellation()

        let player = try AVAudioPlayer(data: data)
        self.audioPlayer = player
        player.play()
        print("🔊 ElevenLabs TTS: playing \(data.count / 1024)KB audio")
    }

    private func speakTextWithSystemSpeech(_ text: String, voicePreset: ClickyVoicePreset) async {
        let speechSynthesizer = NSSpeechSynthesizer()
        let systemSpeechDelegate = SystemSpeechDelegate()

        self.systemSpeechSynthesizer = speechSynthesizer
        self.systemSpeechDelegate = systemSpeechDelegate
        speechSynthesizer.delegate = systemSpeechDelegate
        speechSynthesizer.rate = voicePreset.systemSpeechRate
        speechSynthesizer.startSpeaking(text)
        print("🔊 System TTS: speaking local fallback audio")

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
