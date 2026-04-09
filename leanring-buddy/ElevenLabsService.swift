//
//  ElevenLabsService.swift
//  leanring-buddy
//
//  Local-first ElevenLabs BYO API integration for listing voices and direct TTS.
//

import Foundation

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
            throw NSError(domain: "ElevenLabsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid ElevenLabs response"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown ElevenLabs error"
            throw NSError(
                domain: "ElevenLabsService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "ElevenLabs voices error (\(httpResponse.statusCode)): \(errorBody)"]
            )
        }

        let decodedResponse = try JSONDecoder().decode(ElevenLabsVoicesResponse.self, from: data)
        return decodedResponse.voices.map { voice in
            ElevenLabsVoiceOption(
                id: voice.voiceID,
                name: voice.name,
                category: voice.category,
                previewURL: voice.previewURL.flatMap(URL.init(string:))
            )
        }
    }

    private struct ElevenLabsVoicesResponse: Decodable {
        let voices: [ElevenLabsVoice]
    }

    private struct ElevenLabsVoice: Decodable {
        let voiceID: String
        let name: String
        let category: String?
        let previewURL: String?

        enum CodingKeys: String, CodingKey {
            case voiceID = "voice_id"
            case name
            case category
            case previewURL = "preview_url"
        }
    }
}
