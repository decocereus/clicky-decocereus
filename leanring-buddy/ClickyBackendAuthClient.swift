//
//  ClickyBackendAuthClient.swift
//  leanring-buddy
//
//  Launch auth client for the Clicky backend.
//

import Foundation

struct ClickyBackendNativeAuthStartPayload: Decodable {
    let state: String
    let browserURL: String
    let callbackURL: String
    let expiresAt: String
    let returnScheme: String

    private enum CodingKeys: String, CodingKey {
        case state
        case browserURL = "browserUrl"
        case callbackURL = "callbackUrl"
        case expiresAt
        case returnScheme
    }
}

struct ClickyBackendSessionUserPayload: Decodable {
    let id: String
    let email: String
}

struct ClickyBackendSessionPayload: Decodable {
    let user: ClickyBackendSessionUserPayload
}

struct ClickyBackendNativeAuthExchangePayload: Decodable {
    let tokenType: String
    let sessionToken: String
    let userID: String

    private enum CodingKeys: String, CodingKey {
        case tokenType
        case sessionToken
        case userID = "userId"
    }
}

enum ClickyBackendAuthClientError: LocalizedError {
    case backendNotConfigured
    case invalidBackendURL
    case invalidResponse
    case missingExchangeCode
    case unexpectedStatus(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "Configure the Clicky backend URL before signing in."
        case .invalidBackendURL:
            return "The Clicky backend URL is invalid."
        case .invalidResponse:
            return "The Clicky backend returned an invalid response."
        case .missingExchangeCode:
            return "The auth callback did not include an exchange code."
        case let .unexpectedStatus(code, message):
            return "Clicky backend request failed (\(code)): \(message)"
        }
    }
}

struct ClickyBackendAuthClient {
    let baseURL: String

    private let session: URLSession = .shared

    private var normalizedBaseURL: String? {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty else { return nil }
        return trimmedBaseURL.hasSuffix("/") ? String(trimmedBaseURL.dropLast()) : trimmedBaseURL
    }

    private func endpointURL(path: String) throws -> URL {
        guard let normalizedBaseURL else {
            throw ClickyBackendAuthClientError.backendNotConfigured
        }

        guard let url = URL(string: normalizedBaseURL + path) else {
            throw ClickyBackendAuthClientError.invalidBackendURL
        }

        return url
    }

    func startNativeSignIn() async throws -> ClickyBackendNativeAuthStartPayload {
        var components = URLComponents(url: try endpointURL(path: "/v1/auth/native/start"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "mode", value: "json")
        ]

        guard let url = components?.url else {
            throw ClickyBackendAuthClientError.invalidBackendURL
        }

        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ClickyBackendNativeAuthStartPayload.self, from: data)
    }

    func exchangeNativeCode(_ code: String) async throws -> ClickyBackendNativeAuthExchangePayload {
        var request = URLRequest(url: try endpointURL(path: "/v1/auth/native/exchange"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["code": code])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ClickyBackendNativeAuthExchangePayload.self, from: data)
    }

    func fetchCurrentSession(sessionToken: String) async throws -> ClickyBackendSessionPayload {
        var request = URLRequest(url: try endpointURL(path: "/v1/me"))
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ClickyBackendSessionPayload.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClickyBackendAuthClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClickyBackendAuthClientError.unexpectedStatus(code: httpResponse.statusCode, message: responseMessage)
        }
    }
}
