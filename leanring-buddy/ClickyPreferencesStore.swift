//
//  ClickyPreferencesStore.swift
//  leanring-buddy
//
//  Centralized persistence for user-configurable companion preferences.
//

import Combine
import Foundation

@MainActor
final class ClickyPreferencesStore: ObservableObject {
    private enum Key {
        static let selectedModel = "selectedClaudeModel"
        static let selectedAgentBackend = "selectedCompanionAgentBackend"
        static let openClawGatewayURL = "openClawGatewayURL"
        static let openClawAgentIdentifier = "openClawAgentIdentifier"
        static let openClawAgentName = "openClawAgentName"
        static let openClawGatewayAuthToken = "openClawGatewayAuthToken"
        static let openClawSessionKey = "openClawSessionKey"
        static let clickyPersonaScopeMode = "clickyPersonaScopeMode"
        static let clickyPersonaOverrideName = "clickyPersonaOverrideName"
        static let clickyPersonaOverrideInstructions = "clickyPersonaOverrideInstructions"
        static let clickyPersonaPreset = "clickyPersonaPreset"
        static let clickyPersonaToneInstructions = "clickyPersonaToneInstructions"
        static let clickyVoicePreset = "clickyVoicePreset"
        static let clickyCursorStyle = "clickyCursorStyle"
        static let clickySpeechProviderMode = "clickySpeechProviderMode"
        static let clickyBackendBaseURL = "clickyBackendBaseURL"
        static let elevenLabsSelectedVoiceID = "elevenLabsSelectedVoiceID"
        static let elevenLabsSelectedVoiceName = "elevenLabsSelectedVoiceName"
        static let clickyThemePreset = "clickyThemePreset"
        static let isClickyCursorEnabled = "isClickyCursorEnabled"
        static let clickyComputerUsePermissionMode = "clickyComputerUsePermissionMode"
        static let legacyComputerUsePermissionLevel = "computerUsePermissionLevel"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private let defaults: UserDefaults

