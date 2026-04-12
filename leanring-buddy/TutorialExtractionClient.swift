//
//  TutorialExtractionClient.swift
//  leanring-buddy
//
//  Thin client for Clicky's external tutorial extraction dependency.
//

import Foundation

struct TutorialExtractionStartResponse: Decodable, Sendable {
    let jobID: String
    let videoID: String
    let status: String

    private enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case videoID = "video_id"
        case status
    }
}

struct TutorialExtractionJobSnapshot: Decodable, Sendable {
    let id: String
    let videoID: String
    let url: String
    let status: String
    let stage: String
    let progress: Int
    let error: String?
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case videoID = "video_id"
        case url
        case status
        case stage
        case progress
        case error
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
    }
}

enum TutorialExtractionClientError: LocalizedError {
    case extractorNotConfigured
    case invalidExtractorBaseURL
    case missingSession
    case invalidResponse
    case unexpectedStatus(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .extractorNotConfigured:
            return "Configure the Clicky backend URL before importing tutorials."
        case .invalidExtractorBaseURL:
            return "The Clicky backend URL is invalid."
        case .missingSession:
            return "Sign in before importing tutorials."
        case .invalidResponse:
            return "The tutorial extraction service returned an invalid response."
        case let .unexpectedStatus(code, message):
            return "Tutorial extraction request failed (\(code)): \(message)"
        }
    }
}

struct TutorialExtractionClient {
    let baseURL: String
    let sessionToken: String
    let session: URLSession

    init(
        baseURL: String,
        sessionToken: String,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.sessionToken = sessionToken
        self.session = session
    }

    private var normalizedBaseURL: String? {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else { return nil }
        return trimmedBaseURL.hasSuffix("/") ? String(trimmedBaseURL.dropLast()) : trimmedBaseURL
    }

    private func endpointURL(path: String) throws -> URL {
        guard let normalizedBaseURL else {
            throw TutorialExtractionClientError.extractorNotConfigured
        }

        guard let url = URL(string: normalizedBaseURL + path) else {
            throw TutorialExtractionClientError.invalidExtractorBaseURL
        }

        return url
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func authorizedRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) throws -> URLRequest {
        let trimmedSessionToken = sessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSessionToken.isEmpty else {
            throw TutorialExtractionClientError.missingSession
        }

        var request = URLRequest(url: try endpointURL(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(trimmedSessionToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    func startExtraction(
        sourceURL: String,
        language: String = "en",
        maxFrames: Int = 8
    ) async throws -> TutorialExtractionStartResponse {
        let payload = StartExtractionRequest(url: sourceURL, language: language, maxFrames: maxFrames)
        let body = try JSONEncoder().encode(payload)
        let request = try authorizedRequest(path: "/v1/tutorials/extract", method: "POST", body: body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try makeDecoder().decode(TutorialExtractionStartResponse.self, from: data)
    }

    func fetchJob(jobID: String) async throws -> TutorialExtractionJobSnapshot {
        let request = try authorizedRequest(path: "/v1/tutorials/extract/\(jobID)")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try makeDecoder().decode(TutorialExtractionJobSnapshot.self, from: data)
    }

    func fetchEvidence(videoID: String) async throws -> TutorialEvidenceBundle {
        let request = try authorizedRequest(path: "/v1/tutorials/evidence/\(videoID)")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try makeDecoder().decode(TutorialEvidenceBundle.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TutorialExtractionClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TutorialExtractionClientError.unexpectedStatus(
                code: httpResponse.statusCode,
                message: message
            )
        }
    }
}

private struct StartExtractionRequest: Encodable {
    let url: String
    let language: String
    let maxFrames: Int

    private enum CodingKeys: String, CodingKey {
        case url
        case language
        case maxFrames = "max_frames"
    }
}
