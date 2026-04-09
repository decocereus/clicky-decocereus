//
//  CompanionStudioView.swift
//  leanring-buddy
//
//  Desktop configuration surface for the companion shell.
//

import AppKit
import SwiftUI

private enum CompanionStudioSection: String, CaseIterable, Identifiable {
    case general
    case openClaw
    case voiceAppearance
    case integrations
    case diagnostics

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
        case .diagnostics:
            return "Diagnostics"
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
        case .diagnostics:
            return "stethoscope"
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
        case .diagnostics:
            return "Debug and internal state"
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
        case .diagnostics:
            diagnosticsSectionContent
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

            StudioCard(title: "Identity in Clicky", subtitle: "Choose how your existing OpenClaw agent shows up inside Clicky") {
                VStack(alignment: .leading, spacing: 14) {
                    StudioKeyValueRow(
                        label: "Current agent",
                        value: companionManager.inferredOpenClawAgentIdentityDisplayName
                    )

                    Button(action: {
                        companionManager.refreshOpenClawAgentIdentity()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Refresh OpenClaw Identity")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(DS.Colors.textSecondary)
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
                    .buttonStyle(.plain)
                    .pointerCursor()

                    Picker(
                        "Persona Scope",
                        selection: Binding(
                            get: { companionManager.clickyPersonaScopeMode },
                            set: { companionManager.clickyPersonaScopeMode = $0 }
                        )
                    ) {
                        Text("Use OpenClaw Identity").tag(ClickyPersonaScopeMode.useOpenClawIdentity)
                        Text("Override in Clicky").tag(ClickyPersonaScopeMode.overrideInClicky)
                    }
                    .pickerStyle(.segmented)

                    Text("Your OpenClaw agent stays itself. Clicky only changes how that agent appears inside Clicky when you choose an override.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    StudioKeyValueRow(
                        label: "Clicky presents as",
                        value: companionManager.effectiveClickyPresentationName
                    )

                    if companionManager.clickyPersonaScopeMode == .overrideInClicky {
                        StudioTextField(
                            title: "Clicky-only display name",
                            text: Binding(
                                get: { companionManager.clickyPersonaOverrideName },
                                set: { companionManager.clickyPersonaOverrideName = $0 }
                            ),
                            placeholder: "Example: Zuko in Clicky"
                        )

                        StudioMultilineField(
                            title: "Clicky-only persona notes",
                            text: Binding(
                                get: { companionManager.clickyPersonaOverrideInstructions },
                                set: { companionManager.clickyPersonaOverrideInstructions = $0 }
                            ),
                            placeholder: "Only affects Clicky. Does not rewrite the agent inside OpenClaw."
                        )
                    }
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
            StudioCard(title: "Connect Clicky to OpenClaw", subtitle: "Set up the bridge once, then Clicky can work as your desktop companion shell") {
                VStack(alignment: .leading, spacing: 12) {
                    StudioStepRow(
                        stepNumber: 1,
                        title: "Install the plugin",
                        detail: "Run this once from your terminal.",
                        statusLabel: companionManager.clickyOpenClawPluginStatus == .notConfigured ? "Needed" : "Done",
                        statusTone: companionManager.clickyOpenClawPluginStatus == .notConfigured ? .warning : .success
                    )

                    StudioCommandBlock(
                        title: "Install command",
                        command: companionManager.clickyOpenClawPluginInstallCommand
                    )

                    StudioStepRow(
                        stepNumber: 2,
                        title: "Enable it in OpenClaw",
                        detail: "This turns the plugin on and restarts the Gateway.",
                        statusLabel: companionManager.clickyOpenClawPluginStatus == .enabled ? "Done" : "Needed",
                        statusTone: companionManager.clickyOpenClawPluginStatus == .enabled ? .success : .warning
                    )

                    StudioCommandBlock(
                        title: "Enable + restart",
                        command: companionManager.clickyOpenClawPluginEnableCommand
                    )

                    StudioStepRow(
                        stepNumber: 3,
                        title: "Register this Clicky shell",
                        detail: "Once OpenClaw is enabled and the Agent backend is set to OpenClaw, Clicky can identify itself as the live desktop shell.",
                        statusLabel: companionManager.clickyShellRegistrationStatusLabel,
                        statusTone: clickyShellRegistrationTone
                    )

                    Button(action: {
                        companionManager.registerClickyShellNow()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Register Clicky Shell")
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
                    .pointerCursor()

                    Button(action: {
                        companionManager.refreshClickyShellStatusNow()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Refresh Shell Status")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(DS.Colors.textSecondary)
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
                    .buttonStyle(.plain)
                    .pointerCursor()

                    shellRegistrationStatusView
                }
            }

            StudioCard(title: "Connection Summary", subtitle: "What matters to a user right now") {
                VStack(alignment: .leading, spacing: 12) {
                    StudioStatusPill(
                        label: companionManager.clickyOpenClawPluginStatusLabel,
                        tone: clickyPluginStatusTone
                    )

                    Text("Once this bridge is installed and enabled, Clicky can speak responses, show cursor presence, and stay aligned with your OpenClaw agent while keeping that agent’s core identity intact.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            StudioCard(title: "Remote-Ready Setup", subtitle: "This keeps working when OpenClaw is hosted somewhere else") {
                VStack(alignment: .leading, spacing: 12) {
                    StudioKeyValueRow(label: "Gateway transport", value: "Clicky connects out over ws:// or wss://")
                    StudioKeyValueRow(label: "Auth mode", value: "Local token fallback or explicit Studio token")
                    Text(companionManager.clickyOpenClawRemoteReadinessSummary)
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            StudioCard(title: "What Comes Next", subtitle: "The current bridge is working, but the plugin will keep getting richer") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Next we deepen the trust handshake, capability versioning, and session-binding behavior so OpenClaw can treat Clicky as a first-class shell instead of just a generic Gateway client.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var diagnosticsSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Diagnostics", subtitle: "Internal app and integration state for debugging") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This section is intentionally more technical. It’s here so we can debug identity, shell registration, and bridge behavior without exposing those details in the normal user flow.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    StudioKeyValueRow(label: "OpenClaw agent id", value: companionManager.inferredOpenClawAgentIdentifier ?? "Not detected")
                    StudioKeyValueRow(label: "OpenClaw emoji", value: companionManager.inferredOpenClawAgentIdentityEmojiLabel)
                    StudioKeyValueRow(label: "OpenClaw avatar", value: companionManager.inferredOpenClawAgentIdentityAvatarLabel)
                    StudioKeyValueRow(label: "Shell trust", value: companionManager.clickyShellServerTrustLabel)
                    StudioKeyValueRow(label: "Shell freshness", value: companionManager.clickyShellServerFreshnessLabel)
                    StudioKeyValueRow(label: "Session binding", value: companionManager.clickyShellServerBindingLabel)
                    StudioKeyValueRow(label: "Bound session", value: companionManager.clickyShellServerSessionKeyLabel)

                    if let clickyShellServerStatusSummary = companionManager.clickyShellServerStatusSummary,
                       !clickyShellServerStatusSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DisclosureGroup("Raw shell summary") {
                            Text(clickyShellServerStatusSummary)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(DS.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                                .textSelection(.enabled)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.Colors.textSecondary)
                    }

                    HStack(spacing: 10) {
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(ClickyDiagnosticsStore.shared.formattedRecentLogText(), forType: .string)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Copy Recent Logs")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(DS.Colors.textSecondary)
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
                        .buttonStyle(.plain)
                        .pointerCursor()

                        Button(action: {
                            ClickyDiagnosticsStore.shared.clear()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Clear Buffer")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(DS.Colors.textSecondary)
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
                        .buttonStyle(.plain)
                        .pointerCursor()
                    }
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
        case .diagnostics:
            return "Internal activity, bridge state, and debugging details live here instead of cluttering the normal user flow."
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

    private var clickyPluginStatusTone: StudioStatusTone {
        switch companionManager.clickyOpenClawPluginStatus {
        case .enabled:
            return .success
        case .disabled:
            return .warning
        case .notConfigured:
            return .neutral
        }
    }

    private var clickyShellRegistrationTone: StudioStatusTone {
        switch companionManager.clickyShellRegistrationStatus {
        case .idle:
            return .neutral
        case .registering:
            return .info
        case .registered:
            return .success
        case .failed:
            return .warning
        }
    }

    private var clickyShellTrustTone: StudioStatusTone {
        switch companionManager.clickyShellServerTrustState {
        case "trusted-local", "trusted-remote":
            return .success
        case nil:
            return .neutral
        default:
            return .warning
        }
    }

    private var clickyShellFreshnessTone: StudioStatusTone {
        switch companionManager.clickyShellServerFreshnessState {
        case "fresh":
            return .success
        case "stale":
            return .warning
        case nil:
            return .neutral
        default:
            return .warning
        }
    }

    private var clickyShellBindingTone: StudioStatusTone {
        switch companionManager.clickyShellServerSessionBindingState {
        case "bound":
            return .success
        case "unbound":
            return .warning
        case nil:
            return .neutral
        default:
            return .warning
        }
    }

    @ViewBuilder
    private var shellRegistrationStatusView: some View {
        switch companionManager.clickyShellRegistrationStatus {
        case .idle:
            Text("OpenClaw will only accept a live Clicky shell registration once the `clicky-shell` plugin is enabled and the app is targeting the OpenClaw backend.")
                .font(.system(size: 12))
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .registering:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(DS.Colors.accentText)
                Text("Registering this desktop shell with OpenClaw...")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
            }
        case .registered(let summary):
            Text(summary)
                .font(.system(size: 12))
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .failed(let message):
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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

private struct StudioCommandBlock: View {
    let title: String
    let command: String

    @State private var hasCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Colors.textTertiary)

                Spacer()

                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(command, forType: .string)
                    hasCopied = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        hasCopied = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(hasCopied ? "Copied" : "Copy")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(hasCopied ? DS.Colors.success : DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }

            Text(command)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(DS.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DS.Colors.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
                .textSelection(.enabled)
        }
    }
}

private struct StudioStepRow: View {
    let stepNumber: Int
    let title: String
    let detail: String
    let statusLabel: String
    let statusTone: StudioStatusTone

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(stepNumber)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(DS.Colors.textPrimary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(DS.Colors.surface2)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DS.Colors.textPrimary)

                    StudioStatusPill(label: statusLabel, tone: statusTone)
                }

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
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

private struct StudioMultilineField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.textTertiary)

            ZStack(alignment: .topLeading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundColor(DS.Colors.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minHeight: 120)
            }
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
