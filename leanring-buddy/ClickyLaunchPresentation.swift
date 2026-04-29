//
//  ClickyLaunchPresentation.swift
//  leanring-buddy
//
//  Pure launch/account presentation helpers shared by Studio, panel, and
//  companion manager facades.
//

import Foundation

enum ClickyLaunchPresentation {
    static func authStatusLabel(for state: ClickyLaunchAuthState) -> String {
        switch state {
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

    static func billingStatusLabel(for state: ClickyLaunchBillingState) -> String {
        switch state {
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

    static func trialStatusLabel(for state: ClickyLaunchTrialState) -> String {
        switch state {
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

    static func isSignedIn(_ state: ClickyLaunchAuthState) -> Bool {
        if case .signedIn = state {
            return true
        }

        return false
    }

    static func hasUnlimitedAccess(_ state: ClickyLaunchTrialState) -> Bool {
        if case .unlocked = state {
            return true
        }

        return false
    }

    static func displayName(profileName: String, authState: ClickyLaunchAuthState) -> String {
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

    static func initials(for displayName: String) -> String {
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
