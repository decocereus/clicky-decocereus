//
//  ElevenLabsService.swift
//  leanring-buddy
//
//  Local-first ElevenLabs BYO API integration for listing voices and direct TTS.
//

import Foundation

enum ElevenLabsErrorContext {
    case voices
    case voice
    case tts
}

struct ElevenLabsVoiceOption: Identifiable, Equatable {
    let id: String
    let name: String
    let category: String?
    let previewURL: URL?

    var displaySubtitle: String {
        category ?? "Voice"
    }
}

enum ClickySpeechProviderMode: String, CaseIterable, Identifiable {
    case system
    case elevenLabsBYO

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .elevenLabsBYO:
            return "ElevenLabs"
        }
    }
}

struct ElevenLabsDirectConfiguration {
    let apiKey: String
    let voiceID: String
}

enum ElevenLabsService {
    private static let baseURL = URL(string: "https://api.elevenlabs.io/v1")!

    static func fetchVoices(apiKey: String) async throws -> [ElevenLabsVoiceOption] {
        var request = URLRequest(url: baseURL.appendingPathComponent("voices"))
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ElevenLabsService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Clicky could not read the ElevenLabs voice list response."]
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown ElevenLabs error"
            throw NSError(
                domain: "ElevenLabsService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: userFacingErrorMessage(statusCode: httpResponse.statusCode, errorBody: errorBody, context: .voices)]
            )
        }

        let decodedResponse = try JSONDecoder().decode(ElevenLabsVoicesResponse.self, from: data)
        return decodedResponse.voices.map { voice in
            voice.option
        }
    }

    static func fetchVoice(apiKey: String, voiceID: String) async throws -> ElevenLabsVoiceOption {
        var request = URLRequest(url: baseURL.appendingPathComponent("voices").appendingPathComponent(voiceID))
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ElevenLabsService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Clicky could not read the ElevenLabs voice response."]
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown ElevenLabs error"
            throw NSError(
                domain: "ElevenLabsService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: userFacingErrorMessage(statusCode: httpResponse.statusCode, errorBody: errorBody, context: .voice)]
            )
        }

        let decodedVoice = try JSONDecoder().decode(ElevenLabsVoice.self, from: data)
        return decodedVoice.option
    }

    private struct ElevenLabsVoicesResponse: Decodable {
        let voices: [ElevenLabsVoice]
    }

    private struct ElevenLabsVoice: Decodable {
        let voiceID: String
        let name: String
        let category: String?
        let previewURL: String?

        var option: ElevenLabsVoiceOption {
            ElevenLabsVoiceOption(
                id: voiceID,
                name: name,
                category: category,
                previewURL: previewURL.flatMap(URL.init(string:))
            )
        }

        enum CodingKeys: String, CodingKey {
            case voiceID = "voice_id"
            case name
            case category
            case previewURL = "preview_url"
        }
    }

    static func userFacingErrorMessage(
        statusCode: Int,
        errorBody: String,
        context: ElevenLabsErrorContext
    ) -> String {
        switch statusCode {
        case 401:
            return "Your ElevenLabs API key was rejected. Update it and try again."
        case 403:
            switch context {
            case .voices:
                return "This ElevenLabs account cannot access those voices through the API. Voice Library and shared custom voices require a subscriber account."
            case .voice:
                return "This voice is not available to this ElevenLabs account yet. Shared and custom voices require a subscriber account, and shared voices usually need to be added to My Voices first."
            case .tts:
                return "This ElevenLabs voice is not available for synthesis on this account. Shared and custom voices require a subscriber account, and the voice may need to be added to My Voices first."
            }
        case 404:
            switch context {
            case .voices:
                return "ElevenLabs could not find the voice list for this account."
            case .voice:
                return "Clicky could not find that ElevenLabs voice ID. If it is a shared or custom voice, make sure it belongs to this account or has been added to My Voices first."
            case .tts:
                return "That ElevenLabs voice could not be found. Load voices again and choose another one."
            }
        case 429:
            return "ElevenLabs is rate limiting requests right now. Try again in a moment."
        case 500...599:
            return "ElevenLabs is having trouble right now. Try again in a moment."
        default:
            let trimmedBody = errorBody.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedBody.isEmpty || trimmedBody == "Unknown ElevenLabs error" {
                return "ElevenLabs returned an unexpected error (\(statusCode))."
            }

            return "ElevenLabs returned an error (\(statusCode)). \(trimmedBody)"
        }
    }
}
