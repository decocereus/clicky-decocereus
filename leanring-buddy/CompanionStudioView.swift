//
//  CompanionStudioView.swift
//  leanring-buddy
//
//  Desktop configuration surface for the companion shell.
//

import AppKit
import SwiftUI

private enum CompanionStudioSection: String, CaseIterable, Identifiable, Hashable {
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
            return "Persona"
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
            return "Connection and identity"
        case .voiceAppearance:
            return "Tone, voice, and look"
        case .integrations:
            return "Setup and status"
        case .diagnostics:
            return "Internal only"
        }
    }
}

struct CompanionStudioView: View {
    @ObservedObject var companionManager: CompanionManager

    @State private var selectedSection: CompanionStudioSection = .general
    @State private var isOpenClawTokenVisible = false

    private var theme: ClickyTheme {
        companionManager.activeClickyTheme
    }

    var body: some View {
        ZStack {
            ClickyAuraBackground()
            NavigationSplitView {
                sidebar
            } detail: {
                detailPane
            }
            .navigationSplitViewStyle(.balanced)
        }
        .clickyTheme(theme)
        .onAppear {
            NotificationCenter.default.post(name: .clickyStudioDidAppear, object: nil)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .clickyStudioDidDisappear, object: nil)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("clicky")
                    .font(ClickyTypography.brand(size: 40))
                    .foregroundColor(theme.accent)

                Text("Studio")
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(theme.textMuted)
                    .tracking(1.1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            List {
                ForEach(CompanionStudioSection.allCases) { section in
                    Button(action: {
                        selectedSection = section
                    }) {
                        studioSidebarRow(for: section)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                        .listRowInsets(EdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 240, idealWidth: 260)
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.top, 12)
    }

    private var detailPane: some View {
        ScrollView {
            ClickyGlassCluster {
                VStack(alignment: .leading, spacing: 24) {
                    sectionHero
                    sectionContent
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func studioSidebarRow(for section: CompanionStudioSection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: section.iconSystemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 16)
                .foregroundColor(selectedSection == section ? theme.accent : theme.textMuted)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(section.subtitle)
                    .font(ClickyTypography.mono(size: 10, weight: .medium))
                    .foregroundColor(theme.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(sidebarRowBackground(isSelected: selectedSection == section))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func sidebarRowBackground(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        if isSelected {
            if #available(macOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular.tint(theme.primary.opacity(0.18)).interactive(), in: shape)
            } else {
                shape
                    .fill(theme.primary.opacity(0.14))
            }
        } else {
            shape
                .fill(Color.clear)
        }
    }

    private var sectionHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedSection.title)
                .font(ClickyTypography.display(size: 44))
                .foregroundColor(theme.textPrimary)

            Text(sectionHeroDescription)
                .font(ClickyTypography.mono(size: 14, weight: .medium))
                .foregroundColor(theme.textSecondary)
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
            StudioCard(title: "Connection", subtitle: "Use your existing OpenClaw agent inside Clicky") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        StudioStatusPill(
                            label: openClawConnectionStatusLabel,
                            tone: openClawConnectionTone
                        )

                        StudioStatusPill(
                            label: companionManager.isOpenClawGatewayRemote ? "Remote Gateway" : "Local Gateway",
                            tone: companionManager.isOpenClawGatewayRemote ? .info : .success
                        )
                    }

                    Text(openClawConnectionSummary)
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

            StudioCard(title: "Advanced Connection Settings", subtitle: "Only change these when you are pointing Clicky at a different OpenClaw host or debugging setup") {
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

                    StudioTextField(title: "Agent ID", text: Binding(
                        get: { companionManager.openClawAgentIdentifier },
                        set: { companionManager.openClawAgentIdentifier = $0 }
                    ), placeholder: "Optional fixed OpenClaw agent id")

                    StudioTextField(title: "Session Key", text: Binding(
                        get: { companionManager.openClawSessionKey },
                        set: { companionManager.openClawSessionKey = $0 }
                    ), placeholder: "clicky-companion")

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
            personaPresetCard

            StudioCard(title: "Persona Notes", subtitle: "These instructions shape how Clicky speaks inside the app") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your upstream OpenClaw identity stays clean. These notes are Clicky-local presentation and tone guidance.")
                        .font(ClickyTypography.body(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    StudioMultilineField(
                        title: "Tone notes",
                        text: Binding(
                            get: { companionManager.clickyPersonaToneInstructions },
                            set: { companionManager.clickyPersonaToneInstructions = $0 }
                        ),
                        placeholder: "Example: sound more encouraging, explain a little slower, and keep the tone grounded."
                    )
                }
            }

            StudioCard(title: "Voice", subtitle: "Choose how the persona should sound") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ForEach(ClickyVoicePreset.allCases) { preset in
                            selectionChip(
                                title: preset.displayName,
                                subtitle: preset.summary,
                                isSelected: companionManager.clickyVoicePreset == preset
                            ) {
                                companionManager.clickyVoicePreset = preset
                            }
                        }
                    }

                    StudioKeyValueRow(label: "Current output", value: companionManager.effectiveVoiceOutputDisplayName)
                }
            }

            themeCard

            StudioCard(title: "Cursor Style", subtitle: "Set the visual personality of the companion shell") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ForEach(ClickyCursorStyle.allCases) { style in
                            selectionChip(
                                title: style.displayName,
                                subtitle: style.summary,
                                isSelected: companionManager.clickyCursorStyle == style
                            ) {
                                companionManager.clickyCursorStyle = style
                            }
                        }
                    }

                    Toggle(
                        "Show Clicky cursor overlay",
                        isOn: Binding(
                            get: { companionManager.isClickyCursorEnabled },
                            set: { companionManager.setClickyCursorEnabled($0) }
                        )
                    )
                    .toggleStyle(.switch)
                    .tint(theme.primary)
                }
            }

