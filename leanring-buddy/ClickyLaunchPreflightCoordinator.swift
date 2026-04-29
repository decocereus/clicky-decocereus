//
//  ClickyLaunchPreflightCoordinator.swift
//  leanring-buddy
//
//  Decides whether a push-to-talk session may begin under launch access rules.
//

import Foundation

@MainActor
struct ClickyLaunchPreflightCoordinator {
    let launchTurnGate: ClickyLaunchTurnGate
    let blockedTurnPresenter: ClickyLaunchBlockedTurnPresenter
    let authStateProvider: @MainActor () -> ClickyLaunchAuthState
    let hasCompletedOnboarding: @MainActor () -> Bool
    let allPermissionsGranted: @MainActor () -> Bool
    let isOnboardingVideoVisible: @MainActor () -> Bool

    func canBeginPushToTalkSession() -> Bool {
        guard !isOnboardingVideoVisible() else { return false }

        if launchTurnGate.requiresRepurchaseForCompanionUse() {
            blockedTurnPresenter.presentAccessRecovery(
                openStudio: true,
                message: "your launch pass is no longer active. open studio to buy again or restore access if this looks wrong.",
                logReason: "launch entitlement requires repurchase"
            )
            return false
        }

        if launchTurnGate.requiresEntitlementRefreshForCompanionUse() {
            blockedTurnPresenter.presentAccessRecovery(
                openStudio: true,
                message: "your cached access expired and clicky needs to refresh it. open studio and run refresh access before starting a new assisted turn.",
                logReason: "launch entitlement grace expired"
            )
            return false
        }

        if launchTurnGate.requiresSignInForCompanionUse(
            hasCompletedOnboarding: hasCompletedOnboarding(),
            allPermissionsGranted: allPermissionsGranted()
        ) {
            blockedTurnPresenter.presentSignInRequired(
                authState: authStateProvider(),
                openStudio: true
            )
            return false
        }

        if launchTurnGate.isPaywallActive() {
            blockedTurnPresenter.presentPaywallLocked(openStudio: true)
            return false
        }

        return true
    }
}
