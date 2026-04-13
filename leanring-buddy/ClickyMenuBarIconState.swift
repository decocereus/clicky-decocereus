//
//  ClickyMenuBarIconState.swift
//  leanring-buddy
//
//  Derived status-item icon state for the menu bar companion.
//

import Foundation

enum ClickyMenuBarIconState: Equatable {
    case idle
    case listening
    case thinking
    case responding
    case onboarding
    case signInRequired
    case locked
    case backendIssue

    var isAnimated: Bool {
        switch self {
        case .idle, .onboarding, .signInRequired, .locked, .backendIssue:
            return false
        case .listening, .thinking, .responding:
            return true
        }
    }
}

struct ClickyMenuBarIconStateInput {
    let hasCompletedOnboarding: Bool
    let hasAccessibilityPermission: Bool
    let hasScreenRecordingPermission: Bool
    let hasMicrophonePermission: Bool
    let hasScreenContentPermission: Bool
    let voiceState: CompanionVoiceState
    let selectedBackend: CompanionAgentBackend
    let launchAuthState: ClickyLaunchAuthState
    let launchTrialState: ClickyLaunchTrialState
    let openClawConnectionStatus: OpenClawConnectionStatus
    let codexRuntimeStatus: CodexRuntimeStatus

    var allPermissionsGranted: Bool {
        hasAccessibilityPermission
            && hasScreenRecordingPermission
            && hasMicrophonePermission
            && hasScreenContentPermission
    }

    var requiresLaunchSignIn: Bool {
        guard hasCompletedOnboarding && allPermissionsGranted else { return false }

        switch launchTrialState {
        case .paywalled:
            return false
        case .inactive, .active, .armed, .unlocked, .failed:
            break
        }

        switch launchAuthState {
        case .signedOut, .failed:
            return true
        case .restoring, .signingIn, .signedIn:
            return false
        }
    }

    var hasBackendAttention: Bool {
        switch selectedBackend {
        case .claude:
            return false
        case .codex:
            if case .failed = codexRuntimeStatus {
                return true
            }
            return false
        case .openClaw:
            if case .failed = openClawConnectionStatus {
                return true
            }
            return false
        }
    }
}

enum ClickyMenuBarIconStateResolver {
    static func resolve(_ input: ClickyMenuBarIconStateInput) -> ClickyMenuBarIconState {
        if !input.hasCompletedOnboarding || !input.allPermissionsGranted {
            return .onboarding
        }

        if input.requiresLaunchSignIn {
            return .signInRequired
        }

        switch input.launchTrialState {
        case .paywalled:
            return .locked
        case .failed:
            return .backendIssue
        case .inactive, .active, .armed, .unlocked:
            break
        }

        if input.hasBackendAttention {
            return .backendIssue
        }

        switch input.voiceState {
        case .idle:
            return .idle
        case .listening:
            return .listening
        case .transcribing, .thinking:
            return .thinking
        case .responding:
            return .responding
        }
    }
}
