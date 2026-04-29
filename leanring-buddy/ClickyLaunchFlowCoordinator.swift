//
//  ClickyLaunchFlowCoordinator.swift
//  leanring-buddy
//
//  User-initiated launch auth, billing, and entitlement flows.
//

import AppKit
import Foundation
import os

@MainActor
final class ClickyLaunchFlowCoordinator {
    private let authClient: ClickyBackendAuthClient
    private let accessController: ClickyLaunchAccessController
    private let sessionService: ClickyLaunchSessionService

    init(
        authClient: ClickyBackendAuthClient,
        accessController: ClickyLaunchAccessController,
        sessionService: ClickyLaunchSessionService
    ) {
        self.authClient = authClient
        self.accessController = accessController
        self.sessionService = sessionService
    }

    func startSignIn() {
        ClickyUnifiedTelemetry.launchAuth.info("Launch auth sign-in requested")
        ClickyLogger.notice(.app, "Starting Clicky launch sign-in")

        Task { @MainActor in
            do {
                let payload = try await authClient.startNativeSignIn()
                guard let browserURL = URL(string: payload.browserURL) else {
                    throw ClickyBackendAuthClientError.invalidBackendURL
                }

                let didOpenBrowser = NSWorkspace.shared.open(browserURL)
                accessController.setAuthState(.signingIn, reason: "sign-in-browser-opened")
                ClickyUnifiedTelemetry.launchAuth.info(
                    "Launch auth sign-in browser opened success=\(didOpenBrowser ? "true" : "false", privacy: .public)"
                )
            } catch {
                accessController.setAuthState(.failed(message: error.localizedDescription), reason: "sign-in-start-failed")
                ClickyUnifiedTelemetry.launchAuth.error(
                    "Launch auth sign-in failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to start Clicky launch sign-in error=\(error.localizedDescription)")
            }
        }
    }

    func signOut() {
        ClickyAuthSessionStore.clear()
        accessController.clearSessionState(reason: "sign-out")
        ClickyUnifiedTelemetry.launchAuth.info("Launch auth sign-out completed")
        ClickyLogger.notice(.app, "Cleared Clicky launch auth session")
    }

