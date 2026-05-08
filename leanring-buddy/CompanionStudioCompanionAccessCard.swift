//
//  CompanionStudioCompanionAccessCard.swift
//  leanring-buddy
//
//  Launch access and account card for the Companion Studio scene.
//

import SwiftUI

struct CompanionStudioCompanionAccessCard: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    @ObservedObject private var surfaceController: ClickySurfaceController

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
        _surfaceController = ObservedObject(wrappedValue: companionManager.surfaceController)
    }

    private var launchAccess: CompanionStudioLaunchAccessSnapshot {
        CompanionStudioLaunchAccessSnapshot(
            authState: launchAccessController.clickyLaunchAuthState,
            billingState: launchAccessController.clickyLaunchBillingState,
            trialState: launchAccessController.clickyLaunchTrialState,
            profileName: launchAccessController.clickyLaunchProfileName,
            profileImageURL: launchAccessController.clickyLaunchProfileImageURL,
            hasCompletedOnboarding: preferences.hasCompletedOnboarding,
            hasAccessibilityPermission: surfaceController.hasAccessibilityPermission,
            hasScreenRecordingPermission: surfaceController.hasScreenRecordingPermission,
            hasMicrophonePermission: surfaceController.hasMicrophonePermission,
            hasScreenContentPermission: surfaceController.hasScreenContentPermission
        )
    }

    var body: some View {
        CompanionStudioReadableCard(
            eyebrow: "Access",
            title: "Your Access"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                accountHeader

                if launchAccess.hasUnlimitedAccess {
                    CompanionStudioAccessCelebrationCard()
                } else {
                    Text(summaryCopy)
                        .font(ClickyTypography.body(size: 14))
                        .foregroundColor(palette.cardSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    ForEach(chipLabels, id: \.self) { label in
                        CompanionStudioGlassChip(text: label)
                    }
                }

                VStack(spacing: 12) {
                    CompanionStudioKeyValueRow(label: "Account", value: launchAccess.displayName)

                    if !launchAccess.hasUnlimitedAccess {
                        if launchAccess.isSignedIn {
                            CompanionStudioKeyValueRow(label: "Access", value: statusLine)
                        }

                        if showsTrialRow {
                            CompanionStudioKeyValueRow(label: "Trial", value: launchAccess.trialStatusLabel)
                        }

                        if showsCheckoutRow {
                            CompanionStudioKeyValueRow(label: "Checkout", value: launchAccess.billingStatusLabel)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    primaryAction
                    secondaryActions
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task(id: backgroundSyncToken) {
            guard launchAccess.isSignedIn else {
                return
            }

            companionManager.launchRuntimeCoordinator.refreshEntitlementQuietlyIfNeeded(
                reason: "studio-access-card",
                minimumInterval: 15
            )
        }
    }

    private var summaryCopy: String {
        if launchAccess.hasUnlimitedAccess {
            return "Your subscription is live. Clicky is fully unlocked here, so you can talk to it as much as you want."
        }

        if launchAccess.requiresSignInForCompanionUse {
            return "Sign in to start your Clicky trial and keep your access tied to your account."
        }

        if launchAccess.isPaywallActive {
            return "Your included taste is finished. Unlock Clicky to keep the companion with you across as many turns as you want."
        }

        if launchAccess.billingStatusLabel == "Waiting for purchase" {
            return "Clicky is checking your purchase in the background so this Mac can unlock itself as soon as it lands."
        }

        return "Your account is in good shape, and Clicky is quietly keeping your access up to date on this Mac."
    }

    private var accountHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            CompanionStudioAccessAvatar(
                initials: launchAccess.displayInitials,
                imageURL: launchAccessController.clickyLaunchProfileImageURL,
                palette: palette
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(launchAccess.displayName)
                    .font(ClickyTypography.section(size: 24))
                    .foregroundColor(palette.cardPrimaryText)
                    .lineLimit(1)

                Text(headerSubtitle)
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var headerSubtitle: String {
        if launchAccess.hasUnlimitedAccess {
            return "You’re fully unlocked on this Mac."
        }

        if launchAccess.requiresSignInForCompanionUse {
            return "Sign in once to tie your trial and future access to your account."
        }

        if launchAccess.isPaywallActive {
            return "Your trial has wrapped, but this is where Clicky can unlock for good."
        }

        return "Clicky keeps this Mac in sync with your access in the background."
    }

    private var chipLabels: [String] {
        if launchAccess.hasUnlimitedAccess {
            return ["Subscription active", "Unlimited access"]
        }

        if launchAccess.requiresSignInForCompanionUse {
            return ["Sign in required"]
        }

        if launchAccess.isPaywallActive {
            return ["Trial finished", "Unlock available"]
        }

        if launchAccess.billingStatusLabel == "Waiting for purchase" {
            return ["Finishing purchase"]
        }

        return ["Ready on this Mac"]
    }

    private var statusLine: String {
        if launchAccess.isPaywallActive {
            return "Needs unlock"
        }

        if launchAccess.billingStatusLabel == "Waiting for purchase" {
            return "Checking purchase"
        }

        return "Ready to use"
    }

    private var showsTrialRow: Bool {
        !launchAccess.hasUnlimitedAccess
    }

    private var showsCheckoutRow: Bool {
        !launchAccess.hasUnlimitedAccess
            && launchAccess.isSignedIn
            && launchAccess.billingStatusLabel != "Idle"
    }

    private var backgroundSyncToken: String {
        [
            launchAccess.authStatusLabel,
            launchAccess.billingStatusLabel,
            launchAccess.trialStatusLabel
        ].joined(separator: "|")
    }

    @ViewBuilder
    private var primaryAction: some View {
        if launchAccess.requiresSignInForCompanionUse {
            Button {
                companionManager.launchFlowCoordinator.startSignIn()
            } label: {
                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 150)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        } else if launchAccess.isPaywallActive {
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
    private var secondaryActions: some View {
        if launchAccess.isSignedIn {
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
