//
//  ClickyLaunchAccessController.swift
//  leanring-buddy
//
//  Observable launch-auth, entitlement, and billing state for Clicky.
//

import Combine
import Foundation
import os

@MainActor
final class ClickyLaunchAccessController: ObservableObject {
    @Published var clickyLaunchAuthState: ClickyLaunchAuthState = .signedOut
    @Published var clickyLaunchEntitlementStatusLabel: String = "Unknown"
    @Published var clickyLaunchBillingState: ClickyLaunchBillingState = .idle
    @Published var clickyLaunchTrialState: ClickyLaunchTrialState = .inactive
    @Published var clickyLaunchProfileName: String = ""
    @Published var clickyLaunchProfileImageURL: String = ""
}

extension ClickyLaunchAccessController {
    func setAuthState(_ newState: ClickyLaunchAuthState, reason: String) {
        let previousState = clickyLaunchAuthState
        clickyLaunchAuthState = newState

        guard previousState != newState else { return }

        ClickyUnifiedTelemetry.launchAuth.info(
            "Launch auth state state=\(Self.authStateName(newState), privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    func setBillingState(_ newState: ClickyLaunchBillingState, reason: String) {
        let previousState = clickyLaunchBillingState
        clickyLaunchBillingState = newState

        guard previousState != newState else { return }

        ClickyUnifiedTelemetry.billing.info(
            "Billing state state=\(Self.billingStateName(newState), privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    func setTrialState(_ newState: ClickyLaunchTrialState, reason: String) {
        let previousState = clickyLaunchTrialState
        clickyLaunchTrialState = newState

        guard previousState != newState else { return }

        ClickyUnifiedTelemetry.billing.info(
            "Launch trial state state=\(Self.trialStateName(newState), privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    func persistSessionSnapshot(_ snapshot: ClickyAuthSessionSnapshot, reason: String) throws {
        try ClickyAuthSessionStore.save(snapshot)
        setAuthState(.signedIn(email: snapshot.email), reason: reason)
        clickyLaunchProfileName = snapshot.name ?? ""
        clickyLaunchProfileImageURL = snapshot.image ?? ""
        clickyLaunchEntitlementStatusLabel = Self.formatEntitlementStatus(snapshot.entitlement)
        setTrialState(Self.formatTrialState(
            snapshot.trial,
            hasAccess: Self.entitlementHasEffectiveAccess(snapshot.entitlement)
        ), reason: reason)
    }

    func clearSessionState(reason: String) {
        setAuthState(.signedOut, reason: reason)
        clickyLaunchEntitlementStatusLabel = "Unknown"
        setBillingState(.idle, reason: reason)
        setTrialState(.inactive, reason: reason)
        clickyLaunchProfileName = ""
        clickyLaunchProfileImageURL = ""
    }

    func restoreCachedSessionState(_ snapshot: ClickyAuthSessionSnapshot, reason: String) {
        setAuthState(.signedIn(email: snapshot.email), reason: reason)
        clickyLaunchProfileName = snapshot.name ?? ""
        clickyLaunchProfileImageURL = snapshot.image ?? ""
        clickyLaunchEntitlementStatusLabel = Self.formatEntitlementStatus(snapshot.entitlement)
        setTrialState(Self.formatTrialState(
            snapshot.trial,
            hasAccess: Self.entitlementHasEffectiveAccess(snapshot.entitlement)
        ), reason: reason)
    }

    static func entitlementHasEffectiveAccess(
        _ entitlement: ClickyLaunchEntitlementSnapshot
    ) -> Bool {
        guard entitlement.hasAccess else {
            return false
        }

        guard let graceEndDate = entitlementGraceEndDate(entitlement) else {
            return true
        }

        return graceEndDate > Date()
    }

    static func entitlementRequiresRepurchase(
        _ entitlement: ClickyLaunchEntitlementSnapshot
    ) -> Bool {
        let normalizedStatus = entitlement.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !entitlementHasEffectiveAccess(entitlement) else {
            return false
        }

        return normalizedStatus == "refunded" || normalizedStatus == "revoked"
    }

    static func entitlementGraceExpired(
        _ entitlement: ClickyLaunchEntitlementSnapshot
    ) -> Bool {
        entitlement.hasAccess && !entitlementHasEffectiveAccess(entitlement)
    }

    static func makeEntitlementSnapshot(
        from payload: ClickyBackendEntitlementPayload
    ) -> ClickyLaunchEntitlementSnapshot {
        ClickyLaunchEntitlementSnapshot(
            productKey: payload.productKey,
            status: payload.status,
            hasAccess: payload.hasAccess,
            gracePeriodEndsAt: payload.gracePeriodEndsAt
        )
    }

    static func makeTrialSnapshot(
        from payload: ClickyBackendTrialPayload
    ) -> ClickyLaunchTrialSnapshot {
        ClickyLaunchTrialSnapshot(
            status: payload.status,
            initialCredits: payload.initialCredits,
            remainingCredits: payload.remainingCredits,
            setupCompletedAt: payload.setupCompletedAt,
            trialActivatedAt: payload.trialActivatedAt,
            lastCreditConsumedAt: payload.lastCreditConsumedAt,
            welcomePromptDeliveredAt: payload.welcomePromptDeliveredAt,
            paywallActivatedAt: payload.paywallActivatedAt
        )
    }

    static func updatedSessionSnapshot(
        from storedSession: ClickyAuthSessionSnapshot,
        userID: String? = nil,
        email: String? = nil,
        entitlement: ClickyLaunchEntitlementSnapshot? = nil,
        trial: ClickyLaunchTrialSnapshot? = nil
    ) -> ClickyAuthSessionSnapshot {
        ClickyAuthSessionSnapshot(
            sessionToken: storedSession.sessionToken,
            userID: userID ?? storedSession.userID,
            email: email ?? storedSession.email,
            name: storedSession.name,
            image: storedSession.image,
            entitlement: entitlement ?? storedSession.entitlement,
            trial: trial ?? storedSession.trial
        )
    }

    static func shouldClearStoredSession(after error: Error) -> Bool {
        guard let authError = error as? ClickyBackendAuthClientError else {
            return false
        }

        guard case let .unexpectedStatus(code, _) = authError else {
            return false
        }

        return code == 401 || code == 404
    }

    static func formatTrialState(_ trial: ClickyLaunchTrialSnapshot?, hasAccess: Bool) -> ClickyLaunchTrialState {
        if hasAccess {
            return .unlocked
        }

        guard let trial else {
            return .inactive
        }

        switch trial.status {
        case "active":
            return .active(remainingCredits: trial.remainingCredits)
        case "armed":
            return .armed
        case "paywalled":
            return .paywalled
        case "unlocked":
            return .paywalled
        default:
            return .inactive
        }
    }

    static func formatEntitlementStatus(_ entitlement: ClickyLaunchEntitlementSnapshot) -> String {
        if entitlement.hasAccess {
            if entitlementGraceExpired(entitlement) {
                return "Refresh required"
            }

            if let gracePeriodEndsAt = entitlement.gracePeriodEndsAt,
               !gracePeriodEndsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Active · grace until \(gracePeriodEndsAt)"
            }

            return "Active"
        }

        return entitlement.status.capitalized
    }

    private static func entitlementGraceEndDate(
        _ entitlement: ClickyLaunchEntitlementSnapshot
    ) -> Date? {
        guard let gracePeriodEndsAt = entitlement.gracePeriodEndsAt,
              !gracePeriodEndsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return ISO8601DateFormatter().date(from: gracePeriodEndsAt)
    }

    private static func authStateName(_ state: ClickyLaunchAuthState) -> String {
        switch state {
        case .signedOut:
            return "signed-out"
        case .restoring:
            return "restoring"
        case .signingIn:
            return "signing-in"
        case .signedIn:
            return "signed-in"
        case .failed:
            return "failed"
        }
    }

    private static func billingStateName(_ state: ClickyLaunchBillingState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .openingCheckout:
            return "opening-checkout"
        case .waitingForCompletion:
            return "waiting-for-completion"
        case .canceled:
            return "canceled"
        case .completed:
            return "completed"
        case .failed:
            return "failed"
        }
    }

    private static func trialStateName(_ state: ClickyLaunchTrialState) -> String {
        switch state {
        case .inactive:
            return "inactive"
        case .active:
            return "active"
        case .armed:
            return "armed"
        case .paywalled:
            return "paywalled"
        case .unlocked:
            return "unlocked"
        case .failed:
            return "failed"
        }
    }
}
