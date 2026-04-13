//
//  CompanionStudioLaunchAccessSnapshot.swift
//  leanring-buddy
//
//  Shared Studio-facing access/account summary derived from the smaller stores.
//

import Foundation

struct CompanionStudioLaunchAccessSnapshot {
    let authState: ClickyLaunchAuthState
    let billingState: ClickyLaunchBillingState
    let trialState: ClickyLaunchTrialState
    let profileName: String
    let profileImageURL: String
    let hasCompletedOnboarding: Bool
    let hasAccessibilityPermission: Bool
    let hasScreenRecordingPermission: Bool
    let hasMicrophonePermission: Bool
    let hasScreenContentPermission: Bool

    var billingStatusLabel: String {
        switch billingState {
        case .idle:
            return "Idle"
        case .openingCheckout:
            return "Opening checkout"
        case .waitingForCompletion:
            return "Waiting for purchase"
        case .canceled:
            return "Checkout canceled"
        case .completed:
            return "Checkout completed"
        case let .failed(message):
            return message
        }
    }

    var trialStatusLabel: String {
        switch trialState {
        case .inactive:
            return "Inactive"
        case let .active(remainingCredits):
            return "\(remainingCredits) credits left"
        case .armed:
            return "Paywall armed"
        case .paywalled:
            return "Paywall active"
        case .unlocked:
            return "Unlocked"
        case let .failed(message):
            return message
        }
    }

    var isSignedIn: Bool {
        if case .signedIn = authState {
            return true
        }

        return false
    }

    var hasUnlimitedAccess: Bool {
        if case .unlocked = trialState {
            return true
        }

        return false
    }

    var allPermissionsGranted: Bool {
        hasAccessibilityPermission
            && hasScreenRecordingPermission
            && hasMicrophonePermission
            && hasScreenContentPermission
    }

    var isPaywallActive: Bool {
        if let storedSession = ClickyAuthSessionStore.load() {
            return !storedSession.entitlement.hasAccess && storedSession.trial?.status == "paywalled"
        }

        if case .paywalled = trialState {
            return true
        }

        return false
    }

    var requiresSignInForCompanionUse: Bool {
        guard hasCompletedOnboarding && allPermissionsGranted else {
            return false
        }

        if isPaywallActive {
            return false
        }

        switch authState {
        case .signedOut, .failed:
            return true
        case .restoring, .signingIn, .signedIn:
            return false
        }
    }

    var authStatusLabel: String {
        switch authState {
        case .signedOut:
            return "Signed out"
        case .restoring:
            return "Restoring session"
        case .signingIn:
            return "Waiting for browser sign-in"
        case let .signedIn(email):
            return email
        case let .failed(message):
            return message
        }
    }

    var displayName: String {
        let trimmedProfileName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedProfileName.isEmpty {
            return trimmedProfileName
        }

        let fullUserName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullUserName.isEmpty {
            return fullUserName
        }

        guard case let .signedIn(email) = authState else {
            return "Clicky User"
        }

        let localPart = email.split(separator: "@").first.map(String.init) ?? ""
        let normalizedLocalPart = localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedLocalPart.isEmpty {
            return "Clicky User"
        }

        return normalizedLocalPart
            .split(separator: " ")
            .map { fragment in
                let lowercased = fragment.lowercased()
                return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }

    var displayInitials: String {
        let words = displayName
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .map(String.init)

        if words.count >= 2 {
            return String(words.prefix(2).compactMap(\.first)).uppercased()
        }

        let compactName = displayName.replacingOccurrences(of: " ", with: "")
        return String(compactName.prefix(2)).uppercased()
    }
}
