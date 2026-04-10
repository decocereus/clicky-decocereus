//
//  CompanionPanelView.swift
//  leanring-buddy
//
//  The SwiftUI content hosted inside the menu bar panel. Shows the companion
//  voice status, push-to-talk shortcut, and quick settings. Designed to feel
//  like Loom's recording panel — dark, rounded, minimal, and special.
//

import AVFoundation
import SwiftUI

struct CompanionPanelView: View {
    @ObservedObject var companionManager: CompanionManager

    private var theme: ClickyTheme {
        companionManager.activeClickyTheme
    }

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        ClickyGlassCluster {
            panelShell
                .padding(12)
        }
        .clickyTheme(theme)
        .frame(width: 360)
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("clicky")
                    .font(ClickyTypography.brand(size: 30))
                    .foregroundColor(theme.primary)

                HStack(spacing: 8) {
                    panelStatusPill

                    if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
                        Text(companionManager.selectedAgentBackend.displayName)
                            .font(ClickyTypography.mono(size: 10, weight: .semibold))
                            .foregroundColor(theme.textMuted)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    openStudio()
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .modifier(ClickyTinyGlassCircleStyle())

                Button(action: {
                    NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .modifier(ClickyTinyGlassCircleStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var mainPanelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            permissionsCopySection

            if !companionManager.allPermissionsGranted {
                settingsSection
            }

            if !companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
                startButton
            }
        }
        .clickyGlassCard(cornerRadius: 28, padding: 18)
    }

    private var panelShell: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHeader

            panelHairline

            panelBody

            panelHairline

            footerSection
        }
        .modifier(ClickyPanelShellStyle())
    }

    private var panelBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            permissionsCopySection
                .modifier(ClickyPanelContentCardStyle(tone: .hero, padding: 16))

            if !companionManager.allPermissionsGranted {
                settingsSection
                    .modifier(ClickyPanelContentCardStyle(padding: 16))
            } else if !companionManager.hasCompletedOnboarding {
                startButton
            } else if companionManager.isClickyLaunchPaywallActive {
                paywallLockedSection
                    .modifier(ClickyPanelContentCardStyle(tone: .hero, padding: 16))
            } else if companionManager.requiresLaunchSignInForCompanionUse {
                launchAccessPromptSection
                    .modifier(ClickyPanelContentCardStyle(tone: .hero, padding: 16))
            } else {
                compactCompanionCard

                if companionManager.selectedAgentBackend == .claude {
                    claudeModelCard
                } else {
                    compactOpenClawCard
                }
            }
        }
    }

    private var panelStatusPill: some View {
        Text(statusText.uppercased())
            .font(ClickyTypography.mono(size: 10, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.primary.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 0.8)
            )
    }

    private var paywallLockedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelSectionEyebrow("Launch Access")

            Text("Clicky is locked")
                .font(ClickyTypography.section(size: 26))
                .foregroundColor(contentTheme.textPrimary)

            Text("Your trial credits are exhausted. Unlock Clicky to keep using the companion experience.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(contentTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                companionManager.startClickyLaunchCheckout()
            }) {
                Text("Buy Launch Pass")
                    .frame(maxWidth: .infinity)
            }
            .modifier(ClickyProminentActionStyle())
            .pointerCursor()
        }
    }

    private var launchAccessPromptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelSectionEyebrow("Launch Access")

            Text("Sign in to start your trial")
                .font(ClickyTypography.section(size: 22))
                .foregroundColor(contentTheme.textPrimary)

            Text("Clicky now starts the launch trial only after you sign in, so credits and restore stay tied to your account.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(contentTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: {
                    companionManager.startClickyLaunchSignIn()
                }) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()

                Button(action: {
                    openStudio()
                }) {
                    Text("Open Studio")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
    }

    private var backendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelSectionEyebrow("Agent")
            agentBackendPickerRow
        }
        .clickyGlassCard(cornerRadius: 28, padding: 18)
    }

    private var claudeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelSectionEyebrow("Claude")
            Text("Cloud voice guidance stays available here, while Studio handles deeper model and persona setup.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            modelPickerRow
        }
        .clickyGlassCard(cornerRadius: 28, padding: 18)
    }

    private var compactOpenClawCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelSectionEyebrow("OpenClaw")

            HStack {
                Text(companionManager.effectiveClickyPresentationName)
                    .font(ClickyTypography.section(size: 20))
                    .foregroundColor(contentTheme.textPrimary)

                Spacer()

                Circle()
                    .fill(openClawStatusColor)
                    .frame(width: 8, height: 8)
            }

            Text(openClawCompactSummary)
                .font(ClickyTypography.body(size: 12, weight: .medium))
                .foregroundColor(contentTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: {
                    openStudio()
                }) {
                    Text("Open Studio")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()

                Button(action: {
                    companionManager.testOpenClawConnection()
                }) {
                    Text("Test Gateway")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor(isEnabled: !isTestingOpenClawConnection)
                .disabled(isTestingOpenClawConnection)
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var compactCompanionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    panelSectionEyebrow("Persona")
                    Text(companionManager.activeClickyPersonaLabel)
                        .font(ClickyTypography.section(size: 20))
                        .foregroundColor(contentTheme.textPrimary)
                    Text("\(companionManager.effectiveClickyVoicePreset.displayName) voice · \(companionManager.effectiveClickyCursorStyle.displayName) cursor")
                        .font(ClickyTypography.mono(size: 10, weight: .medium))
                        .foregroundColor(contentTheme.textMuted)
                }

                Spacer()

                Circle()
                    .fill(theme.primary)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
            }

            Rectangle()
                .fill(contentTheme.strokeSoft)
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                panelSectionEyebrow("Routing")
                agentBackendPickerRow
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var claudeModelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelSectionEyebrow("Claude")
            modelPickerRow
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var openClawSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                panelSectionEyebrow("OpenClaw")
                Spacer()
                Circle()
                    .fill(openClawStatusColor)
                    .frame(width: 8, height: 8)
            }

            Text(companionManager.effectiveClickyPresentationName)
                .font(ClickyTypography.section(size: 28))
                .foregroundColor(theme.textPrimary)

            Text(openClawPanelSummary)
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                openStudio()
            }) {
                Text("Open Studio for Connection Settings")
                    .frame(maxWidth: .infinity)
            }
            .modifier(ClickyProminentActionStyle())
            .pointerCursor()
        }
        .clickyGlassCard(cornerRadius: 28, padding: 18)
    }

    // MARK: - Permissions Copy

    @ViewBuilder
    private var permissionsCopySection: some View {
        if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
            Text("Hold Control+Option to talk.")
                .font(ClickyTypography.body(size: 15, weight: .semibold))
                .foregroundColor(contentTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if companionManager.allPermissionsGranted {
            Text("You're all set. Hit Start to meet Clicky.")
                .font(ClickyTypography.body(size: 15, weight: .semibold))
                .foregroundColor(contentTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if companionManager.hasCompletedOnboarding {
            // Permissions were revoked after onboarding — tell user to re-grant
            VStack(alignment: .leading, spacing: 6) {
                Text("Permissions needed")
                    .font(ClickyTypography.section(size: 22))
                    .foregroundColor(contentTheme.textPrimary)

                Text("Some permissions were revoked. Grant all four below to keep using Clicky.")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Learn with an agent that stays right next to you.")
                    .font(ClickyTypography.section(size: 24))
                    .foregroundColor(contentTheme.textPrimary)

                Text("Clicky only looks when you ask it to. Use the hotkey, speak naturally, and let the assistant guide you on top of your real screen.")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Start Button

    @ViewBuilder
    private var startButton: some View {
        if !companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
            Button(action: {
                companionManager.triggerOnboarding()
            }) {
                Text("Start")
                    .frame(maxWidth: .infinity)
            }
            .modifier(ClickyProminentActionStyle())
            .pointerCursor()
        }
    }

    // MARK: - Permissions

    private var settingsSection: some View {
        VStack(spacing: 4) {
            Text("PERMISSIONS")
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(contentTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            microphonePermissionRow

            accessibilityPermissionRow

            screenRecordingPermissionRow

            if companionManager.hasScreenRecordingPermission {
                screenContentPermissionRow
            }

        }
    }

    private var accessibilityPermissionRow: some View {
        let isGranted = companionManager.hasAccessibilityPermission
        return panelPermissionRow(
            label: "Accessibility",
            systemImage: "hand.raised",
            detail: "Needed so Clicky can act on the desktop when you ask it to.",
            isGranted: isGranted,
            primaryAction: {
                WindowPositionManager.requestAccessibilityPermission()
            },
            primaryTitle: "Grant",
            secondaryAction: {
                WindowPositionManager.revealAppInFinder()
                WindowPositionManager.openAccessibilitySettings()
            },
            secondaryTitle: "Find App"
        )
    }

    private var screenRecordingPermissionRow: some View {
        let isGranted = companionManager.hasScreenRecordingPermission
        return panelPermissionRow(
            label: "Screen Recording",
            systemImage: "rectangle.dashed.badge.record",
            detail: isGranted ? "Only takes a screenshot when you use the hotkey." : "macOS may require a quit and reopen after granting this.",
            isGranted: isGranted,
            primaryAction: {
                WindowPositionManager.requestScreenRecordingPermission()
            },
            primaryTitle: "Grant"
        )
    }

    private var screenContentPermissionRow: some View {
        let isGranted = companionManager.hasScreenContentPermission
        return panelPermissionRow(
            label: "Screen Content",
            systemImage: "eye",
            detail: "Lets Clicky inspect screen text and context after recording is already allowed.",
            isGranted: isGranted,
            primaryAction: {
                companionManager.requestScreenContentPermission()
            },
            primaryTitle: "Grant"
        )
    }

    private var microphonePermissionRow: some View {
        let isGranted = companionManager.hasMicrophonePermission
        return panelPermissionRow(
            label: "Microphone",
            systemImage: "mic",
            detail: "Needed for push-to-talk and voice capture.",
            isGranted: isGranted,
            primaryAction: {
                let status = AVCaptureDevice.authorizationStatus(for: .audio)
                if status == .notDetermined {
                    AVCaptureDevice.requestAccess(for: .audio) { _ in }
                } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            },
            primaryTitle: "Grant"
        )
    }

    private func permissionRow(
        label: String,
        iconName: String,
        isGranted: Bool,
        settingsURL: String
    ) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Granted")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.Colors.success)
                }
            } else {
                Button(action: {
                    if let url = URL(string: settingsURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Grant")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Colors.textOnAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DS.Colors.accent)
                        )
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.vertical, 6)
    }

    private func panelPermissionRow(
        label: String,
        systemImage: String,
        detail: String,
        isGranted: Bool,
        primaryAction: @escaping () -> Void,
        primaryTitle: String,
        secondaryAction: (() -> Void)? = nil,
        secondaryTitle: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isGranted ? contentTheme.textMuted : theme.warning)
                    .frame(width: 16, height: 16)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                        .foregroundColor(contentTheme.textPrimary)

                    Text(detail)
                        .font(ClickyTypography.body(size: 12))
                        .foregroundColor(contentTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                if isGranted {
                    panelInlineStatus(label: "Granted", tone: .success)
                } else {
                    panelInlineStatus(label: "Needed", tone: .warning)
                }
            }

            if !isGranted {
                HStack(spacing: 10) {
                    Button(action: primaryAction) {
                        Text(primaryTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .modifier(ClickyProminentActionStyle())
                    .pointerCursor()

                    if let secondaryAction, let secondaryTitle {
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
        .padding(.vertical, 8)
    }



    // MARK: - Show Clicky Cursor Toggle

    private var showClickyCursorToggleRow: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
                    .frame(width: 16)

                Text("Show Clicky")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { companionManager.isClickyCursorEnabled },
                set: { companionManager.setClickyCursorEnabled($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .tint(DS.Colors.accent)
            .scaleEffect(0.8)
        }
        .padding(.vertical, 4)
    }

    private var speechToTextProviderRow: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "mic.badge.waveform")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
                    .frame(width: 16)

                Text("Speech to Text")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            Text(companionManager.buddyDictationManager.transcriptionProviderDisplayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DS.Colors.textTertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Model Picker

    private var modelPickerRow: some View {
        Picker("Model", selection: Binding(
            get: { companionManager.selectedModel },
            set: { companionManager.setSelectedModel($0) }
        )) {
            Text("Sonnet").tag("claude-sonnet-4-6")
            Text("Opus").tag("claude-opus-4-6")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .tint(theme.ring)
    }

    private var agentBackendPickerRow: some View {
        Picker("Agent", selection: Binding(
            get: { companionManager.selectedAgentBackend },
            set: { companionManager.setSelectedAgentBackend($0) }
        )) {
            Text("Claude").tag(CompanionAgentBackend.claude)
            Text("OpenClaw").tag(CompanionAgentBackend.openClaw)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .tint(theme.ring)
    }

    private var activePersonaSummary: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                panelSectionEyebrow("Persona")
                Text(companionManager.activeClickyPersonaLabel)
                    .font(ClickyTypography.section(size: 22))
                    .foregroundColor(theme.textPrimary)
                Text("\(companionManager.effectiveClickyVoicePreset.displayName) voice · \(companionManager.effectiveClickyCursorStyle.displayName) cursor")
                    .font(ClickyTypography.mono(size: 11, weight: .medium))
                    .foregroundColor(theme.textMuted)
            }

            Spacer()

            Circle()
                .fill(theme.primary)
                .frame(width: 10, height: 10)
        }
    }

    private var openClawGatewaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OpenClaw")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)

            openClawTextField(
                title: "Gateway URL",
                text: Binding(
                    get: { companionManager.openClawGatewayURL },
                    set: { companionManager.openClawGatewayURL = $0 }
                ),
                placeholder: "ws://127.0.0.1:18789"
            )

            openClawTextField(
                title: "Agent ID",
                text: Binding(
                    get: { companionManager.openClawAgentIdentifier },
                    set: { companionManager.openClawAgentIdentifier = $0 }
                ),
                placeholder: "Optional OpenClaw agent id"
            )

            openClawTextField(
                title: "Session Key",
                text: Binding(
                    get: { companionManager.openClawSessionKey },
                    set: { companionManager.openClawSessionKey = $0 }
                ),
                placeholder: "clicky-companion"
            )

            Text("The first pass auto-reads the local Gateway token from `~/.openclaw/openclaw.json`.")
                .font(.system(size: 10))
                .foregroundColor(DS.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private func openClawTextField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.textTertiary)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                        .fill(Color.white.opacity(0.025))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                        .stroke(theme.strokeSoft, lineWidth: 0.8)
                )
        }
    }

    // MARK: - DM Farza Button

    private var dmFarzaButton: some View {
        Button(action: {
            if let url = URL(string: "https://x.com/decocereus") {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 12, weight: .medium))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Got feedback? DM me")
                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                    Text("Bugs, ideas, anything — I read every message.")
                        .font(ClickyTypography.mono(size: 10, weight: .medium))
                        .foregroundColor(theme.textMuted)
                }
            }
            .foregroundColor(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 18) {
            Button(action: {
                NSApp.terminate(nil)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .medium))
                    Text("Quit Clicky")
                        .font(ClickyTypography.body(size: 12, weight: .medium))
                }
                .foregroundColor(theme.textPrimary)
            }
            .buttonStyle(.plain)
            .modifier(ClickyFooterActionStyle())
            .pointerCursor()

            Spacer(minLength: 0)
        }
    }

    // MARK: - Visual Helpers

    private var statusDotColor: Color {
        if !companionManager.isOverlayVisible {
            return theme.textMuted
        }
        switch companionManager.voiceState {
        case .idle:
            return theme.success
        case .listening:
            return theme.accent
        case .transcribing, .thinking, .responding:
            return theme.accent
        }
    }

    private var statusText: String {
        if !companionManager.hasCompletedOnboarding || !companionManager.allPermissionsGranted {
            return "Setup"
        }
        if companionManager.isClickyLaunchPaywallActive {
            return "Locked"
        }
        if !companionManager.isOverlayVisible {
            return "Ready"
        }
        switch companionManager.voiceState {
        case .idle:
            return "Active"
        case .listening:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .thinking:
            return "Thinking"
        case .responding:
            return "Responding"
        }
    }

    private func openStudio() {
        NotificationCenter.default.post(name: .clickyOpenStudio, object: nil)
    }

    private func panelSectionEyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ClickyTypography.mono(size: 10, weight: .semibold))
            .foregroundColor(contentTheme.textMuted)
            .tracking(1.2)
    }

    private func panelInlineStatus(label: String, tone: PanelInlineStatusTone) -> some View {
        Text(label)
            .font(ClickyTypography.mono(size: 10, weight: .semibold))
            .foregroundColor(panelInlineStatusForeground(tone))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(panelInlineStatusBackground(tone))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(panelInlineStatusBorder(tone), lineWidth: 0.8)
            )
    }

    private func panelInlineStatusForeground(_ tone: PanelInlineStatusTone) -> Color {
        switch tone {
        case .neutral:
            return theme.textSecondary
        case .success:
            return theme.success
        case .warning:
            return theme.warning
        case .info:
            return theme.accentStrong
        }
    }

    private func panelInlineStatusBackground(_ tone: PanelInlineStatusTone) -> Color {
        switch tone {
        case .neutral:
            return Color.white.opacity(0.02)
        case .success:
            return theme.success.opacity(0.12)
        case .warning:
            return theme.warning.opacity(0.12)
        case .info:
            return theme.primary.opacity(0.12)
        }
    }

    private func panelInlineStatusBorder(_ tone: PanelInlineStatusTone) -> Color {
        switch tone {
        case .neutral:
            return theme.strokeSoft
        case .success:
            return theme.success.opacity(0.3)
        case .warning:
            return theme.warning.opacity(0.3)
        case .info:
            return theme.primary.opacity(0.3)
        }
    }

    private var panelHairline: some View {
        Rectangle()
            .fill(theme.strokeSoft)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private var openClawPanelSummary: String {
        let gatewayKind = companionManager.isOpenClawGatewayRemote ? "remote" : "local"
        let currentAgent = companionManager.effectiveOpenClawAgentName
        return "Connected to your \(gatewayKind) OpenClaw setup. Clicky is currently presenting \(currentAgent) inside the desktop shell."
    }

    private var openClawCompactSummary: String {
        switch companionManager.openClawConnectionStatus {
        case .connected:
            return "Connected to your \(companionManager.isOpenClawGatewayRemote ? "remote" : "local") OpenClaw gateway."
        case .testing:
            return "Testing your OpenClaw gateway connection."
        case .failed:
            return "Gateway needs attention. Open Studio for details."
        case .idle:
            return "Gateway is configured but idle."
        }
    }

    private var openClawStatusColor: Color {
        switch companionManager.openClawConnectionStatus {
        case .connected:
            return theme.success
        case .failed:
            return theme.warning
        case .testing:
            return theme.accent
        case .idle:
            return theme.textMuted
        }
    }

    private var isTestingOpenClawConnection: Bool {
        if case .testing = companionManager.openClawConnectionStatus {
            return true
        }

        return false
    }

}