    func startCheckout() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            accessController.setBillingState(.failed(message: "Sign in before starting checkout."), reason: "checkout-blocked-no-session")
            ClickyUnifiedTelemetry.billing.info("Checkout blocked reason=no-session")
            ClickyLogger.error(.app, "Checkout blocked because no launch auth session is available")
            return
        }

        accessController.setBillingState(.openingCheckout, reason: "checkout-requested")
        ClickyUnifiedTelemetry.billing.info("Checkout requested")
        ClickyLogger.notice(.app, "Starting Polar checkout")

        Task { @MainActor in
            do {
                let checkoutPayload = try await authClient.createCheckoutSession(sessionToken: storedSession.sessionToken)
                guard let checkoutURL = URL(string: checkoutPayload.checkout.url) else {
                    throw ClickyBackendAuthClientError.invalidBackendURL
                }

                let didOpenBrowser = NSWorkspace.shared.open(checkoutURL)
                accessController.setBillingState(.waitingForCompletion, reason: "checkout-browser-opened")
                ClickyUnifiedTelemetry.billing.info(
                    "Checkout browser opened success=\(didOpenBrowser ? "true" : "false", privacy: .public)"
                )
                ClickyLogger.notice(.app, "Opened Polar checkout")
            } catch {
                accessController.setBillingState(.failed(message: error.localizedDescription), reason: "checkout-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Checkout failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to start Polar checkout error=\(error.localizedDescription)")
            }
        }
    }

    func refreshEntitlement() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            accessController.clearSessionState(reason: "manual-entitlement-refresh-no-session")
            ClickyUnifiedTelemetry.billing.info("Entitlement refresh blocked reason=no-session")
            ClickyLogger.error(.app, "Entitlement refresh blocked because no launch auth session is available")
            return
        }

        ClickyUnifiedTelemetry.billing.info("Entitlement refresh requested source=manual")
        ClickyLogger.info(.app, "Refreshing launch entitlement")

        Task { @MainActor in
            do {
                let refreshedSnapshot = try await sessionService.synchronizeSessionSnapshot(
                    sessionToken: storedSession.sessionToken,
                    fallbackUserID: storedSession.userID,
                    fallbackEmail: storedSession.email,
                    entitlementSyncMode: .refresh
                )
                try accessController.persistSessionSnapshot(refreshedSnapshot, reason: "manual-entitlement-refresh")
                if refreshedSnapshot.entitlement.hasAccess {
                    accessController.setBillingState(.completed, reason: "manual-entitlement-refresh")
                }
                ClickyUnifiedTelemetry.billing.info(
                    "Entitlement refresh completed source=manual access=\(refreshedSnapshot.entitlement.hasAccess ? "true" : "false", privacy: .public) status=\(refreshedSnapshot.entitlement.status, privacy: .public)"
                )
                ClickyLogger.notice(.app, "Launch entitlement refresh completed")
            } catch {
                accessController.setBillingState(.failed(message: error.localizedDescription), reason: "manual-entitlement-refresh-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Entitlement refresh failed source=manual error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to refresh Clicky launch entitlement error=\(error.localizedDescription)")
            }
        }
    }

    func restoreAccess() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            accessController.setBillingState(.failed(message: "Sign in before restoring access."), reason: "restore-blocked-no-session")
            ClickyUnifiedTelemetry.billing.info("Restore access blocked reason=no-session")
            ClickyLogger.error(.app, "Restore blocked because no launch auth session is available")
            return
        }

        accessController.setBillingState(.waitingForCompletion, reason: "restore-requested")
        ClickyUnifiedTelemetry.billing.info("Restore access requested")
        ClickyLogger.info(.app, "Restoring launch access")

        Task { @MainActor in
            do {
                let restoredSnapshot = try await sessionService.synchronizeSessionSnapshot(
                    sessionToken: storedSession.sessionToken,
                    fallbackUserID: storedSession.userID,
                    fallbackEmail: storedSession.email,
                    entitlementSyncMode: .restore
                )
                try accessController.persistSessionSnapshot(restoredSnapshot, reason: "restore-access")
                accessController.setBillingState(
                    restoredSnapshot.entitlement.hasAccess ? .completed : .idle,
                    reason: "restore-access"
                )
                ClickyUnifiedTelemetry.billing.info(
                    "Restore access completed access=\(restoredSnapshot.entitlement.hasAccess ? "true" : "false", privacy: .public) status=\(restoredSnapshot.entitlement.status, privacy: .public)"
                )
                ClickyLogger.notice(.app, "Restore launch access completed")
            } catch {
                accessController.setBillingState(.failed(message: error.localizedDescription), reason: "restore-access-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Restore access failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to restore Clicky launch access error=\(error.localizedDescription)")
            }
        }
    }

    func handleCallback(url: URL) {
        guard url.scheme?.lowercased() == "clicky" else { return }

        if url.host?.lowercased() == "auth", url.path == "/callback" {
            ClickyUnifiedTelemetry.launchAuth.info("Launch auth callback received")
            ClickyLogger.notice(.app, "Received Clicky auth callback")
            handleAuthCallback(url: url)
            return
        }

        if url.host?.lowercased() == "billing", url.path == "/success" {
            accessController.setBillingState(.completed, reason: "billing-callback-success")
            ClickyUnifiedTelemetry.billing.info("Billing callback received outcome=success")
            ClickyLogger.notice(.app, "Received Clicky billing success callback")
            refreshEntitlement()
            return
        }

        if url.host?.lowercased() == "billing", url.path == "/cancel" {
            accessController.setBillingState(.canceled, reason: "billing-callback-cancel")
            ClickyUnifiedTelemetry.billing.info("Billing callback received outcome=cancel")
            ClickyLogger.notice(.app, "Received Clicky billing cancel callback")
        }
    }

    private func handleAuthCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let exchangeCode = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !exchangeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            accessController.setAuthState(
                .failed(message: ClickyBackendAuthClientError.missingExchangeCode.localizedDescription),
                reason: "auth-callback-missing-code"
            )
            ClickyUnifiedTelemetry.launchAuth.error("Launch auth callback missing exchange code")
            return
        }

        accessController.setAuthState(.signingIn, reason: "auth-callback-received")
        ClickyUnifiedTelemetry.launchAuth.info("Launch auth exchange started")

        Task { @MainActor in
            do {
                let exchangePayload = try await authClient.exchangeNativeCode(exchangeCode)
                let snapshot = try await sessionService.synchronizeSessionSnapshot(
                    sessionToken: exchangePayload.sessionToken,
                    fallbackUserID: exchangePayload.userID
                )

                try accessController.persistSessionSnapshot(snapshot, reason: "auth-exchange")
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .clickyOpenStudio, object: nil)
                ClickyUnifiedTelemetry.launchAuth.info("Launch auth exchange completed")
                ClickyLogger.notice(.app, "Completed Clicky launch auth exchange")
            } catch {
                accessController.setAuthState(.failed(message: error.localizedDescription), reason: "auth-exchange-failed")
                accessController.clickyLaunchEntitlementStatusLabel = "Unknown"
                ClickyUnifiedTelemetry.launchAuth.error(
                    "Launch auth exchange failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to complete Clicky launch auth exchange error=\(error.localizedDescription)")
            }
        }
    }
}
