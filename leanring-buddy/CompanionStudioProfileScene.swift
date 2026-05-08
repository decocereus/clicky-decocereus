//
//  CompanionStudioProfileScene.swift
//  leanring-buddy
//
//  Account, access, and app upkeep surface for the Studio window.
//

import SwiftUI

struct CompanionStudioProfileScene: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    @ObservedObject private var backendRoutingController: ClickyBackendRoutingController
    @ObservedObject private var surfaceController: ClickySurfaceController
    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
        _backendRoutingController = ObservedObject(wrappedValue: companionManager.backendRoutingController)
        _surfaceController = ObservedObject(wrappedValue: companionManager.surfaceController)
    }

    private var clickyLaunchBillingStatusLabel: String {
        ClickyLaunchPresentation.billingStatusLabel(for: launchAccessController.clickyLaunchBillingState)
    }

    private var clickyLaunchTrialStatusLabel: String {
        ClickyLaunchPresentation.trialStatusLabel(for: launchAccessController.clickyLaunchTrialState)
    }

    private var isClickyLaunchSignedIn: Bool {
        ClickyLaunchPresentation.isSignedIn(launchAccessController.clickyLaunchAuthState)
    }

    private var hasUnlimitedClickyLaunchAccess: Bool {
        ClickyLaunchPresentation.hasUnlimitedAccess(launchAccessController.clickyLaunchTrialState)
    }

    private var clickyLaunchDisplayName: String {
        ClickyLaunchPresentation.displayName(
            profileName: launchAccessController.clickyLaunchProfileName,
            authState: launchAccessController.clickyLaunchAuthState
        )
    }

    private var clickyLaunchDisplayInitials: String {
        ClickyLaunchPresentation.initials(for: clickyLaunchDisplayName)
    }

    private var isClickyLaunchPaywallActive: Bool {
        if let storedSession = ClickyAuthSessionStore.load() {
            return !storedSession.entitlement.hasAccess && storedSession.trial?.status == "paywalled"
        }

        if case .paywalled = launchAccessController.clickyLaunchTrialState {
            return true
        }

        return false
    }

    private var requiresLaunchSignInForCompanionUse: Bool {
        let allPermissionsGranted = surfaceController.hasAccessibilityPermission
            && surfaceController.hasScreenRecordingPermission
            && surfaceController.hasMicrophonePermission
            && surfaceController.hasScreenContentPermission

        guard preferences.hasCompletedOnboarding && allPermissionsGranted else {
            return false
        }

        if isClickyLaunchPaywallActive {
            return false
        }

        switch launchAccessController.clickyLaunchAuthState {
        case .signedOut, .failed:
            return true
        case .restoring, .signingIn, .signedIn:
            return false
        }
    }

    private var clickyLaunchAuthStatusLabel: String {
        ClickyLaunchPresentation.authStatusLabel(for: launchAccessController.clickyLaunchAuthState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CompanionStudioReadableCard(
                eyebrow: "Profile",
                title: "Your Account"
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 14) {
                        CompanionStudioAccessAvatar(
                            initials: clickyLaunchDisplayInitials,
                            imageURL: launchAccessController.clickyLaunchProfileImageURL,
                            palette: palette
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(clickyLaunchDisplayName)
                                .font(ClickyTypography.section(size: 24))
                                .foregroundColor(palette.cardPrimaryText)
                                .lineLimit(1)

                            Text(profileHeaderSubtitle)
                                .font(ClickyTypography.body(size: 13))
                                .foregroundColor(palette.cardSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    Text("This page keeps your account, purchase state, and app maintenance in one calm place so the companion can stay focused on helping you work.")
                        .font(ClickyTypography.body(size: 14))
                        .foregroundColor(palette.cardSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        ForEach(profileChipLabels, id: \.self) { label in
                            CompanionStudioGlassChip(text: label)
                        }
                    }
                }
            }
            .task(id: profileBackgroundSyncToken) {
                guard isClickyLaunchSignedIn else {
                    return
                }

                companionManager.launchRuntimeCoordinator.refreshEntitlementQuietlyIfNeeded(
                    reason: "studio-profile-scene",
                    minimumInterval: 15
                )
            }

            HStack(alignment: .top, spacing: 18) {
                CompanionStudioReadableCard(
                    eyebrow: "Account",
                    title: profileAccessTitle
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        if hasUnlimitedClickyLaunchAccess {
                            CompanionStudioAccessCelebrationCard()
                        } else {
                            Text(profileAccessCopy)
                                .font(ClickyTypography.body(size: 14))
                                .foregroundColor(palette.cardSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 12) {
                            CompanionStudioKeyValueRow(label: "Signed in", value: isClickyLaunchSignedIn ? "Yes" : "Not yet")
                            CompanionStudioKeyValueRow(label: "Account", value: clickyLaunchDisplayName)
                            CompanionStudioKeyValueRow(label: "Purchase", value: profilePurchaseStatusLabel)

                            if showsProfileCreditsRow {
                                CompanionStudioKeyValueRow(label: "Credits", value: clickyLaunchTrialStatusLabel)
                            }

                            if showsProfileCheckoutRow {
                                CompanionStudioKeyValueRow(label: "Checkout", value: clickyLaunchBillingStatusLabel)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            profilePrimaryAction
                            profileSecondaryActions
                        }
                    }
                }

                CompanionStudioReadableCard(
                    eyebrow: "App",
                    title: "Keep Clicky Up To Date"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use this space for app upkeep while the rest of Clicky stays about guidance and flow. Updates belong here, not in the daily companion surface.")
                            .font(ClickyTypography.body(size: 14))
                            .foregroundColor(palette.cardSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            NotificationCenter.default.post(name: .clickyCheckForUpdates, object: nil)
                        } label: {
                            Label("Check for Updates", systemImage: "arrow.down.circle")
                                .font(ClickyTypography.body(size: 13, weight: .semibold))
                                .frame(minWidth: 180)
                        }
                        .modifier(CompanionStudioPrimaryButtonModifier())
                        .pointerCursor()

                        Text("App updates, account state, and subscription access live here so the companion surface can stay focused on helping you get work done.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var profileHeaderSubtitle: String {
        if hasUnlimitedClickyLaunchAccess {
            return "Subscription active on this Mac."
        }

        if requiresLaunchSignInForCompanionUse {
            return "Sign in to start your Clicky taste and keep access tied to you."
        }

        if isClickyLaunchPaywallActive {
            return "Your trial wrapped up. Unlock Clicky here when you’re ready for unlimited use."
        }

        return "Your account and access are quietly syncing in the background."
    }

    private var profileChipLabels: [String] {
        if hasUnlimitedClickyLaunchAccess {
            return ["Subscription active", "Signed in"]
        }

        if requiresLaunchSignInForCompanionUse {
            return ["Sign in required"]
        }

        if isClickyLaunchPaywallActive {
            return ["Trial finished", "Unlock available"]
        }

        if clickyLaunchBillingStatusLabel == "Waiting for purchase" {
            return ["Finishing purchase", "Signed in"]
        }

        return isClickyLaunchSignedIn ? ["Signed in", "Ready on this Mac"] : ["Account not connected"]
    }

    private var profileAccessTitle: String {
        if hasUnlimitedClickyLaunchAccess {
            return "Full Access"
        }

        if requiresLaunchSignInForCompanionUse {
            return "Get Started"
        }

        if isClickyLaunchPaywallActive {
            return "Unlock Clicky"
        }

        return "Your Access"
    }

    private var profileAccessCopy: String {
        if requiresLaunchSignInForCompanionUse {
            return "Sign in once and Clicky will keep your trial, purchase state, and future restore tied to your account."
        }

        if isClickyLaunchPaywallActive {
            return "You’ve already had the taste. Unlock Clicky to keep talking to it without limits."
        }

        if clickyLaunchBillingStatusLabel == "Waiting for purchase" {
            return "Your purchase is being checked in the background. This screen should update on its own as soon as the backend confirms it."
        }

        return "Your account is active on this Mac, and Clicky is keeping access in sync behind the scenes."
    }

    private var profilePurchaseStatusLabel: String {
        if hasUnlimitedClickyLaunchAccess {
            return "Active"
        }

        if requiresLaunchSignInForCompanionUse {
            return "Not connected"
        }

        if isClickyLaunchPaywallActive {
            return "Needs unlock"
        }

        if clickyLaunchBillingStatusLabel == "Waiting for purchase" {
            return "Checking purchase"
        }

        return "Taste available"
    }

    private var showsProfileCreditsRow: Bool {
        !hasUnlimitedClickyLaunchAccess
    }

    private var showsProfileCheckoutRow: Bool {
        isClickyLaunchSignedIn
            && !hasUnlimitedClickyLaunchAccess
            && clickyLaunchBillingStatusLabel != "Idle"
    }

    private var profileBackgroundSyncToken: String {
        [
            clickyLaunchAuthStatusLabel,
            clickyLaunchBillingStatusLabel,
            clickyLaunchTrialStatusLabel,
            launchAccessController.clickyLaunchProfileImageURL
        ].joined(separator: "|")
    }

    @ViewBuilder
    private var profilePrimaryAction: some View {
        if requiresLaunchSignInForCompanionUse {
            Button {
                companionManager.launchFlowCoordinator.startSignIn()
            } label: {
                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 150)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        } else if isClickyLaunchPaywallActive {
            Button {
                companionManager.launchFlowCoordinator.startCheckout()
            } label: {
                Label("Unlock Clicky", systemImage: "creditcard")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 150)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        }
    }

    @ViewBuilder
    private var profileSecondaryActions: some View {
        if isClickyLaunchSignedIn {
            Button {
                companionManager.launchFlowCoordinator.signOut()
            } label: {
                Text("Sign Out")
                    .font(ClickyTypography.body(size: 12, weight: .semibold))
                    .foregroundColor(palette.cardSecondaryText)
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
    }
}
