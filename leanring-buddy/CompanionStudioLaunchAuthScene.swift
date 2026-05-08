//
//  CompanionStudioLaunchAuthScene.swift
//  leanring-buddy
//
//  Launch access gate shown before normal Studio scenes are available.
//

import SwiftUI

struct CompanionStudioLaunchAuthScene: View {
    let companionManager: CompanionManager
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
    }

    private var clickyLaunchAuthState: ClickyLaunchAuthState {
        launchAccessController.clickyLaunchAuthState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CompanionStudioReadableCard(
                eyebrow: "Welcome",
                title: launchGateTitle
            ) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(launchGateCopy)
                                .font(ClickyTypography.body(size: 15))
                                .foregroundColor(palette.cardSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                ForEach(launchGateChips, id: \.self) { chip in
                                    CompanionStudioGlassChip(text: chip)
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        CompanionStudioAccessAvatar(
                            initials: "CL",
                            imageURL: "",
                            palette: palette
                        )
                    }

                    CompanionStudioHairline()

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            launchMomentCard(
                                eyebrow: "01",
                                title: "Sign in once",
                                copy: "Tie your Clicky taste, purchase state, and restore flow to your account."
                            )
                            launchMomentCard(
                                eyebrow: "02",
                                title: "Let Studio settle",
                                copy: "Clicky quietly restores and refreshes access in the background as soon as the app loads."
                            )
                            launchMomentCard(
                                eyebrow: "03",
                                title: "Drop into work",
                                copy: "Once auth is ready, the normal Studio surfaces take over and the companion is ready to help."
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            launchMomentCard(
                                eyebrow: "01",
                                title: "Sign in once",
                                copy: "Tie your Clicky taste, purchase state, and restore flow to your account."
                            )
                            launchMomentCard(
                                eyebrow: "02",
                                title: "Let Studio settle",
                                copy: "Clicky quietly restores and refreshes access in the background as soon as the app loads."
                            )
                            launchMomentCard(
                                eyebrow: "03",
                                title: "Drop into work",
                                copy: "Once auth is ready, the normal Studio surfaces take over and the companion is ready to help."
                            )
                        }
                    }

                    launchGateAction
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .topLeading)
    }

    private var launchGateTitle: String {
        switch clickyLaunchAuthState {
        case .restoring:
            return "Loading Your Studio"
        case .signingIn:
            return "Finishing Sign-In"
        case .failed:
            return "Sign In To Continue"
        case .signedOut:
            return "Start With Your Account"
        case .signedIn:
            return "Loading Your Studio"
        }
    }

    private var launchGateCopy: String {
        switch clickyLaunchAuthState {
        case .restoring:
            return "Clicky is restoring your session and checking access in the background so Studio can open in the right state."
        case .signingIn:
            return "Your browser sign-in is in flight. As soon as the callback lands, Studio will switch over to your normal account and access view."
        case .failed(let message):
            return "Clicky couldn’t finish signing you in yet. Start the sign-in again from here and Studio will continue as soon as your account is connected. \(message)"
        case .signedOut:
            return "Sign in to make Clicky yours on this Mac. That gives the app a real account home for your included taste, purchase state, and future restores."
        case .signedIn:
            return "Clicky is getting Studio ready."
        }
    }

    private var launchGateChips: [String] {
        switch clickyLaunchAuthState {
        case .restoring:
            return ["Restoring session", "Checking access"]
        case .signingIn:
            return ["Waiting for browser sign-in"]
        case .failed:
            return ["Sign-in needs attention"]
        case .signedOut:
            return ["Account required"]
        case .signedIn:
            return ["Loading"]
        }
    }

    @ViewBuilder
    private var launchGateAction: some View {
        switch clickyLaunchAuthState {
        case .restoring, .signingIn:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(clickyLaunchAuthState == .restoring ? "Restoring your Clicky session..." : "Waiting for the browser to hand auth back...")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
            }
            .padding(.vertical, 6)
        case .signedOut, .failed:
            Button {
                companionManager.launchFlowCoordinator.startSignIn()
            } label: {
                Label("Continue With Google", systemImage: "person.crop.circle.badge.plus")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 200)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        case .signedIn:
            EmptyView()
        }
    }

    private func launchMomentCard(eyebrow: String, title: String, copy: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(title)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)

            Text(copy)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardAccent.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }
}
