//
//  BuddyTranscriptionProvider.swift
//  leanring-buddy
//
//  Shared protocol surface for voice transcription backends.
//

import AVFoundation
import Foundation
import OSLog

protocol BuddyStreamingTranscriptionSession: AnyObject {
    var finalTranscriptFallbackDelaySeconds: TimeInterval { get }
    func appendAudioBuffer(_ audioBuffer: AVAudioPCMBuffer)
    func requestFinalTranscript()
    func cancel()
}

protocol BuddyTranscriptionProvider {
    var displayName: String { get }
    var requiresSpeechRecognitionPermission: Bool { get }
    var isConfigured: Bool { get }
    var unavailableExplanation: String? { get }

    func startStreamingSession(
        keyterms: [String],
        onTranscriptUpdate: @escaping (String) -> Void,
        onFinalTranscriptReady: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) async throws -> any BuddyStreamingTranscriptionSession
}

enum BuddyTranscriptionProviderFactory {
    private enum PreferredProvider: String {
        case assemblyAI = "assemblyai"
        case openAI = "openai"
        case appleSpeech = "apple"
    }

    private struct Resolution {
        let provider: any BuddyTranscriptionProvider
        let reason: String
        let didFallback: Bool
    }

    static func makeDefaultProvider() -> any BuddyTranscriptionProvider {
        let resolution = resolveProvider()
        ClickyUnifiedTelemetry.voiceRouting.info(
            "Transcription provider resolved provider=\(resolution.provider.displayName, privacy: .public) reason=\(resolution.reason, privacy: .public) fallback=\(resolution.didFallback ? "true" : "false", privacy: .public)"
        )
        return resolution.provider
    }

    private static func resolveProvider() -> Resolution {
        let preferredProviderRawValue = AppBundleConfiguration
            .stringValue(forKey: "VoiceTranscriptionProvider")?
            .lowercased()
        let preferredProvider = preferredProviderRawValue.flatMap(PreferredProvider.init(rawValue:))

        let assemblyAIProvider = AssemblyAIStreamingTranscriptionProvider()
        let openAIProvider = OpenAIAudioTranscriptionProvider()

        if preferredProvider == .appleSpeech {
            return Resolution(
                provider: AppleSpeechTranscriptionProvider(),
                reason: "preferred-apple-speech",
                didFallback: false
            )
        }

        if preferredProvider == .assemblyAI {
            if assemblyAIProvider.isConfigured {
                return Resolution(
                    provider: assemblyAIProvider,
                    reason: "preferred-assemblyai",
                    didFallback: false
                )
            }

            if openAIProvider.isConfigured {
                return Resolution(
                    provider: openAIProvider,
                    reason: "preferred-assemblyai-unavailable",
                    didFallback: true
                )
            }

            return Resolution(
                provider: AppleSpeechTranscriptionProvider(),
                reason: "preferred-assemblyai-unavailable",
                didFallback: true
            )
        }

        if preferredProvider == .openAI {
            if openAIProvider.isConfigured {
                return Resolution(
                    provider: openAIProvider,
                    reason: "preferred-openai",
                    didFallback: false
                )
            }

            if assemblyAIProvider.isConfigured {
                return Resolution(
                    provider: assemblyAIProvider,
                    reason: "preferred-openai-unavailable",
                    didFallback: true
                )
            }

            return Resolution(
                provider: AppleSpeechTranscriptionProvider(),
                reason: "preferred-openai-unavailable",
                didFallback: true
            )
        }

        if assemblyAIProvider.isConfigured {
            return Resolution(
                provider: assemblyAIProvider,
                reason: "default-worker-configured",
                didFallback: false
            )
        }

        if openAIProvider.isConfigured {
            return Resolution(
                provider: openAIProvider,
                reason: "default-openai-configured",
                didFallback: false
            )
        }

        return Resolution(
            provider: AppleSpeechTranscriptionProvider(),
            reason: "default-local-fallback",
            didFallback: true
        )
    }
}