    @Published var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: Key.selectedModel) }
    }

    @Published var selectedAgentBackend: CompanionAgentBackend {
        didSet { defaults.set(selectedAgentBackend.rawValue, forKey: Key.selectedAgentBackend) }
    }

    @Published var openClawGatewayURL: String {
        didSet { defaults.set(openClawGatewayURL, forKey: Key.openClawGatewayURL) }
    }

    @Published var openClawAgentIdentifier: String {
        didSet { defaults.set(openClawAgentIdentifier, forKey: Key.openClawAgentIdentifier) }
    }

    @Published var openClawAgentName: String {
        didSet { defaults.set(openClawAgentName, forKey: Key.openClawAgentName) }
    }

    @Published var openClawGatewayAuthToken: String {
        didSet { defaults.set(openClawGatewayAuthToken, forKey: Key.openClawGatewayAuthToken) }
    }

    @Published var openClawSessionKey: String {
        didSet { defaults.set(openClawSessionKey, forKey: Key.openClawSessionKey) }
    }

    @Published var clickyPersonaScopeMode: ClickyPersonaScopeMode {
        didSet { defaults.set(clickyPersonaScopeMode.rawValue, forKey: Key.clickyPersonaScopeMode) }
    }

    @Published var clickyPersonaOverrideName: String {
        didSet { defaults.set(clickyPersonaOverrideName, forKey: Key.clickyPersonaOverrideName) }
    }

    @Published var clickyPersonaOverrideInstructions: String {
        didSet { defaults.set(clickyPersonaOverrideInstructions, forKey: Key.clickyPersonaOverrideInstructions) }
    }

    @Published var clickyPersonaPreset: ClickyPersonaPreset {
        didSet { defaults.set(clickyPersonaPreset.rawValue, forKey: Key.clickyPersonaPreset) }
    }

    @Published var clickyPersonaToneInstructions: String {
        didSet { defaults.set(clickyPersonaToneInstructions, forKey: Key.clickyPersonaToneInstructions) }
    }

    @Published var clickyVoicePreset: ClickyVoicePreset {
        didSet { defaults.set(clickyVoicePreset.rawValue, forKey: Key.clickyVoicePreset) }
    }

    @Published var clickyCursorStyle: ClickyCursorStyle {
        didSet { defaults.set(clickyCursorStyle.rawValue, forKey: Key.clickyCursorStyle) }
    }

    @Published var clickySpeechProviderMode: ClickySpeechProviderMode {
        didSet { defaults.set(clickySpeechProviderMode.rawValue, forKey: Key.clickySpeechProviderMode) }
    }

    @Published var clickyBackendBaseURL: String {
        didSet { defaults.set(clickyBackendBaseURL, forKey: Key.clickyBackendBaseURL) }
    }

    @Published var elevenLabsSelectedVoiceID: String {
        didSet { defaults.set(elevenLabsSelectedVoiceID, forKey: Key.elevenLabsSelectedVoiceID) }
    }

    @Published var elevenLabsSelectedVoiceName: String {
        didSet { defaults.set(elevenLabsSelectedVoiceName, forKey: Key.elevenLabsSelectedVoiceName) }
    }

    @Published var clickyThemePreset: ClickyThemePreset {
        didSet { defaults.set(clickyThemePreset.rawValue, forKey: Key.clickyThemePreset) }
    }

    @Published var isClickyCursorEnabled: Bool {
        didSet { defaults.set(isClickyCursorEnabled, forKey: Key.isClickyCursorEnabled) }
    }

    @Published var clickyComputerUsePermissionMode: ClickyComputerUsePermissionMode {
        didSet { defaults.set(clickyComputerUsePermissionMode.rawValue, forKey: Key.clickyComputerUsePermissionMode) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedModel = defaults.string(forKey: Key.selectedModel) ?? "claude-sonnet-4-6"
        selectedAgentBackend = CompanionAgentBackend(
            rawValue: defaults.string(forKey: Key.selectedAgentBackend) ?? ""
        ) ?? (CompanionRuntimeConfiguration.isWorkerConfigured ? .claude : .openClaw)
        openClawGatewayURL = defaults.string(forKey: Key.openClawGatewayURL) ?? "ws://127.0.0.1:18789"
        openClawAgentIdentifier = defaults.string(forKey: Key.openClawAgentIdentifier) ?? ""
        openClawAgentName = defaults.string(forKey: Key.openClawAgentName) ?? ""
        openClawGatewayAuthToken = defaults.string(forKey: Key.openClawGatewayAuthToken) ?? ""
        openClawSessionKey = defaults.string(forKey: Key.openClawSessionKey) ?? "clicky-companion"
        clickyPersonaScopeMode = ClickyPersonaScopeMode(
            rawValue: defaults.string(forKey: Key.clickyPersonaScopeMode) ?? ""
        ) ?? .useOpenClawIdentity
        clickyPersonaOverrideName = defaults.string(forKey: Key.clickyPersonaOverrideName) ?? ""
        clickyPersonaOverrideInstructions = defaults.string(forKey: Key.clickyPersonaOverrideInstructions) ?? ""
        clickyPersonaPreset = ClickyPersonaPreset(
            rawValue: defaults.string(forKey: Key.clickyPersonaPreset) ?? ""
        ) ?? .guide
        clickyPersonaToneInstructions = defaults.string(forKey: Key.clickyPersonaToneInstructions) ?? ""
        clickyVoicePreset = ClickyVoicePreset(
            rawValue: defaults.string(forKey: Key.clickyVoicePreset) ?? ""
        ) ?? .balanced
        clickyCursorStyle = ClickyCursorStyle(
            rawValue: defaults.string(forKey: Key.clickyCursorStyle) ?? ""
        ) ?? .classic
        clickySpeechProviderMode = ClickySpeechProviderMode(
            rawValue: defaults.string(forKey: Key.clickySpeechProviderMode) ?? ""
        ) ?? .system
        clickyBackendBaseURL = Self.resolvedInitialClickyBackendBaseURL(defaults: defaults)
        elevenLabsSelectedVoiceID = defaults.string(forKey: Key.elevenLabsSelectedVoiceID) ?? ""
        elevenLabsSelectedVoiceName = defaults.string(forKey: Key.elevenLabsSelectedVoiceName) ?? ""
        clickyThemePreset = ClickyThemePreset(
            rawValue: defaults.string(forKey: Key.clickyThemePreset) ?? ""
        ) ?? .dark
        isClickyCursorEnabled = defaults.object(forKey: Key.isClickyCursorEnabled) == nil
            ? true
            : defaults.bool(forKey: Key.isClickyCursorEnabled)
        clickyComputerUsePermissionMode = Self.resolvedInitialComputerUsePermissionMode(defaults: defaults)
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
    }

    private static func resolvedInitialClickyBackendBaseURL(defaults: UserDefaults) -> String {
        let defaultBackendBaseURL = CompanionRuntimeConfiguration.defaultBackendBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let storedBackendBaseURL = defaults.string(forKey: Key.clickyBackendBaseURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !storedBackendBaseURL.isEmpty else {
            defaults.set(defaultBackendBaseURL, forKey: Key.clickyBackendBaseURL)
            return defaultBackendBaseURL
        }

        let legacyBackendBaseURLs: Set<String> = [
            "https://api.clicky.app",
        ]

        if legacyBackendBaseURLs.contains(storedBackendBaseURL) {
            defaults.set(defaultBackendBaseURL, forKey: Key.clickyBackendBaseURL)
            return defaultBackendBaseURL
        }

        if let storedURL = URL(string: storedBackendBaseURL),
           let host = storedURL.host?.lowercased(),
           host == "localhost" || host == "127.0.0.1" || host == "127.1.1.0" {
            #if DEBUG
            return storedBackendBaseURL
            #else
            defaults.set(defaultBackendBaseURL, forKey: Key.clickyBackendBaseURL)
            return defaultBackendBaseURL
            #endif
        }

        return storedBackendBaseURL
    }

    private static func resolvedInitialComputerUsePermissionMode(defaults: UserDefaults) -> ClickyComputerUsePermissionMode {
        if let storedMode = ClickyComputerUsePermissionMode(
            rawValue: defaults.string(forKey: Key.clickyComputerUsePermissionMode) ?? ""
        ) {
            defaults.removeObject(forKey: Key.legacyComputerUsePermissionLevel)
            return storedMode
        }

        let migratedMode: ClickyComputerUsePermissionMode
        switch defaults.string(forKey: Key.legacyComputerUsePermissionLevel) {
        case "autoApproved":
            migratedMode = .direct
        case "review":
            migratedMode = .review
        case "off", "disabled":
            migratedMode = .off
        default:
            migratedMode = .off
        }

        defaults.set(migratedMode.rawValue, forKey: Key.clickyComputerUsePermissionMode)
        defaults.removeObject(forKey: Key.legacyComputerUsePermissionLevel)
        return migratedMode
    }
}
