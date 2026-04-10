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
    @Environment(\.openSettings) private var openSettings

    private var theme: ClickyTheme {
        companionManager.activeClickyTheme
    }

    var body: some View {
        ZStack {
            ClickyAuraBackground()

            ClickyGlassCluster {
                VStack(alignment: .leading, spacing: 18) {
                    panelHeader

                    panelShell

                    footerSection
                        .padding(.top, 4)
                }
                .padding(18)
            }
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
                    .foregroundColor(theme.accent)

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
        .padding(.horizontal, 14)
        .padding(.top, 2)
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
        VStack(alignment: .leading, spacing: 18) {
            permissionsCopySection

            if !companionManager.allPermissionsGranted {
                settingsSection
            }

            if !companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
                startButton
            }

            if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted && companionManager.isClickyLaunchPaywallActive {
                panelHairline
                paywallLockedSection
            } else if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
                panelHairline
                activePersonaSummary

                panelHairline
                agentBackendPickerRow

                if companionManager.selectedAgentBackend == .claude {
                    panelHairline
                    modelPickerRow
                } else {
                    panelHairline
                    openClawInlineSummary
                }

                panelHairline
                dmFarzaButton
            }
        }
        .modifier(ClickyPanelShellStyle())
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
                .foregroundColor(theme.textPrimary)

            Text("Your trial credits are exhausted. Unlock Clicky to keep using the companion experience.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(theme.textSecondary)
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

    private var openClawInlineSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelSectionEyebrow("OpenClaw")

            HStack {
                Text(companionManager.effectiveClickyPresentationName)
                    .font(ClickyTypography.section(size: 22))
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Circle()
                    .fill(openClawStatusColor)
                    .frame(width: 8, height: 8)
            }

            Text(openClawPanelSummary)
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(theme.textSecondary)
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
                .foregroundColor(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if companionManager.allPermissionsGranted {
            Text("You're all set. Hit Start to meet Clicky.")
                .font(ClickyTypography.body(size: 15, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if companionManager.hasCompletedOnboarding {
            // Permissions were revoked after onboarding — tell user to re-grant
            VStack(alignment: .leading, spacing: 6) {
                Text("Permissions needed")
                    .font(ClickyTypography.section(size: 22))
                    .foregroundColor(theme.textPrimary)

                Text("Some permissions were revoked. Grant all four below to keep using Clicky.")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Learn with an agent that stays right next to you.")
                    .font(ClickyTypography.section(size: 24))
                    .foregroundColor(theme.textPrimary)

                Text("Clicky only looks when you ask it to. Use the hotkey, speak naturally, and let the assistant guide you on top of your real screen.")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(theme.textSecondary)
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
                .foregroundColor(theme.textMuted)
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
                    .foregroundColor(isGranted ? theme.textMuted : theme.warning)
                    .frame(width: 16, height: 16)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    Text(detail)
                        .font(ClickyTypography.body(size: 12))
                        .foregroundColor(theme.textSecondary)
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
        HStack {
            Text("Model")
                .font(ClickyTypography.body(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)

            Spacer()

            Picker("Model", selection: Binding(
                get: { companionManager.selectedModel },
                set: { companionManager.setSelectedModel($0) }
            )) {
                Text("Sonnet").tag("claude-sonnet-4-6")
                Text("Opus").tag("claude-opus-4-6")
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        }
        .padding(.vertical, 4)
    }

    private var agentBackendPickerRow: some View {
        HStack {
            Text("Agent")
                .font(ClickyTypography.body(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)

            Spacer()

            Picker("Agent", selection: Binding(
                get: { companionManager.selectedAgentBackend },
                set: { companionManager.setSelectedAgentBackend($0) }
            )) {
                Text("Claude").tag(CompanionAgentBackend.claude)
                Text("OpenClaw").tag(CompanionAgentBackend.openClaw)
            }
            .pickerStyle(.segmented)
            .frame(width: 190)
        }
        .padding(.vertical, 4)
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
                .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .pointerCursor()

            if companionManager.hasCompletedOnboarding {
                Button(action: {
                    companionManager.replayOnboarding()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 11, weight: .medium))
                        Text("Watch Onboarding Again")
                            .font(ClickyTypography.body(size: 12, weight: .medium))
                    }
                    .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }

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
        NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)
        openSettings()
    }

    private func panelSectionEyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ClickyTypography.mono(size: 10, weight: .semibold))
            .foregroundColor(theme.textMuted)
            .tracking(1.2)
    }

    private func panelInlineStatus(label: String, tone: StudioStatusTone) -> some View {
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

    private func panelInlineStatusForeground(_ tone: StudioStatusTone) -> Color {
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

    private func panelInlineStatusBackground(_ tone: StudioStatusTone) -> Color {
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

    private func panelInlineStatusBorder(_ tone: StudioStatusTone) -> Color {
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

}

private struct ClickyProminentActionStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.82))
                .buttonStyle(.glassProminent)
                .tint(theme.accent)
        } else {
            content
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.82))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.accent)
                )
        }
    }
}

private struct ClickySecondaryGlassButtonStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .font(ClickyTypography.body(size: 12, weight: .semibold))
                .buttonStyle(.glass)
                .tint(theme.primary.opacity(0.14))
        } else {
            content
                .font(ClickyTypography.body(size: 12, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
        }
    }
}

private struct ClickyTinyGlassCircleStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.tint(theme.primary.opacity(0.10)).interactive(), in: Circle())
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
                .background(
                    shape
                        .fill(.clear)
                        .glassEffect(.regular.tint(theme.primary.opacity(0.07)).interactive(), in: shape)
                )
                .overlay(
                    shape
                        .stroke(theme.strokeSoft, lineWidth: 0.9)
                )
        } else {
            content
                .clickyGlassCard(cornerRadius: 28, padding: 18)
        }
    }
}
