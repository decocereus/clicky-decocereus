//
//  ClickyLaunchTurnGate.swift
//  leanring-buddy
//
//  Decides how launch access state affects assistant turns.
//

import Foundation

struct LaunchAssistantTurnAuthorization {
    let session: ClickyAuthSessionSnapshot?
    let shouldUseWelcomeTurn: Bool
    let shouldUsePaywallTurn: Bool

    static let standard = LaunchAssistantTurnAuthorization(
        session: nil,
        shouldUseWelcomeTurn: false,
        shouldUsePaywallTurn: false
    )

    var promptMode: ClickyAssistantLaunchPromptMode {
        if shouldUsePaywallTurn {
            return .paywall
        }
        if shouldUseWelcomeTurn {
            return .welcome
        }
        return .standard
    }
}

@MainActor
struct ClickyLaunchTurnGate {
    static let paywallLockedMessage = "clicky has used the included trial on this mac. open studio to unlock access or restore your purchase, and everything will pick up from there."

    let accessController: ClickyLaunchAccessController
    let sessionService: ClickyLaunchSessionService
    var storedSessionProvider: () -> ClickyAuthSessionSnapshot? = ClickyAuthSessionStore.load

    func hasUnlimitedAccess() -> Bool {
        if case .unlocked = accessController.clickyLaunchTrialState {
            return true
        }

        return false
    }

    func requiresRepurchaseForCompanionUse() -> Bool {
        guard let storedSession = storedSessionProvider() else {
            return false
        }

        return ClickyLaunchAccessController.entitlementRequiresRepurchase(storedSession.entitlement)
    }

    func requiresEntitlementRefreshForCompanionUse() -> Bool {
        guard let storedSession = storedSessionProvider() else {
            return false
        }

        return ClickyLaunchAccessController.entitlementGraceExpired(storedSession.entitlement)
    }

    func requiresSignInForCompanionUse(
        hasCompletedOnboarding: Bool,
        allPermissionsGranted: Bool
    ) -> Bool {
        guard hasCompletedOnboarding && allPermissionsGranted else {
            return false
        }

        if isPaywallActive() {
            return false
        }

        switch accessController.clickyLaunchAuthState {
        case .signedOut, .failed:
            return true
        case .restoring, .signingIn, .signedIn:
            return false
        }
    }

    func isPaywallActive() -> Bool {
        if let storedSession = storedSessionProvider() {
            return !storedSession.entitlement.hasAccess && storedSession.trial?.status == "paywalled"
        }

        switch accessController.clickyLaunchTrialState {
        case .paywalled:
            return true
        default:
            return false
        }
    }

    func prepareAuthorizationForAssistantTurn(
        hasCompletedOnboarding: Bool,
        allPermissionsGranted: Bool
    ) async throws -> LaunchAssistantTurnAuthorization {
        guard let storedSession = storedSessionProvider() else {
            return .standard
        }

        guard !ClickyLaunchAccessController.entitlementHasEffectiveAccess(storedSession.entitlement) else {
            return LaunchAssistantTurnAuthorization(
                session: storedSession,
                shouldUseWelcomeTurn: false,
                shouldUsePaywallTurn: false
            )
        }

        if ClickyLaunchAccessController.entitlementRequiresRepurchase(storedSession.entitlement)
            || ClickyLaunchAccessController.entitlementGraceExpired(storedSession.entitlement) {
            return LaunchAssistantTurnAuthorization(
                session: storedSession,
                shouldUseWelcomeTurn: false,
                shouldUsePaywallTurn: false
            )
        }

        guard hasCompletedOnboarding && allPermissionsGranted else {
            return LaunchAssistantTurnAuthorization(
                session: storedSession,
                shouldUseWelcomeTurn: false,
                shouldUsePaywallTurn: false
            )
        }

        let needsTrialActivation = storedSession.trial == nil || storedSession.trial?.status == "inactive"
        let sessionForTurn = needsTrialActivation
            ? try await sessionService.activateTrial(for: storedSession)
            : storedSession

        let shouldUseWelcomeTurn =
            sessionForTurn.trial?.status == "active"
            && sessionForTurn.trial?.welcomePromptDeliveredAt == nil
        let shouldUsePaywallTurn = sessionForTurn.trial?.status == "armed"
        return LaunchAssistantTurnAuthorization(
            session: sessionForTurn,
            shouldUseWelcomeTurn: shouldUseWelcomeTurn,
            shouldUsePaywallTurn: shouldUsePaywallTurn
        )
    }
}
