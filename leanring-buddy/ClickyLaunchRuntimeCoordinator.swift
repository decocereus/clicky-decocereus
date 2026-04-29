//
//  ClickyLaunchRuntimeCoordinator.swift
//  leanring-buddy
//
//  Owns launch auth restore, quiet entitlement refresh, and trial/paywall
//  runtime actions.
//

import Foundation
import os

@MainActor
final class ClickyLaunchRuntimeCoordinator {
    private let accessController: ClickyLaunchAccessController
    private let sessionService: ClickyLaunchSessionService
    private let backendClientProvider: () -> ClickyBackendAuthClient

    private var quietEntitlementRefreshTask: Task<Void, Never>?
    private var lastQuietEntitlementRefreshAt: Date?

    init(
        accessController: ClickyLaunchAccessController,
        sessionService: ClickyLaunchSessionService,
        backendClientProvider: @escaping () -> ClickyBackendAuthClient
    ) {
        self.accessController = accessController
        self.sessionService = sessionService
        self.backendClientProvider = backendClientProvider
    }

    func stop() {
        quietEntitlementRefreshTask?.cancel()
        quietEntitlementRefreshTask = nil
    }

    func restoreSessionIfPossible() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            accessController.clearSessionState(reason: "restore-no-session")
            ClickyUnifiedTelemetry.launchAuth.info("Launch auth restore skipped reason=no-stored-session")
            return
        }

        accessController.setAuthState(.restoring, reason: "restore-started")
        ClickyUnifiedTelemetry.launchAuth.info("Launch auth restore started source=stored-session")

        Task { @MainActor in
            do {
                let refreshedSnapshot = try await sessionService.synchronizeSessionSnapshot(
                    sessionToken: storedSession.sessionToken,
                    fallbackUserID: storedSession.userID,
                    fallbackEmail: storedSession.email,
                    entitlementSyncMode: .refresh
                )

                try accessController.persistSessionSnapshot(refreshedSnapshot, reason: "stored-session-restore")
                ClickyUnifiedTelemetry.launchAuth.info("Launch auth restore completed source=stored-session result=refreshed")
                ClickyLogger.notice(.app, "Restored Clicky launch auth session")
            } catch {
                if ClickyLaunchAccessController.shouldClearStoredSession(after: error) {
                    ClickyAuthSessionStore.clear()
                    accessController.clearSessionState(reason: "restore-invalid-session")
                    ClickyUnifiedTelemetry.launchAuth.error(
                        "Launch auth restore cleared invalid stored session error=\(error.localizedDescription, privacy: .public)"
                    )
                    ClickyLogger.error(.app, "Failed to restore Clicky launch auth session error=\(error.localizedDescription)")
                    return
                }

                accessController.restoreCachedSessionState(storedSession, reason: "restore-cached-fallback")
                ClickyUnifiedTelemetry.launchAuth.debug(
                    "Launch auth restore failed; using cached session error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.debug(
                    .app,
                    "Failed to refresh Clicky launch session; continuing with cached state error=\(error.localizedDescription)"
                )
            }
        }
    }

    func handleApplicationDidBecomeActive() {
        refreshEntitlementQuietlyIfNeeded(reason: "app_became_active")
    }

    func refreshEntitlementQuietlyIfNeeded(
        reason: String,
        minimumInterval: TimeInterval = 90
    ) {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            return
        }

        guard Self.shouldAttemptQuietEntitlementRefresh(
            storedSession: storedSession,
            trialState: accessController.clickyLaunchTrialState,
            billingState: accessController.clickyLaunchBillingState
        ) else {
            return
        }

        if let lastQuietEntitlementRefreshAt,
           Date().timeIntervalSince(lastQuietEntitlementRefreshAt) < minimumInterval {
            return
        }

        if quietEntitlementRefreshTask != nil {
            return
        }

        lastQuietEntitlementRefreshAt = Date()
        ClickyUnifiedTelemetry.billing.debug(
            "Quiet entitlement refresh scheduled reason=\(reason, privacy: .public)"
        )
        ClickyLogger.debug(.app, "Scheduling quiet launch entitlement refresh reason=\(reason)")

        quietEntitlementRefreshTask = Task { @MainActor in
            defer {
                quietEntitlementRefreshTask = nil
            }

            do {
                let syncMode = Self.quietEntitlementSyncMode(
                    storedSession: storedSession,
                    billingState: accessController.clickyLaunchBillingState
                )
                let refreshedSnapshot = try await sessionService.synchronizeSessionSnapshot(
                    sessionToken: storedSession.sessionToken,
                    fallbackUserID: storedSession.userID,
                    fallbackEmail: storedSession.email,
                    entitlementSyncMode: syncMode
                )

                try accessController.persistSessionSnapshot(refreshedSnapshot, reason: "quiet-entitlement-refresh")
                if refreshedSnapshot.entitlement.hasAccess {
                    accessController.setBillingState(.completed, reason: "quiet-entitlement-refresh")
                }
                ClickyUnifiedTelemetry.billing.debug(
                    "Quiet entitlement refresh completed reason=\(reason, privacy: .public) access=\(refreshedSnapshot.entitlement.hasAccess ? "true" : "false", privacy: .public) status=\(refreshedSnapshot.entitlement.status, privacy: .public)"
                )
                ClickyLogger.debug(
                    .app,
                    "Quiet launch entitlement refresh succeeded reason=\(reason) access=\(refreshedSnapshot.entitlement.hasAccess)"
                )
            } catch {
                if ClickyLaunchAccessController.shouldClearStoredSession(after: error) {
                    ClickyAuthSessionStore.clear()
                    accessController.clearSessionState(reason: "quiet-entitlement-refresh-invalid-session")
                    ClickyUnifiedTelemetry.billing.error(
                        "Quiet entitlement refresh cleared invalid session reason=\(reason, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                    )
                    ClickyLogger.error(
                        .app,
                        "Quiet launch entitlement refresh cleared invalid session reason=\(reason) error=\(error.localizedDescription)"
                    )
                    return
                }

                ClickyUnifiedTelemetry.billing.debug(
                    "Quiet entitlement refresh failed reason=\(reason, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.debug(
                    .app,
                    "Quiet launch entitlement refresh failed reason=\(reason) error=\(error.localizedDescription)"
                )
            }
        }
    }

    func refreshTrialState() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            accessController.setTrialState(.inactive, reason: "trial-refresh-no-session")
            return
        }

        ClickyUnifiedTelemetry.billing.info("Launch trial refresh requested")
        Task { @MainActor in
            do {
                let trialPayload = try await backendClientProvider().fetchCurrentTrial(sessionToken: storedSession.sessionToken)
                let updatedTrial = ClickyLaunchAccessController.makeTrialSnapshot(from: trialPayload.trial)
                let refreshedSnapshot = ClickyLaunchAccessController.updatedSessionSnapshot(
                    from: storedSession,
                    trial: updatedTrial
                )

                try accessController.persistSessionSnapshot(refreshedSnapshot, reason: "trial-refresh")
                ClickyUnifiedTelemetry.billing.info(
                    "Launch trial refresh completed status=\(updatedTrial.status, privacy: .public) remainingCredits=\(String(updatedTrial.remainingCredits), privacy: .public)"
                )
                ClickyLogger.notice(.app, "Launch trial state refreshed status=\(updatedTrial.status) remaining=\(updatedTrial.remainingCredits)")
            } catch {
                accessController.setTrialState(.failed(message: error.localizedDescription), reason: "trial-refresh-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Launch trial refresh failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to refresh launch trial state error=\(error.localizedDescription)")
            }
        }
    }

    func activateTrial() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            accessController.setTrialState(.failed(message: "Sign in before activating the trial."), reason: "trial-activate-blocked-no-session")
            ClickyUnifiedTelemetry.billing.info("Launch trial activation blocked reason=no-session")
            return
        }

        Task { @MainActor in
            do {
                _ = try await sessionService.activateTrial(for: storedSession)
            } catch {
                accessController.setTrialState(.failed(message: error.localizedDescription), reason: "trial-activate-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Launch trial activation failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to activate launch trial error=\(error.localizedDescription)")
            }
        }
    }

    func consumeTrialCredit() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            accessController.setTrialState(.failed(message: "Sign in before consuming trial credits."), reason: "trial-consume-blocked-no-session")
            ClickyUnifiedTelemetry.billing.info("Launch trial consume blocked reason=no-session")
            return
        }

        Task { @MainActor in
            do {
                _ = try await sessionService.consumeTrialCredit(for: storedSession)
            } catch {
                accessController.setTrialState(.failed(message: error.localizedDescription), reason: "trial-consume-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Launch trial consume failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to consume launch trial credit error=\(error.localizedDescription)")
            }
        }
    }

    func activatePaywall() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            accessController.setTrialState(.failed(message: "Sign in before activating the paywall."), reason: "paywall-activate-blocked-no-session")
            ClickyUnifiedTelemetry.billing.info("Launch paywall activation blocked reason=no-session")
            return
        }

        Task { @MainActor in
            do {
                _ = try await sessionService.activatePaywall(for: storedSession)
            } catch {
                accessController.setTrialState(.failed(message: error.localizedDescription), reason: "paywall-activate-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Launch paywall activation failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to activate launch paywall error=\(error.localizedDescription)")
            }
        }
    }

    static func shouldAttemptQuietEntitlementRefresh(
        storedSession: ClickyAuthSessionSnapshot,
        trialState: ClickyLaunchTrialState,
        billingState: ClickyLaunchBillingState
    ) -> Bool {
        if ClickyLaunchAccessController.entitlementHasEffectiveAccess(storedSession.entitlement) {
            return true
        }

        if trialState == .paywalled {
            return true
        }

        switch billingState {
        case .waitingForCompletion, .completed:
            return true
        default:
            return false
        }
    }

    static func quietEntitlementSyncMode(
        storedSession: ClickyAuthSessionSnapshot,
        billingState: ClickyLaunchBillingState
    ) -> ClickyLaunchEntitlementSyncMode {
        if ClickyLaunchAccessController.entitlementHasEffectiveAccess(storedSession.entitlement) {
            return .refresh
        }

        switch billingState {
        case .waitingForCompletion, .completed:
            return .refresh
        default:
            return .restore
        }
    }
}
