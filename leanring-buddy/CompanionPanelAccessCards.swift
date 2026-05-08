//
//  CompanionPanelAccessCards.swift
//  leanring-buddy
//
//  Onboarding, permission, active-summary, and locked-state cards for the
//  menu-bar companion panel.
//

import SwiftUI

struct CompanionPanelOnboardingWelcomeCard: View {
    let continueFromWelcome: () -> Void
    let openStudio: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                CompanionPanelSectionEyebrow("What Clicky Does")

                CompanionPanelOnboardingBullet("Understand the software in front of you.")
                CompanionPanelOnboardingBullet("Teach you the next step in plain language.")
                CompanionPanelOnboardingBullet("Point exactly where you should look or click.")
            }

            HStack(spacing: 10) {
                Button(action: continueFromWelcome) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle(attentionMode: .singlePulse))
                .pointerCursor()

                Button(action: openStudio) {
                    Text("Open Studio")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }
}

struct CompanionPanelSignInCard: View {
    let authState: ClickyLaunchAuthState
    let showsWhyCopy: Bool
    let primaryAction: () -> Void
    let toggleWhyCopy: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(summaryCopy)
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(contentTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if showsWhyCopy {
                Text("Clicky keeps credits, restore, and purchase state on your account so it stays with you across reinstalls and future upgrades.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                Button(action: primaryAction) {
                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor(isEnabled: !isAuthPending)
                .disabled(isAuthPending)

                Button(action: toggleWhyCopy) {
                    Text(showsWhyCopy ? "Hide" : "Why?")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var summaryCopy: String {
        switch authState {
        case .restoring:
            return "Clicky is restoring your session right now. Stay here for a moment while it checks your account and access."
        case .signingIn:
            return "Finish sign-in in your browser. Once the callback completes, Clicky will move you to the next step automatically."
        case .failed(let message):
            return message
        case .signedIn:
            return "You're signed in. Continue and Clicky will guide you through the remaining setup."
        case .signedOut:
            return "Once you're in, Clicky is ready to help across your work until your included credits run out."
        }
    }

    private var primaryButtonTitle: String {
        switch authState {
        case .signingIn:
            return "Waiting…"
        case .restoring:
            return "Restoring…"
        case .signedOut, .failed:
            return "Sign In"
        case .signedIn:
            return "Continue"
        }
    }

    private var isAuthPending: Bool {
        switch authState {
        case .restoring, .signingIn:
            return true
        case .signedOut, .signedIn, .failed:
            return false
        }
    }
}

struct CompanionPanelOnboardingReadyCard: View {
    let startUsingClicky: () -> Void
    let openStudio: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                CompanionPanelSectionEyebrow("You Can Now")

                CompanionPanelOnboardingBullet("Ask what this software is doing.")
                CompanionPanelOnboardingBullet("Learn the next step while staying in context.")
                CompanionPanelOnboardingBullet("Follow the pointer when Clicky wants to show you where to look.")
            }

            HStack(spacing: 10) {
                Button(action: startUsingClicky) {
                    Text("Start Using Clicky")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()

                Button(action: openStudio) {
                    Text("Open Studio")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }
}

struct CompanionPanelCurrentFeelCard: View {
    let personaLabel: String
    let voicePreset: ClickyVoicePreset
    let cursorStyle: ClickyCursorStyle
    let creditsLabel: String
    let hasUnlimitedAccess: Bool
    let selectedBackend: CompanionAgentBackend
    let setSelectedBackend: (CompanionAgentBackend) -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    CompanionPanelSectionEyebrow("Current Feel")

                    Text(personaLabel)
                        .font(ClickyTypography.section(size: 20))
                        .foregroundColor(contentTheme.textPrimary)

                    Text("\(voicePreset.displayName) voice  ·  \(cursorStyle.displayName) cursor")
                        .font(ClickyTypography.mono(size: 10, weight: .medium))
                        .foregroundColor(contentTheme.textMuted)
                }

                Spacer()

                CompanionCreditsChip(
                    label: creditsLabel.uppercased(),
                    tone: hasUnlimitedAccess ? .success : .neutral
                )
            }

            CompanionPanelHairline()

            VStack(alignment: .leading, spacing: 8) {
                CompanionPanelSectionEyebrow("Companion")
                CompanionPanelBackendButtons(
                    selectedBackend: selectedBackend,
                    setSelectedBackend: setSelectedBackend
                )
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }
}

struct CompanionPanelLockedStateCard: View {
    let showsStudioChip: Bool
    let startCheckout: () -> Void
    let signOut: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        CompanionPanelSectionEyebrow("Unlock Clicky")
                        Spacer()
                        Text("$49")
                            .font(ClickyTypography.section(size: 20))
                            .foregroundColor(contentTheme.textPrimary)
                    }

                    Text("One payment to continue learning, asking, and getting guided help in context.")
                        .font(ClickyTypography.body(size: 13))
                        .foregroundColor(contentTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: startCheckout) {
                    Text("Pay Now")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle(attentionMode: .loopingPulse))
                .pointerCursor()

                Button(action: signOut) {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    CompanionPanelSectionEyebrow("Studio")
                    Spacer()
                    if showsStudioChip {
                        CompanionPanelInlineStatus(label: "Locked", tone: .warning)
                            .transition(.opacity)
                    }
                }

                Text("Studio stays available for account repair and restore paths while companion use stays locked until upgrade.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }
}

struct CompanionPanelPermissionsCard: View {
    let rows: [CompanionPanelPermissionRow]
    let primaryTitle: String?
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { row in
                    CompanionPanelPermissionRowView(row: row)
                        .transition(.opacity)
                    if row.id != rows.last?.id {
                        CompanionPanelHairline()
                    }
                }
            }

            if let primaryTitle {
                HStack(spacing: 10) {
                    Button(action: primaryAction) {
                        Text(primaryTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .modifier(ClickyProminentActionStyle())
                    .pointerCursor()

                    if let secondaryTitle, let secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .modifier(ClickySecondaryGlassButtonStyle())
                        .pointerCursor()
                    }
                }
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }
}

private struct CompanionPanelPermissionRowView: View {
    let row: CompanionPanelPermissionRow

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(row.state.dotColor(theme))
                .frame(width: 10, height: 10)
                .scaleEffect(row.state == .granted ? 1.12 : 1.0)
                .padding(.top, 6)
                .animation(.easeInOut(duration: 0.16), value: row.state)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(contentTheme.textPrimary)

                Text(row.detail)
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if row.state == .granted {
                    CompanionPanelInlineStatus(label: "Granted", tone: .success)
                        .transition(.opacity)
                } else {
                    Button(action: row.primaryAction) {
                        Text(row.primaryTitle)
                    }
                    .modifier(ClickyProminentActionStyle())
                    .pointerCursor()
                    if let secondaryTitle = row.secondaryTitle,
                       let secondaryAction = row.secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                        }
                        .modifier(ClickySecondaryGlassButtonStyle())
                        .pointerCursor()
                    }
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(row.state.backgroundColor(theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(row.state.borderColor(theme), lineWidth: 0.8)
        )
        .animation(.easeInOut(duration: 0.22), value: row.state)
    }
}
