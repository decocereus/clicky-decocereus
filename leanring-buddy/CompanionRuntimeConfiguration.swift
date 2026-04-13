//
//  CompanionRuntimeConfiguration.swift
//  leanring-buddy
//
//  Shared runtime configuration for worker-backed services and local fallbacks.
//

import Foundation

enum CompanionRuntimeConfiguration {
    private static let placeholderWorkerBaseURL = "https://your-worker-name.your-subdomain.workers.dev"
    private static let workerBaseURLInfoPlistKey = "CompanionWorkerBaseURL"
    private static let placeholderBackendBaseURL = "https://backend.clickyhq.com"
    private static let backendBaseURLInfoPlistKey = "ClickyBackendBaseURL"
    private static let placeholderTutorialExtractorBaseURL = "https://tutorial-extractor.example.com"
    private static let tutorialExtractorBaseURLInfoPlistKey = "ClickyTutorialExtractorBaseURL"

    static var workerBaseURL: String {
        AppBundleConfiguration.stringValue(forKey: workerBaseURLInfoPlistKey) ?? placeholderWorkerBaseURL
    }

    static var defaultBackendBaseURL: String {
        AppBundleConfiguration.stringValue(forKey: backendBaseURLInfoPlistKey) ?? placeholderBackendBaseURL
    }

    private static var currentBackendBaseURL: String {
        let storedBackendBaseURL = UserDefaults.standard
            .string(forKey: "clickyBackendBaseURL")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !storedBackendBaseURL.isEmpty {
            return storedBackendBaseURL.hasSuffix("/")
                ? String(storedBackendBaseURL.dropLast())
                : storedBackendBaseURL
        }

        let trimmedDefaultBackendBaseURL = defaultBackendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDefaultBackendBaseURL.hasSuffix("/")
            ? String(trimmedDefaultBackendBaseURL.dropLast())
            : trimmedDefaultBackendBaseURL
    }

    static var tutorialExtractorBaseURL: String {
        AppBundleConfiguration.stringValue(forKey: tutorialExtractorBaseURLInfoPlistKey) ?? placeholderTutorialExtractorBaseURL
    }

    static var isWorkerConfigured: Bool {
        let normalizedWorkerBaseURL = workerBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedWorkerBaseURL.isEmpty else { return false }
        return normalizedWorkerBaseURL != placeholderWorkerBaseURL
    }

    static var isBackendConfigured: Bool {
        let normalizedBackendBaseURL = currentBackendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBackendBaseURL.isEmpty else { return false }
        return normalizedBackendBaseURL != placeholderBackendBaseURL
    }

    static var isTutorialExtractorConfigured: Bool {
        let normalizedTutorialExtractorBaseURL = tutorialExtractorBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTutorialExtractorBaseURL.isEmpty else { return false }
        return normalizedTutorialExtractorBaseURL != placeholderTutorialExtractorBaseURL
    }

    static var assemblyAITokenProxyURL: String {
        "\(currentBackendBaseURL)/v1/transcription/assemblyai-token"
    }
}