            StudioCard(title: "Runtime", subtitle: "What handles transcription and playback right now") {
                VStack(spacing: 12) {
                    StudioKeyValueRow(label: "Transcription Engine", value: companionManager.buddyDictationManager.transcriptionProviderDisplayName)
                    StudioKeyValueRow(label: "Speech Output", value: companionManager.effectiveVoiceOutputDisplayName)
                    StudioKeyValueRow(label: "Voice States", value: "Listening • Transcribing • Thinking • Responding")
                }
            }
        }
    }

    private var personaPresetCard: some View {
        StudioCard(title: "Persona Preset", subtitle: "Pick the default personality layer for Clicky") {
            VStack(alignment: .leading, spacing: 16) {
                Text(companionManager.activeClickyPersonaSummary)
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    ForEach(ClickyPersonaPreset.allCases) { preset in
                        selectionChip(
                            title: preset.definition.displayName,
                            subtitle: preset.definition.summary,
                            isSelected: companionManager.clickyPersonaPreset == preset
                        ) {
                            companionManager.setClickyPersonaPreset(preset)
                        }
                    }
                }
            }
        }
    }

    private var themeCard: some View {
        StudioCard(title: "Theme", subtitle: "This palette drives Studio now and becomes the persona surface later") {
            VStack(alignment: .leading, spacing: 16) {
                Text("The UI foundation is now themeable. As persona customization grows, this same layer can drive accent color, glass tint, cursor style, and voice presentation together.")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    ForEach(ClickyThemePreset.allCases) { preset in
                        themePresetButton(for: preset)
                    }
                }
            }
        }
    }

    private func themePresetButton(for preset: ClickyThemePreset) -> some View {
        let presetTheme = preset.theme
        let isSelected = companionManager.clickyThemePreset == preset

        return Button(action: {
            companionManager.clickyThemePreset = preset
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(presetTheme.primary)
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(presetTheme.glowA)
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(presetTheme.glowB)
                        .frame(width: 10, height: 10)
                }

                Text(preset.displayName)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? presetTheme.primary.opacity(0.10) : Color.white.opacity(0.015))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? presetTheme.primary.opacity(0.24) : presetTheme.strokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private func selectionChip(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(subtitle)
                    .font(ClickyTypography.mono(size: 10, weight: .medium))
                    .foregroundColor(theme.textMuted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? theme.primary.opacity(0.10) : Color.white.opacity(0.015))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? theme.primary.opacity(0.24) : theme.strokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private var integrationsSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if shouldShowPluginSetupFlow {
                StudioCard(title: "Set Up the OpenClaw Plugin", subtitle: "This is a one-time setup on this machine") {
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

                        Text("Once that is done, Clicky will reconnect automatically. You should not need to keep running these commands.")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                StudioCard(title: "OpenClaw Integration", subtitle: "The desktop bridge is ready on this machine") {
                    VStack(alignment: .leading, spacing: 12) {
                        StudioStatusPill(label: "Ready", tone: .success)

                        Text("Clicky is already connected to OpenClaw here. You do not need to run setup commands again unless you reinstall OpenClaw or move to a different machine.")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            StudioCard(title: "What You Get", subtitle: "What this integration unlocks inside Clicky") {
                VStack(alignment: .leading, spacing: 12) {
                    StudioStatusPill(
                        label: companionManager.clickyOpenClawPluginStatusLabel,
                        tone: clickyPluginStatusTone
                    )

                    Text("Clicky can speak responses, stay visually present next to your cursor, and keep your OpenClaw agent feeling native inside the desktop experience without rewriting that agent’s core identity.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            StudioCard(title: "Remote Support", subtitle: "You can still use this with a hosted OpenClaw instance later") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(companionManager.clickyOpenClawRemoteReadinessSummary)
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

                    HStack(spacing: 10) {
                        Button(action: {
                            companionManager.registerClickyShellNow()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Register Shell")
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
                    }

                    shellRegistrationStatusView

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
            return "Connect Clicky to your OpenClaw agent, keep the identity clean, and only touch technical setup when you actually need to."
        case .voiceAppearance:
            return "Own the speech pipeline and visual shell here so later voice packs and cursor skins have a real home."
        case .integrations:
            return "Set up the OpenClaw bridge once, then let it fade into the background so the integration feels built in."
        case .diagnostics:
            return "Internal activity, bridge state, and debugging details live here instead of cluttering the normal user flow."
        }
    }

    private var shouldShowPluginSetupFlow: Bool {
        companionManager.clickyOpenClawPluginStatus != .enabled
    }

    private var openClawConnectionSummary: String {
        if companionManager.isOpenClawGatewayRemote {
            return "Clicky is pointed at a remote OpenClaw Gateway. As long as the URL is reachable and the token is valid, the desktop shell should behave the same way."
        }

        return "Clicky is using the local OpenClaw Gateway on this Mac. This is the simplest setup and should work automatically once OpenClaw is running."
    }

    private var openClawConnectionButtonLabel: String {
        if isTestingOpenClawConnection {
            return "Testing Gateway..."
        }

        return "Test OpenClaw Connection"
    }

    private var openClawConnectionStatusLabel: String {
        switch companionManager.openClawConnectionStatus {
        case .idle:
            return "Not checked yet"
        case .testing:
            return "Checking connection"
        case .connected:
            return "Connected"
        case .failed:
            return "Needs attention"
        }
    }

    private var openClawConnectionTone: StudioStatusTone {
        switch companionManager.openClawConnectionStatus {
        case .idle:
            return .neutral
        case .testing:
            return .info
        case .connected:
            return .success
        case .failed:
            return .warning
        }
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

    @ViewBuilder
    private var shellRegistrationStatusView: some View {
        switch companionManager.clickyShellRegistrationStatus {
        case .idle:
            Text("No active shell registration event yet in this app session.")
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
            VStack(alignment: .leading, spacing: 8) {
                StudioStatusPill(label: "Shell registered", tone: .success)
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                StudioStatusPill(label: "Registration issue", tone: .warning)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct StudioCard<Content: View>: View {
    @Environment(\.clickyTheme) private var theme

    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ClickyTypography.section(size: 23))
                    .foregroundColor(theme.textPrimary)
                Text(subtitle)
                    .font(ClickyTypography.mono(size: 12, weight: .medium))
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(theme.card.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(theme.strokeSoft, lineWidth: 1)
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
    @Environment(\.clickyTheme) private var theme

    let label: String
    let tone: StudioStatusTone

    var body: some View {
        Text(label)
            .font(ClickyTypography.mono(size: 11, weight: .semibold))
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
            return theme.textSecondary
        case .success:
            return theme.success
        case .warning:
            return theme.warning
        case .info:
            return theme.accentStrong
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            return Color.white.opacity(0.025)
        case .success:
            return theme.success.opacity(0.12)
        case .warning:
            return theme.warning.opacity(0.12)
        case .info:
            return theme.accent.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral:
            return theme.strokeSoft
        case .success:
            return theme.success.opacity(0.35)
        case .warning:
            return theme.warning.opacity(0.35)
        case .info:
            return theme.accent.opacity(0.35)
        }
    }
}

private struct StudioKeyValueRow: View {
    @Environment(\.clickyTheme) private var theme

    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(theme.textMuted)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(ClickyTypography.body(size: 14, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StudioCommandBlock: View {
    @Environment(\.clickyTheme) private var theme

    let title: String
    let command: String

    @State private var hasCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(theme.textMuted)

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
                            .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    }
                    .foregroundColor(hasCopied ? theme.success : theme.textSecondary)
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }

            Text(command)
                .font(ClickyTypography.mono(size: 12, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.strokeSoft, lineWidth: 1)
                )
                .textSelection(.enabled)
        }
    }
}

private struct StudioStepRow: View {
    @Environment(\.clickyTheme) private var theme

    let stepNumber: Int
    let title: String
    let detail: String
    let statusLabel: String
    let statusTone: StudioStatusTone

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(stepNumber)")
                .font(ClickyTypography.mono(size: 12, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.03))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(title)
                        .font(ClickyTypography.body(size: 14, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    StudioStatusPill(label: statusLabel, tone: statusTone)
                }

                Text(detail)
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

private struct StudioTextField: View {
    @Environment(\.clickyTheme) private var theme

    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(theme.textMuted)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(ClickyTypography.body(size: 14))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.strokeSoft, lineWidth: 1)
                )
        }
    }
}

private struct StudioSecretField: View {
    @Environment(\.clickyTheme) private var theme

    let title: String
    @Binding var text: String
    let placeholder: String
    @Binding var isRevealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(theme.textMuted)

            HStack(spacing: 10) {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .font(ClickyTypography.body(size: 14))
                .foregroundColor(theme.textPrimary)

                Button(action: {
                    isRevealed.toggle()
                }) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textMuted)
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 1)
            )
        }
    }
}

private struct StudioMultilineField: View {
    @Environment(\.clickyTheme) private var theme

    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(theme.textMuted)

            ZStack(alignment: .topLeading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(ClickyTypography.body(size: 13))
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $text)
                    .font(ClickyTypography.body(size: 14))
                    .foregroundColor(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minHeight: 120)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 1)
            )
        }
    }
}
