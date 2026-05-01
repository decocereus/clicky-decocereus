//
//  ClickyCompanionModels.swift
//  leanring-buddy
//
//  Shared companion state models used by the menu bar panel, Studio, and
//  companion coordinators.
//

import Foundation

enum CompanionVoiceState {
    case idle
    case listening
    case transcribing
    case thinking
    case responding
}

enum OpenClawConnectionStatus {
    case idle
    case testing
    case connected(summary: String)
    case failed(message: String)
}

enum CodexRuntimeStatus {
    case idle
    case checking
    case ready(summary: String)
    case failed(message: String)
}

enum ClickyComputerUseRuntimeStatus {
    case idle
    case checking
    case ready(summary: String)
    case failed(message: String)
}

enum ClickyComputerUsePermissionMode: String, CaseIterable {
    case off
    case observeOnly
    case review
    case direct
}

struct ClickyComputerUseReviewRequest: Identifiable, Equatable {
    let id: String
    let toolName: String
    let argumentsSummary: String
    let requestDigest: String
    let createdAt: Date?
}

enum ClickyOpenClawPluginStatus {
    case notConfigured
    case disabled
    case enabled
}

enum ClickyShellRegistrationStatus {
    case idle
    case registering
    case registered(summary: String)
    case failed(message: String)
}

enum ClickyPersonaScopeMode: String, CaseIterable {
    case useOpenClawIdentity
    case overrideInClicky
}

enum ElevenLabsVoiceFetchStatus: Equatable {
    case idle
    case loading
    case loaded
    case failed(message: String)
}

enum ClickySpeechOutputMode {
    case system
    case elevenLabsBYO(ElevenLabsDirectConfiguration)
}

enum ClickySpeechPreviewStatus: Equatable {
    case idle
    case previewing
    case succeeded(message: String)
    case failed(message: String)
}

enum ClickyLaunchAuthState: Equatable {
    case signedOut
    case restoring
    case signingIn
    case signedIn(email: String)
    case failed(message: String)
}

enum ClickyLaunchBillingState: Equatable {
    case idle
    case openingCheckout
    case waitingForCompletion
    case canceled
    case completed
    case failed(message: String)
}

enum ClickyLaunchTrialState: Equatable {
    case inactive
    case active(remainingCredits: Int)
    case armed
    case paywalled
    case unlocked
    case failed(message: String)
}

enum ElevenLabsVoiceImportStatus: Equatable {
    case idle
    case importing
    case succeeded(message: String)
    case failed(message: String)
}

struct ClickySpeechRouting {
    let selectedProvider: ClickySpeechProviderMode
    let outputMode: ClickySpeechOutputMode
    let selectedVoiceID: String
    let selectedVoiceName: String
    let configurationFallbackMessage: String?

    var selectedProviderDisplayName: String {
        selectedProvider.displayName
    }

    var resolvedProviderDisplayName: String {
        switch outputMode {
        case .system:
            return "System Speech"
        case .elevenLabsBYO:
            return "ElevenLabs"
        }
    }

    var didFallbackToSystem: Bool {
        selectedProvider == .elevenLabsBYO && configurationFallbackMessage != nil
    }

    var selectedVoiceNameLabel: String {
        let trimmedName = selectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "No ElevenLabs voice selected" : trimmedName
    }

    var selectedVoiceIDLabel: String {
        let trimmedVoiceID = selectedVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedVoiceID.isEmpty ? "No voice id selected" : trimmedVoiceID
    }
}
