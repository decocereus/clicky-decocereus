//
//  ClickyLaunchSessionService.swift
//  leanring-buddy
//
//  Backend-backed launch session, entitlement, and trial synchronization.
//

import Foundation

enum ClickyLaunchEntitlementSyncMode {
    case current
    case refresh
    case restore
}

@MainActor
final class ClickyLaunchSessionService {
    private let client: ClickyBackendAuthClient
    private let accessController: ClickyLaunchAccessController

    init(
        client: ClickyBackendAuthClient,
        accessController: ClickyLaunchAccessController
    ) {
        self.client = client
        self.accessController = accessController
    }

    func synchronizeSessionSnapshot(
        sessionToken: String,
        fallbackUserID: String? = nil,
        fallbackEmail: String? = nil,
        entitlementSyncMode: ClickyLaunchEntitlementSyncMode = .current
    ) async throws -> ClickyAuthSessionSnapshot {
        async let sessionPayloadTask = client.fetchCurrentSession(sessionToken: sessionToken)
        async let entitlementPayloadTask = loadEntitlement(
            sessionToken: sessionToken,
            mode: entitlementSyncMode
        )
        async let trialPayloadTask = loadTrialSnapshotLeniently(sessionToken: sessionToken)

        let sessionPayload = try await sessionPayloadTask
        let entitlementPayload = try await entitlementPayloadTask
        let trialPayload = await trialPayloadTask

        return ClickyAuthSessionSnapshot(
            sessionToken: sessionToken,
            userID: fallbackUserID ?? sessionPayload.user.id,
            email: fallbackEmail ?? sessionPayload.user.email,
            name: sessionPayload.user.name,
            image: sessionPayload.user.image,
            entitlement: ClickyLaunchAccessController.makeEntitlementSnapshot(from: entitlementPayload),
            trial: trialPayload.map(ClickyLaunchAccessController.makeTrialSnapshot)
        )
    }

    func activateTrial(
        for storedSession: ClickyAuthSessionSnapshot
    ) async throws -> ClickyAuthSessionSnapshot {
        // "Trial activated" means the first setup-complete assisted turn for a
        // signed-in user who still lacks a launch entitlement.
        let trialPayload = try await client.activateTrial(sessionToken: storedSession.sessionToken)
        let activatedTrial = ClickyLaunchAccessController.makeTrialSnapshot(from: trialPayload.trial)
        let refreshedSnapshot = ClickyLaunchAccessController.updatedSessionSnapshot(
            from: storedSession,
            trial: activatedTrial
        )

        try accessController.persistSessionSnapshot(refreshedSnapshot, reason: "trial-activated")
        ClickyUnifiedTelemetry.billing.info(
            "Launch trial activated status=\(activatedTrial.status, privacy: .public) remainingCredits=\(String(activatedTrial.remainingCredits), privacy: .public)"
        )
        ClickyLogger.notice(
            .app,
            "Activated launch trial credits=\(activatedTrial.remainingCredits)"
        )
        return refreshedSnapshot
    }

    func consumeTrialCredit(
        for storedSession: ClickyAuthSessionSnapshot
    ) async throws -> ClickyAuthSessionSnapshot {
        // Credits decrement only after a real assistant turn succeeded.
        let consumePayload = try await client.consumeTrialCredit(
            sessionToken: storedSession.sessionToken
        )
        let updatedTrial = ClickyLaunchAccessController.makeTrialSnapshot(from: consumePayload.trial)
        let refreshedSnapshot = ClickyLaunchAccessController.updatedSessionSnapshot(
            from: storedSession,
            trial: updatedTrial
        )

        try accessController.persistSessionSnapshot(refreshedSnapshot, reason: "trial-credit-consumed")
        ClickyUnifiedTelemetry.billing.info(
            "Launch trial credit consumed remainingCredits=\(String(updatedTrial.remainingCredits), privacy: .public) status=\(updatedTrial.status, privacy: .public)"
        )
        ClickyLogger.notice(
            .app,
            "Consumed launch trial credit remaining=\(updatedTrial.remainingCredits)"
        )
        return refreshedSnapshot
    }

    func activatePaywall(
        for storedSession: ClickyAuthSessionSnapshot
    ) async throws -> ClickyAuthSessionSnapshot {
        let trialPayload = try await client.markTrialPaywalled(
            sessionToken: storedSession.sessionToken
        )
        let paywalledTrial = ClickyLaunchAccessController.makeTrialSnapshot(from: trialPayload.trial)
        let refreshedSnapshot = ClickyLaunchAccessController.updatedSessionSnapshot(
            from: storedSession,
            trial: paywalledTrial
        )

        try accessController.persistSessionSnapshot(refreshedSnapshot, reason: "launch-paywall-activated")
        ClickyUnifiedTelemetry.billing.info("Launch paywall activated")
        ClickyLogger.notice(.app, "Activated launch paywall")
        return refreshedSnapshot
    }

    func markWelcomeDelivered(
        for storedSession: ClickyAuthSessionSnapshot
    ) async throws -> ClickyAuthSessionSnapshot {
        let trialPayload = try await client.markTrialWelcomeDelivered(
            sessionToken: storedSession.sessionToken
        )
        let updatedTrial = ClickyLaunchAccessController.makeTrialSnapshot(from: trialPayload.trial)
        let refreshedSnapshot = ClickyLaunchAccessController.updatedSessionSnapshot(
            from: storedSession,
            trial: updatedTrial
        )

        try accessController.persistSessionSnapshot(refreshedSnapshot, reason: "launch-welcome-delivered")
        ClickyUnifiedTelemetry.billing.info("Launch welcome delivery marked")
        ClickyLogger.notice(.app, "Marked launch welcome turn delivered")
        return refreshedSnapshot
    }

    private func loadEntitlement(
        sessionToken: String,
        mode: ClickyLaunchEntitlementSyncMode
    ) async throws -> ClickyBackendEntitlementPayload {
        switch mode {
        case .current:
            return try await client.fetchCurrentEntitlement(
                sessionToken: sessionToken
            ).entitlement
        case .refresh:
            return try await client.refreshCurrentEntitlement(
                sessionToken: sessionToken
            ).entitlement
        case .restore:
            return try await client.restoreLaunchAccess(
                sessionToken: sessionToken
            ).entitlement
        }
    }

    private func loadTrialSnapshotLeniently(
        sessionToken: String
    ) async -> ClickyBackendTrialPayload? {
        do {
            return try await client.fetchCurrentTrial(sessionToken: sessionToken).trial
        } catch {
            ClickyUnifiedTelemetry.billing.debug(
                "Launch trial snapshot unavailable during session sync error=\(error.localizedDescription, privacy: .public)"
            )
            ClickyLogger.debug(.app, "Launch trial snapshot unavailable during session sync error=\(error.localizedDescription)")
            return nil
        }
    }
}
