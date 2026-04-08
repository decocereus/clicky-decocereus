//
//  CompanionStudioView.swift
//  leanring-buddy
//
//  Desktop configuration surface for the companion shell.
//

import SwiftUI

private enum CompanionStudioSection: String, CaseIterable, Identifiable {
    case general
    case openClaw
    case voiceAppearance
    case integrations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .openClaw:
            return "OpenClaw"
        case .voiceAppearance:
            return "Voice & Appearance"
        case .integrations:
            return "Integrations"
        }
    }

    var iconSystemName: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .openClaw:
            return "bolt.horizontal.circle"
        case .voiceAppearance:
            return "speaker.wave.3"
        case .integrations:
            return "puzzlepiece.extension"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Runtime and backend"
        case .openClaw:
            return "Gateway and agent routing"
        case .voiceAppearance:
            return "Speech and cursor shell"
        case .integrations:
            return "Plugin-ready direction"
        }
    }
}

struct CompanionStudioView: View {
    @ObservedObject var companionManager: CompanionManager

    @State private var selectedSection: CompanionStudioSection = .general
    @State private var isOpenClawTokenVisible = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
                .background(DS.Colors.borderSubtle)
            detailPane
        }
        .background(DS.Colors.background)
        .onAppear {
            NotificationCenter.default.post(name: .clickyStudioDidAppear, object: nil)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .clickyStudioDidDisappear, object: nil)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [DS.Colors.blue500, DS.Colors.blue700],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "cursorarrow.motionlines")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Clicky Studio")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DS.Colors.textPrimary)
                        Text("Companion shell configuration")
                            .font(.system(size: 11))
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }

                StudioStatusPill(
                    label: CompanionRuntimeConfiguration.isWorkerConfigured ? "Cloud Connected" : "Local Fallback",
                    tone: CompanionRuntimeConfiguration.isWorkerConfigured ? .success : .warning
                )
            }
            .padding(24)

            VStack(spacing: 6) {
                ForEach(CompanionStudioSection.allCases) { section in
                    Button(action: {
                        selectedSection = section
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: section.iconSystemName)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 18)
                                .foregroundColor(selectedSection == section ? DS.Colors.textPrimary : DS.Colors.textTertiary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedSection == section ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                                Text(section.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundColor(DS.Colors.textTertiary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedSection == section ? DS.Colors.surface2 : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selectedSection == section ? DS.Colors.borderStrong : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Next Up")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Colors.textTertiary)

                Text("OpenClaw plugin install flow, remote pairing polish, and custom voice/cursor packs belong here next.")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DS.Colors.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
            .padding(16)
        }
        .frame(width: 250)
        .background(DS.Colors.surface1)
    }

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionHero
                sectionContent
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.Colors.background)
    }

    private var sectionHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedSection.title)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(DS.Colors.textPrimary)

            Text(sectionHeroDescription)
                .font(.system(size: 14))
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .general:
            generalSectionContent
        case .openClaw:
            openClawSectionContent
        case .voiceAppearance:
            voiceAppearanceSectionContent
        case .integrations:
            integrationsSectionContent
        }
    }

    private var generalSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Runtime Overview", subtitle: "What shell you are currently running") {
                VStack(spacing: 12) {
                    StudioKeyValueRow(label: "Hotkey", value: "Control + Option")
                    StudioKeyValueRow(label: "Overlay", value: companionManager.isOverlayVisible ? "Visible" : "Hidden")
                    StudioKeyValueRow(label: "Speech to Text", value: companionManager.buddyDictationManager.transcriptionProviderDisplayName)
                    StudioKeyValueRow(label: "Speech Output", value: companionManager.effectiveVoiceOutputDisplayName)
                    StudioKeyValueRow(label: "Backend Mode", value: CompanionRuntimeConfiguration.isWorkerConfigured ? "Cloud worker configured" : "Local fallback mode")
                }
            }

            StudioCard(title: "Agent Backend", subtitle: "Choose which brain powers the companion") {
                VStack(alignment: .leading, spacing: 14) {
                    Picker(
                        "Agent Backend",
                        selection: Binding(
                            get: { companionManager.selectedAgentBackend },
                            set: { companionManager.setSelectedAgentBackend($0) }
                        )
                    ) {
                        ForEach(CompanionAgentBackend.allCases, id: \.self) { backend in
                            Text(backend.displayName).tag(backend)
                        }
                    }
                    .pickerStyle(.segmented)

                    if companionManager.selectedAgentBackend == .claude {
                        Picker(
                            "Claude Model",
                            selection: Binding(
                                get: { companionManager.selectedModel },
                                set: { companionManager.setSelectedModel($0) }
                            )
                        ) {
                            Text("Sonnet").tag("claude-sonnet-4-6")
                            Text("Opus").tag("claude-opus-4-6")
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text("OpenClaw is selected. Use the OpenClaw section to configure local or remote Gateway access.")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            StudioCard(title: "Quick Controls", subtitle: "The shell-level behavior users feel immediately") {
                VStack(spacing: 14) {
                    Toggle(
                        "Show Clicky cursor overlay",
                        isOn: Binding(
                            get: { companionManager.isClickyCursorEnabled },
                            set: { companionManager.setClickyCursorEnabled($0) }
                        )
                    )
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accent)

                    Text("This leaves the fast menu bar companion intact while giving us a real desktop surface for deeper configuration.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var openClawSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Gateway Connection", subtitle: "Supports both local loopback and remote hosted OpenClaw") {
                VStack(alignment: .leading, spacing: 14) {
                    StudioTextField(title: "Gateway URL", text: Binding(
                        get: { companionManager.openClawGatewayURL },
                        set: { companionManager.openClawGatewayURL = $0 }
                    ), placeholder: "ws://127.0.0.1:18789")

                    StudioSecretField(
                        title: "Gateway Token",
                        text: Binding(
                            get: { companionManager.openClawGatewayAuthToken },
                            set: { companionManager.openClawGatewayAuthToken = $0 }
                        ),
                        placeholder: "Leave blank to use local ~/.openclaw token",
                        isRevealed: $isOpenClawTokenVisible
                    )

                    HStack(spacing: 10) {
                        StudioStatusPill(
                            label: companionManager.isOpenClawGatewayRemote ? "Remote Gateway" : "Local Gateway",
                            tone: companionManager.isOpenClawGatewayRemote ? .info : .success
                        )

                        StudioStatusPill(
                            label: companionManager.openClawGatewayAuthSummary,
                            tone: companionManager.openClawGatewayAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .neutral : .info
                        )
                    }
                }
            }

            StudioCard(title: "Agent Routing", subtitle: "Control which OpenClaw session and agent handle companion turns") {
                VStack(alignment: .leading, spacing: 14) {
                    StudioTextField(title: "Agent ID", text: Binding(
                        get: { companionManager.openClawAgentIdentifier },
                        set: { companionManager.openClawAgentIdentifier = $0 }
                    ), placeholder: "Optional fixed OpenClaw agent id")

                    StudioTextField(title: "Session Key", text: Binding(
                        get: { companionManager.openClawSessionKey },
                        set: { companionManager.openClawSessionKey = $0 }
                    ), placeholder: "clicky-companion")

                    Text("Remote hosted instances should still work as long as the URL is reachable over `ws://` or `wss://` and the token is valid.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            StudioCard(title: "Connection Test", subtitle: "Verify that Clicky can establish a real Gateway session") {
                VStack(alignment: .leading, spacing: 14) {
                    Button(action: {
                        companionManager.testOpenClawConnection()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(openClawConnectionButtonLabel)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(DS.Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DS.Colors.surface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor(isEnabled: !isTestingOpenClawConnection)
                    .disabled(isTestingOpenClawConnection)

                    connectionStatusView
                }
            }
        }
    }

    private var voiceAppearanceSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Voice Pipeline", subtitle: "What handles transcription and playback right now") {
                VStack(spacing: 12) {
                    StudioKeyValueRow(label: "Transcription Engine", value: companionManager.buddyDictationManager.transcriptionProviderDisplayName)
                    StudioKeyValueRow(label: "Speech Output", value: companionManager.effectiveVoiceOutputDisplayName)
                    StudioKeyValueRow(label: "Voice States", value: "Listening • Transcribing • Thinking • Responding")
                }
            }

            StudioCard(title: "Voice Customization", subtitle: "This is where ElevenLabs and other voice packs will land next") {
                VStack(alignment: .leading, spacing: 10) {
                    StudioStatusPill(label: "Planned", tone: .warning)
                    Text("Custom voice selection should be owned here, while the runtime keeps speaking through the currently active output engine.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            StudioCard(title: "Appearance Foundation", subtitle: "Cursor shell controls and future visual identity") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(
                        "Show Clicky cursor overlay",
                        isOn: Binding(
                            get: { companionManager.isClickyCursorEnabled },
                            set: { companionManager.setClickyCursorEnabled($0) }
                        )
                    )
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accent)

                    StudioStatusPill(label: "Cursor skins coming next", tone: .warning)

                    Text("The triangle companion stays as the current shell, but this area is now the right home for cursor skins, companion icon variants, and future presence customizations.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var integrationsSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Plugin Direction", subtitle: "Make Clicky installable into agent ecosystems instead of building bespoke glue per runtime") {
                VStack(alignment: .leading, spacing: 12) {
                    StudioStatusPill(label: "OpenClaw plugin is next", tone: .info)
                    Text("The goal is a Clicky plugin that OpenClaw can install so OpenClaw recognizes Clicky as a first-class integration, can route responses through Clicky's transcript/TTS shell, and can keep its own memory updated about the connection.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            StudioCard(title: "Remote-Ready Integration", subtitle: "Local-first, but not local-only") {
                VStack(alignment: .leading, spacing: 12) {
                    StudioKeyValueRow(label: "Transport", value: "ws:// or wss:// Gateway")
                    StudioKeyValueRow(label: "Auth", value: "Studio token override or local OpenClaw token")
                    StudioKeyValueRow(label: "Shell ownership", value: "Clicky captures input, shows presence, speaks output")
                    StudioKeyValueRow(label: "Agent ownership", value: "OpenClaw handles cognition, memory, and agent runtime")
                }
            }

            StudioCard(title: "What Comes After Studio", subtitle: "The next build slice after this window exists") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("1. Give OpenClaw a real Clicky identity handshake.\n2. Package Clicky capabilities as an installable plugin.\n3. Route remote OpenClaw turns through the same silky cursor and voice shell.\n4. Add custom voices and cursor appearance packs here.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var sectionHeroDescription: String {
        switch selectedSection {
        case .general:
            return "Tune the shell itself: runtime mode, backend routing, and the core companion behavior users feel first."
        case .openClaw:
            return "Connect local or remote OpenClaw Gateways, control session routing, and verify the link from Clicky's side."
        case .voiceAppearance:
            return "Own the speech pipeline and visual shell here so later voice packs and cursor skins have a real home."
        case .integrations:
            return "This is the bridge from app-specific integration to a real Clicky plugin story for OpenClaw and other runtimes."
        }
    }

    private var openClawConnectionButtonLabel: String {
        if isTestingOpenClawConnection {
            return "Testing Gateway..."
        }

        return "Test OpenClaw Connection"
    }

    private var isTestingOpenClawConnection: Bool {
        if case .testing = companionManager.openClawConnectionStatus {
            return true
        }

        return false
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch companionManager.openClawConnectionStatus {
        case .idle:
            Text("Run a connection test to verify the Gateway handshake from Clicky's side.")
                .font(.system(size: 12))
                .foregroundColor(DS.Colors.textSecondary)
        case .testing:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(DS.Colors.accentText)
                Text("Talking to the OpenClaw Gateway...")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
            }
        case .connected(let summary):
            VStack(alignment: .leading, spacing: 8) {
                StudioStatusPill(label: "Connected", tone: .success)
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                StudioStatusPill(label: "Connection Failed", tone: .warning)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct StudioCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DS.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DS.Colors.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }
}

private enum StudioStatusTone {
    case neutral
    case success
    case warning
    case info
}

private struct StudioStatusPill: View {
    let label: String
    let tone: StudioStatusTone

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .fixedSize()
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return DS.Colors.textSecondary
        case .success:
            return DS.Colors.success
        case .warning:
            return DS.Colors.warningText
        case .info:
            return DS.Colors.accentText
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            return DS.Colors.surface2
        case .success:
            return DS.Colors.success.opacity(0.12)
        case .warning:
            return DS.Colors.warning.opacity(0.12)
        case .info:
            return DS.Colors.blue500.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral:
            return DS.Colors.borderSubtle
        case .success:
            return DS.Colors.success.opacity(0.35)
        case .warning:
            return DS.Colors.warning.opacity(0.35)
        case .info:
            return DS.Colors.blue400.opacity(0.35)
        }
    }
}

private struct StudioKeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textTertiary)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(.system(size: 13))
                .foregroundColor(DS.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StudioTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DS.Colors.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
        }
    }
}

private struct StudioSecretField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @Binding var isRevealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.textTertiary)

            HStack(spacing: 10) {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(DS.Colors.textPrimary)

                Button(action: {
                    isRevealed.toggle()
                }) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DS.Colors.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
}
