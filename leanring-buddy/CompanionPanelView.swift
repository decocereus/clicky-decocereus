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

            VStack(alignment: .leading, spacing: 18) {
                panelHeader

                panelShell

                footerSection
                    .padding(.top, 4)
            }
            .padding(18)
        }
        .clickyTheme(theme)
        .frame(width: 360)
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("clicky")
                    .font(ClickyTypography.brand(size: 34))
                    .foregroundColor(theme.accent)

                Text(statusText.uppercased())
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(theme.textMuted)
                    .tracking(1.2)
            }

            Spacer()

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
        .padding(.horizontal, 16)
        .padding(.top, 4)
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

            if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
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
        VStack(alignment: .leading, spacing: 10) {
            panelSectionEyebrow("OpenClaw")

            HStack {
                Text(companionManager.effectiveClickyPresentationName)
                    .font(ClickyTypography.section(size: 24))
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

            Button(action: {
                openStudio()
            }) {
                Text("Connection settings live in Studio")
                    .frame(maxWidth: .infinity)
            }
            .modifier(ClickySecondaryGlassButtonStyle())
            .pointerCursor()
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
        VStack(spacing: 2) {
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
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                Text("Accessibility")
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
                HStack(spacing: 6) {
                    Button(action: {
                        // Triggers the system accessibility prompt (AXIsProcessTrustedWithOptions)
                        // on first attempt, then opens System Settings on subsequent attempts.
                        WindowPositionManager.requestAccessibilityPermission()
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

                    Button(action: {
                        // Reveals the app in Finder so the user can drag it into
                        // the Accessibility list if it doesn't appear automatically
                        // (common with unsigned dev builds).
                        WindowPositionManager.revealAppInFinder()
                        WindowPositionManager.openAccessibilitySettings()
                    }) {
                        Text("Find App")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DS.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .stroke(DS.Colors.borderSubtle, lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var screenRecordingPermissionRow: some View {
        let isGranted = companionManager.hasScreenRecordingPermission
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.dashed.badge.record")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Screen Recording")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)

                    Text(isGranted
                         ? "Only takes a screenshot when you use the hotkey"
                         : "Quit and reopen after granting")
                        .font(.system(size: 10))
                        .foregroundColor(DS.Colors.textTertiary)
                }
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
                    // Triggers the native macOS screen recording prompt on first
                    // attempt (auto-adds app to the list), then opens System Settings
                    // on subsequent attempts.
                    WindowPositionManager.requestScreenRecordingPermission()
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

    private var screenContentPermissionRow: some View {
        let isGranted = companionManager.hasScreenContentPermission
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                Text("Screen Content")
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
                    companionManager.requestScreenContentPermission()
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

    private var microphonePermissionRow: some View {
        let isGranted = companionManager.hasMicrophonePermission
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "mic")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                Text("Microphone")
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
                    // Triggers the native macOS microphone permission dialog on
                    // first attempt. If already denied, opens System Settings.
                    let status = AVCaptureDevice.authorizationStatus(for: .audio)
                    if status == .notDetermined {
                        AVCaptureDevice.requestAccess(for: .audio) { _ in }
                    } else {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
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

            HStack(spacing: 0) {
                modelOptionButton(label: "Sonnet", modelID: "claude-sonnet-4-6")
                modelOptionButton(label: "Opus", modelID: "claude-opus-4-6")
            }
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 0.8)
            )
        }
        .padding(.vertical, 4)
    }

    private var agentBackendPickerRow: some View {
        HStack {
            Text("Agent")
                .font(ClickyTypography.body(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)

            Spacer()

            HStack(spacing: 0) {
                agentBackendOptionButton(label: "Claude", backend: .claude)
                agentBackendOptionButton(label: "OpenClaw", backend: .openClaw)
            }
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 0.8)
            )
        }
        .padding(.vertical, 4)
    }

    private func agentBackendOptionButton(label: String, backend: CompanionAgentBackend) -> some View {
        let isSelected = companionManager.selectedAgentBackend == backend
        return Button(action: {
            companionManager.setSelectedAgentBackend(backend)
        }) {
            Text(label)
                .font(ClickyTypography.body(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? theme.textPrimary : theme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? theme.accent.opacity(0.10) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private func modelOptionButton(label: String, modelID: String) -> some View {
        let isSelected = companionManager.selectedModel == modelID
        return Button(action: {
            companionManager.setSelectedModel(modelID)
        }) {
            Text(label)
                .font(ClickyTypography.body(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? theme.textPrimary : theme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? theme.accent.opacity(0.10) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .pointerCursor()
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
                .tint(theme.accent.opacity(0.72))
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
                        .glassEffect(.regular.tint(theme.primary.opacity(0.12)).interactive(), in: shape)
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