private enum PanelInlineStatusTone {
    case neutral
    case success
    case warning
    case info
}

private enum ClickyPanelContentTone {
    case regular
    case hero
    case subtle
}

private struct ClickyPanelContentCardStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    let tone: ClickyPanelContentTone
    let padding: CGFloat

    init(tone: ClickyPanelContentTone = .regular, padding: CGFloat = 15) {
        self.tone = tone
        self.padding = padding
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        content
            .clickyTheme(theme.contentSurfaceTheme)
            .padding(padding)
            .background(
                shape
                    .fill(backgroundFill)
                    .overlay(shape.fill(highlightFill))
            )
            .overlay(
                shape
                    .stroke(borderColor, lineWidth: 0.9)
            )
            .shadow(color: Color.black.opacity(tone == .subtle ? 0.04 : 0.07), radius: 18, y: 8)
    }

    private var backgroundFill: Color {
        switch tone {
        case .regular:
            return theme.card.opacity(0.92)
        case .hero:
            return theme.secondary.opacity(0.96)
        case .subtle:
            return theme.card.opacity(0.82)
        }
    }

    private var highlightFill: LinearGradient {
        switch tone {
        case .regular:
            return LinearGradient(
                colors: [Color.white.opacity(0.08), theme.secondary.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hero:
            return LinearGradient(
                colors: [Color.white.opacity(0.10), theme.primary.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .subtle:
            return LinearGradient(
                colors: [Color.white.opacity(0.06), theme.secondary.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        switch tone {
        case .regular:
            return theme.border.opacity(0.72)
        case .hero:
            return theme.primary.opacity(0.22)
        case .subtle:
            return theme.border.opacity(0.52)
        }
    }
}

private struct ClickyProminentActionStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .foregroundColor(theme.accentForeground)
                .buttonStyle(.glassProminent)
                .tint(theme.accent)
        } else {
            content
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .foregroundColor(theme.accentForeground)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.accent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
        }
    }
}

private struct ClickySecondaryGlassButtonStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        let contentTheme = theme.contentSurfaceTheme

        content
            .font(ClickyTypography.body(size: 12, weight: .semibold))
            .foregroundColor(contentTheme.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(contentTheme.secondary.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(contentTheme.border.opacity(0.78), lineWidth: 0.9)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }
}

private struct ClickyFooterActionStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.background.opacity(0.42))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
    }
}

private struct ClickyTinyGlassCircleStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.04))
                )
        }
    }
}

private struct ClickyPanelShellStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        if #available(macOS 26.0, *) {
            content
                .padding(18)
                .glassEffect(.clear, in: shape)
                .overlay(
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.10),
                                    theme.primary.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.18), radius: 28, y: 16)
        } else {
            content
                .clickyGlassCard(cornerRadius: 28, padding: 18)
        }
    }
}
