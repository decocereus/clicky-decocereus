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
    case designLab
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "Companion"
        case .openClaw:
            return "Connection"
        case .voiceAppearance:
            return "Voice & Persona"
        case .integrations:
            return "Launch Access"
        case .designLab:
            return "Design Lab"
        case .diagnostics:
            return "Support"
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
        case .designLab:
            return "square.on.square"
        case .diagnostics:
            return "stethoscope"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Daily shell controls"
        case .openClaw:
            return "Agent and gateway"
        case .voiceAppearance:
            return "Voice, tone, and look"
        case .integrations:
            return "Buy, restore, unlock"
        case .designLab:
            return "Three UI directions"
        case .diagnostics:
            return "Debug and reports"
        }
    }
}

struct CompanionStudioView: View {
    @ObservedObject var companionManager: CompanionManager

    @AppStorage("clickySupportModeEnabled") private var isSupportModeEnabled = false
    @State private var selectedSection: CompanionStudioSection = .general
    @State private var isOpenClawTokenVisible = false
    @State private var isElevenLabsAPIKeyVisible = false
    @State private var isElevenLabsVoiceImportExpanded = false

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
            normalizeSelectedSection()
        }
        .onDisappear {
            NotificationCenter.default.post(name: .clickyStudioDidDisappear, object: nil)
        }
        .onChange(of: isSupportModeEnabled) { _, _ in
            normalizeSelectedSection()
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
                ForEach(availableSections) { section in
                    Button(action: {
                        withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                            selectedSection = section
                        }
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

    private var availableSections: [CompanionStudioSection] {
        CompanionStudioSection.allCases.filter { section in
            if section == .designLab {
                return isSupportModeEnabled
            }
            return true
        }
    }

    private func normalizeSelectedSection() {
        if !availableSections.contains(selectedSection) {
            selectedSection = .general
        }
    }

    private var detailPane: some View {
        ScrollView {
            ClickyGlassCluster {
                VStack(alignment: .leading, spacing: 24) {
                    sectionHero
                    sectionContent
                }
                .id(selectedSection)
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
            Text(sectionChapterLabel)
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(sectionAccent)
                .tracking(1.2)

            Text(selectedSection.title)
                .font(ClickyTypography.display(size: 44))
                .foregroundColor(theme.textPrimary)

            Text(sectionHeroDescription)
                .font(ClickyTypography.mono(size: 14, weight: .medium))
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !sectionHeroBadges.isEmpty {
                HStack(spacing: 10) {
                    ForEach(sectionHeroBadges, id: \.label) { badge in
                        StudioStatusPill(label: "\(badge.label): \(badge.value)", tone: badge.tone)
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(.bottom, 6)
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
        case .designLab:
            StudioDesignLabView(companionManager: companionManager)
        case .diagnostics:
            diagnosticsSectionContent
        }
    }

    private var generalSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Companion", subtitle: "The production-facing shell surface should stay focused and calm") {
                VStack(spacing: 12) {
                    StudioKeyValueRow(label: "Hotkey", value: "Control + Option")
                    StudioKeyValueRow(label: "Overlay", value: companionManager.isOverlayVisible ? "Visible" : "Hidden")
                    StudioKeyValueRow(label: "Speech to Text", value: companionManager.buddyDictationManager.transcriptionProviderDisplayName)
                    StudioKeyValueRow(label: "Speech Output", value: companionManager.effectiveVoiceOutputDisplayName)
                    StudioKeyValueRow(label: "Backend Mode", value: CompanionRuntimeConfiguration.isWorkerConfigured ? "Cloud worker configured" : "Local fallback mode")
                }
            }

            StudioCard(title: "Agent", subtitle: "Choose which brain powers the companion without exposing the deeper debug controls here") {
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

            StudioCard(title: "Quick Controls", subtitle: "Only the daily product controls belong here") {
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

            pluginSetupCards
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

            StudioCard(title: "Voice", subtitle: "Choose how Clicky speaks and preview it before the next turn") {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        ForEach(ClickySpeechProviderMode.allCases) { mode in
                            selectionChip(
                                title: mode.displayName,
                                subtitle: mode == .system ? "Built in on this Mac." : "Bring your own key and voices.",
                                isSelected: companionManager.clickySpeechProviderMode == mode
                            ) {
                                companionManager.clickySpeechProviderMode = mode
                            }
                        }
                    }

                    if companionManager.clickySpeechProviderMode == .system {
                        systemSpeechPanel
                    } else {
                        elevenLabsSpeechPanel
                    }

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

                    StudioKeyValueRow(label: "Selected provider", value: companionManager.clickySpeechProviderMode.displayName)
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

    private var systemSpeechPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System speech is active")
                        .font(ClickyTypography.body(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    Text("The built-in macOS voice on this Mac is handling playback right now.")
                        .font(ClickyTypography.body(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                StudioStatusPill(label: "Built in", tone: .success)
            }

            previewVoiceButton
            speechPreviewFeedbackView
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.primary.opacity(0.24), lineWidth: 1)
        )
    }

    private var elevenLabsSpeechPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ElevenLabs is selected")
                        .font(ClickyTypography.body(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    Text("Bring your own voice, hear it before the next turn, and keep the key local to this Mac.")
                        .font(ClickyTypography.body(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                StudioStatusPill(label: elevenLabsProviderStatusLabel, tone: elevenLabsProviderStatusTone)
            }

            StudioCallout(
                tone: .info,
                systemImage: "lock.shield",
                title: "Stored only on this Mac",
                message: "Your ElevenLabs API key stays in Keychain on this Mac. Clicky does not upload it to us."
            )

            if let speechFallbackSummary = companionManager.speechFallbackSummary {
                StudioCallout(
                    tone: .warning,
                    systemImage: "speaker.slash",
                    title: "System fallback active",
                    message: speechFallbackSummary
                )
            }

            if let elevenLabsVoiceLoadIssueMessage {
                StudioCallout(
                    tone: .warning,
                    systemImage: "exclamationmark.triangle",
                    title: "Voice setup needs attention",
                    message: elevenLabsVoiceLoadIssueMessage
                )
            }

            StudioSecretField(
                title: "ElevenLabs API key",
                text: Binding(
                    get: { companionManager.elevenLabsAPIKeyDraft },
                    set: { companionManager.elevenLabsAPIKeyDraft = $0 }
                ),
                placeholder: "Paste your ElevenLabs API key",
                isRevealed: $isElevenLabsAPIKeyVisible
            )

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    voiceActionButton(
                        title: "Save Key",
                        systemImage: "key.horizontal",
                        isEnabled: true
                    ) {
                        companionManager.saveElevenLabsAPIKey()
                    }

                    voiceActionButton(
                        title: isLoadingElevenLabsVoices ? "Loading..." : "Load Voices",
                        systemImage: "waveform.badge.magnifyingglass",
                        isEnabled: !isLoadingElevenLabsVoices
                    ) {
                        companionManager.refreshElevenLabsVoices()
                    }
                }

                HStack(spacing: 10) {
                    importVoiceToggleButton

                    previewVoiceButton
                }
            }

            if isElevenLabsVoiceImportExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    StudioTextField(
                        title: "Import voice by ID",
                        text: Binding(
                            get: { companionManager.elevenLabsImportVoiceIDDraft },
                            set: { companionManager.elevenLabsImportVoiceIDDraft = $0 }
                        ),
                        placeholder: "Paste an ElevenLabs voice ID"
                    )

                    StudioCallout(
                        tone: .neutral,
                        systemImage: "square.and.arrow.down",
                        title: "Bring in a specific voice",
                        message: "Use this only if your voice does not appear after loading voices. Shared and custom voices usually require a subscriber account and may need to be added to My Voices first."
                    )

                    voiceActionButton(
                        title: isImportingElevenLabsVoice ? "Importing..." : "Import Voice",
                        systemImage: "square.and.arrow.down",
                        isEnabled: !isImportingElevenLabsVoice
                    ) {
                        isElevenLabsVoiceImportExpanded = true
                        companionManager.importElevenLabsVoiceByID()
                    }
                    
                    importVoiceFeedbackView
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.025))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.strokeSoft, lineWidth: 1)
                )
            }

            StudioKeyValueRow(label: "Selected voice", value: companionManager.effectiveSpeechRouting.selectedVoiceNameLabel)

            if !companionManager.elevenLabsAvailableVoices.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose a voice")
                        .font(ClickyTypography.mono(size: 11, weight: .semibold))
                        .foregroundColor(theme.textMuted)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(companionManager.elevenLabsAvailableVoices) { voice in
                                selectionChip(
                                    title: voice.name,
                                    subtitle: voice.displaySubtitle,
                                    isSelected: companionManager.elevenLabsSelectedVoiceID == voice.id
                                ) {
                                    companionManager.selectElevenLabsVoice(voice)
                                }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .frame(maxHeight: 320)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.025))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(theme.strokeSoft, lineWidth: 1)
                    )
                }
            }

            speechPreviewFeedbackView
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.primary.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.primary.opacity(0.28), lineWidth: 1.2)
        )
    }

    private var previewVoiceButton: some View {
        voiceActionButton(
            title: companionManager.isSpeechPreviewInFlight ? "Playing..." : "Preview Voice",
            systemImage: "play.circle",
            isEnabled: !companionManager.isSpeechPreviewInFlight
        ) {
            companionManager.previewCurrentSpeechOutput()
        }
    }

    private var importVoiceToggleButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                isElevenLabsVoiceImportExpanded.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isElevenLabsVoiceImportExpanded ? "chevron.up.circle" : "square.and.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                Text(isElevenLabsVoiceImportExpanded ? "Hide Voice ID Import" : "Import by Voice ID")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
            }
            .foregroundColor(theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    @ViewBuilder
    private var speechPreviewFeedbackView: some View {
        if let speechPreviewStatusMessage = companionManager.speechPreviewStatusMessage {
            StudioCallout(
                tone: speechPreviewStatusTone,
                systemImage: speechPreviewStatusIcon,
                title: companionManager.speechPreviewStatusLabel,
                message: speechPreviewStatusMessage
            )
        }
    }

    @ViewBuilder
    private var importVoiceFeedbackView: some View {
        if let elevenLabsImportStatusMessage {
            StudioCallout(
                tone: elevenLabsImportStatusTone,
                systemImage: elevenLabsImportStatusIcon,
                title: elevenLabsImportStatusTitle,
                message: elevenLabsImportStatusMessage
            )
        }
    }

    private func voiceActionButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
            }
            .foregroundColor(isEnabled ? theme.textPrimary : theme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.primary.opacity(isEnabled ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.primary.opacity(isEnabled ? 0.24 : 0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .pointerCursor(isEnabled: isEnabled)
    }

    private var integrationsSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Launch Access", subtitle: "This panel should stay product-facing and clean while diagnostics lives elsewhere") {
                VStack(alignment: .leading, spacing: 12) {
                    StudioKeyValueRow(label: "Account", value: companionManager.clickyLaunchAuthStatusLabel)
                    StudioKeyValueRow(label: "Entitlement", value: companionManager.clickyLaunchEntitlementStatusLabel)
                    StudioKeyValueRow(label: "Trial", value: companionManager.clickyLaunchTrialStatusLabel)
                    StudioKeyValueRow(label: "Checkout", value: companionManager.clickyLaunchBillingStatusLabel)

                    HStack(spacing: 10) {
                        launchAccessButton(
                            title: "Sign In",
                            systemImage: "person.crop.circle.badge.plus"
                        ) {
                            companionManager.startClickyLaunchSignIn()
                        }

                        launchAccessButton(
                            title: "Sign Out",
                            systemImage: "person.crop.circle.badge.xmark"
                        ) {
                            companionManager.signOutClickyLaunchSession()
                        }
                    }

                    HStack(spacing: 10) {
                        launchAccessPrimaryButton(
                            title: "Buy Launch Pass",
                            systemImage: "creditcard"
                        ) {
                            companionManager.startClickyLaunchCheckout()
                        }

                        launchAccessButton(
                            title: "Restore Access",
                            systemImage: "arrow.clockwise.circle"
                        ) {
                            companionManager.refreshClickyLaunchEntitlement()
                        }
                    }

                    Text("The Mac app initiates sign-in and purchase. Technical trial and paywall controls live in Support so this panel stays production-ready.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var diagnosticsSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Support", subtitle: "The only place where diagnostics, test controls, and exports should live") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        StudioStatusPill(
                            label: isSupportModeEnabled ? "Support mode on" : "Support mode off",
                            tone: isSupportModeEnabled ? .warning : .neutral
                        )

                        if isSupportModeEnabled {
                            StudioStatusPill(label: "Design Lab visible", tone: .info)
                        }
                    }

                    Text(isSupportModeEnabled
                         ? "Support mode is active. Internal diagnostics, shell tools, and launch simulation controls are now visible below."
                         : "Support mode is currently off. This keeps the main Studio production-ready while still leaving support reports available when you need them.")
                        .font(ClickyTypography.body(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle("Enable support mode", isOn: $isSupportModeEnabled)
                        .toggleStyle(.switch)
                        .tint(theme.primary)
                        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isSupportModeEnabled)

                    HStack(spacing: 10) {
                        supportActionButton(title: "Copy Support Report", systemImage: "doc.on.doc") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(diagnosticsSupportReportText, forType: .string)
                        }

                        supportActionButton(title: "Export Support Report", systemImage: "square.and.arrow.up") {
                            exportDiagnosticsSupportReport()
                        }
                    }

                    Text("Support reports include redacted recent logs and the current launch access state. Deeper debugging and simulation controls stay tucked away until support mode is enabled.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isSupportModeEnabled {
                StudioCard(title: "Launch Simulation", subtitle: "All launch trial and paywall simulation controls stay isolated here") {
                    VStack(alignment: .leading, spacing: 14) {
                        StudioKeyValueRow(label: "Backend URL", value: companionManager.clickyBackendStatusLabel)
                        StudioKeyValueRow(label: "Account", value: companionManager.clickyLaunchAuthStatusLabel)
                        StudioKeyValueRow(label: "Entitlement", value: companionManager.clickyLaunchEntitlementStatusLabel)
                        StudioKeyValueRow(label: "Trial", value: companionManager.clickyLaunchTrialStatusLabel)
                        StudioKeyValueRow(label: "Checkout", value: companionManager.clickyLaunchBillingStatusLabel)

                        StudioTextField(
                            title: "Launch backend URL",
                            text: Binding(
                                get: { companionManager.clickyBackendBaseURL },
                                set: { companionManager.clickyBackendBaseURL = $0 }
                            ),
                            placeholder: "https://api.clicky.app"
                        )

                        HStack(spacing: 10) {
                            supportActionButton(title: "Activate Trial", systemImage: "sparkles") {
                                companionManager.activateClickyLaunchTrial()
                            }
                            supportActionButton(title: "Refresh Trial", systemImage: "hourglass") {
                                companionManager.refreshClickyLaunchTrialState()
                            }
                        }

                        HStack(spacing: 10) {
                            supportActionButton(title: "Consume Credit", systemImage: "minus.circle") {
                                companionManager.consumeClickyLaunchTrialCredit()
                            }
                            supportActionButton(title: "Activate Paywall", systemImage: "lock.circle") {
                                companionManager.activateClickyLaunchPaywall()
                            }
                        }

                        Text("These actions are only for support, QA, and paywall iteration. They should never sit next to the normal purchase and restore controls.")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                StudioCard(title: "Diagnostics", subtitle: "Internal app and integration state for debugging") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This section is intentionally technical. It should contain the debug state, shell tools, exports, and support-only actions that do not belong in the normal product flow.")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        StudioKeyValueRow(label: "Speech provider", value: companionManager.clickySpeechProviderMode.displayName)
                        StudioKeyValueRow(label: "Resolved output", value: companionManager.effectiveVoiceOutputDisplayName)
                        StudioKeyValueRow(label: "ElevenLabs voice", value: companionManager.effectiveSpeechRouting.selectedVoiceNameLabel)
                        StudioKeyValueRow(label: "Voice id", value: companionManager.effectiveSpeechRouting.selectedVoiceIDLabel)
                        StudioKeyValueRow(label: "Voice fetch", value: companionManager.elevenLabsStatusLabel)
                        StudioKeyValueRow(label: "Voice import", value: elevenLabsImportStatusTitle)
                        StudioKeyValueRow(label: "Speech fallback", value: companionManager.speechFallbackSummary ?? "No fallback")
                        StudioKeyValueRow(label: "Voice preview", value: companionManager.speechPreviewStatusLabel)
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
                            supportActionButton(title: "Clear Buffer", systemImage: "trash") {
                                ClickyDiagnosticsStore.shared.clear()
                            }
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                StudioCard(title: "Diagnostics Hidden", subtitle: "Production Studio stays clean until you deliberately reveal internal tools") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enable support mode when you need launch simulation, raw shell state, or deeper diagnostics. Until then, this panel stays intentionally quiet.")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            StudioStatusPill(label: "Launch simulation hidden", tone: .neutral)
                            StudioStatusPill(label: "Raw shell tools hidden", tone: .neutral)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isSupportModeEnabled)
    }

    private var sectionHeroDescription: String {
        switch selectedSection {
        case .general:
            return "The everyday chapter. Keep the shell soft, useful, and legible while the heavier configuration work stays deeper in the story."
        case .openClaw:
            return "Bring your existing OpenClaw agent into Clicky without breaking its identity. Connection, presence, and bridge setup all live here."
        case .voiceAppearance:
            return "Voice, persona, and the surface look all belong to the same chapter. This is where Clicky starts feeling like itself."
        case .integrations:
            return "A clean commercial chapter. Sign in, unlock, and restore without any of the internal launch scaffolding leaking into the user path."
        case .designLab:
            return "Compare three Studio directions before we commit to a full redesign. Each option keeps diagnostics isolated from the production-facing app flow."
        case .diagnostics:
            return "A technical appendix for debugging, exports, and launch simulation. This is intentionally backstage."
        }
    }

    private var sectionChapterLabel: String {
        switch selectedSection {
        case .general:
            return "Chapter 01"
        case .openClaw:
            return "Chapter 02"
        case .voiceAppearance:
            return "Chapter 03"
        case .integrations:
            return "Chapter 04"
        case .designLab:
            return "Lab"
        case .diagnostics:
            return "Appendix"
        }
    }

    private var sectionAccent: Color {
        switch selectedSection {
        case .general:
            return theme.glowA
        case .openClaw:
            return theme.primary
        case .voiceAppearance:
            return theme.accent
        case .integrations:
            return theme.warning
        case .designLab:
            return theme.accentStrong
        case .diagnostics:
            return theme.glowB
        }
    }

    private var sectionHeroBadges: [(label: String, value: String, tone: StudioStatusTone)] {
        switch selectedSection {
        case .general:
            return [
                ("Backend", companionManager.selectedAgentBackend.displayName, .info),
                ("Speech", companionManager.effectiveVoiceOutputDisplayName, .neutral)
            ]
        case .openClaw:
            return [
                ("Gateway", openClawConnectionStatusLabel, openClawConnectionTone),
                ("Identity", companionManager.effectiveClickyPresentationName, .neutral)
            ]
        case .voiceAppearance:
            return [
                ("Theme", companionManager.clickyThemePreset.displayName, .info),
                ("Voice", companionManager.effectiveVoiceOutputDisplayName, .neutral)
            ]
        case .integrations:
            return [
                ("Account", companionManager.clickyLaunchAuthStatusLabel, .neutral),
                ("Entitlement", companionManager.clickyLaunchEntitlementStatusLabel, .success),
                ("Trial", companionManager.clickyLaunchTrialStatusLabel, .warning)
            ]
        case .designLab:
            return [
                ("Mode", "Exploration", .info)
            ]
        case .diagnostics:
            return [
                ("Support", isSupportModeEnabled ? "Enabled" : "Hidden", isSupportModeEnabled ? .warning : .neutral)
            ]
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

    private var isLoadingElevenLabsVoices: Bool {
        if case .loading = companionManager.elevenLabsVoiceFetchStatus {
            return true
        }

        return false
    }

    private var elevenLabsProviderStatusLabel: String {
        if isLoadingElevenLabsVoices {
            return "Loading"
        }

        if companionManager.speechFallbackSummary != nil {
            return "Fallback active"
        }

        if elevenLabsVoiceLoadIssueMessage != nil {
            return "Needs attention"
        }

        return companionManager.hasStoredElevenLabsAPIKey ? "Ready" : "Key needed"
    }

    private var elevenLabsProviderStatusTone: StudioStatusTone {
        if isLoadingElevenLabsVoices {
            return .info
        }

        if companionManager.speechFallbackSummary != nil || elevenLabsVoiceLoadIssueMessage != nil {
            return .warning
        }

        return companionManager.hasStoredElevenLabsAPIKey ? .success : .warning
    }

    private var elevenLabsVoiceLoadIssueMessage: String? {
        switch companionManager.elevenLabsVoiceFetchStatus {
        case .failed(let message):
            return message
        case .loaded:
            if companionManager.hasStoredElevenLabsAPIKey && companionManager.elevenLabsAvailableVoices.isEmpty {
                return "This ElevenLabs account does not have any voices available yet."
            }
            return nil
        case .idle, .loading:
            return nil
        }
    }

    private var isImportingElevenLabsVoice: Bool {
        if case .importing = companionManager.elevenLabsVoiceImportStatus {
            return true
        }

        return false
    }

    private var elevenLabsImportStatusTitle: String {
        switch companionManager.elevenLabsVoiceImportStatus {
        case .idle:
            return "Import voice"
        case .importing:
            return "Importing voice"
        case .succeeded:
            return "Voice imported"
        case .failed:
            return "Import failed"
        }
    }

    private var elevenLabsImportStatusMessage: String? {
        switch companionManager.elevenLabsVoiceImportStatus {
        case .idle:
            return nil
        case .importing:
            return "Clicky is fetching that voice from ElevenLabs now."
        case .succeeded(let message), .failed(let message):
            return message
        }
    }

    private var elevenLabsImportStatusTone: StudioStatusTone {
        switch companionManager.elevenLabsVoiceImportStatus {
        case .idle:
            return .neutral
        case .importing:
            return .info
        case .succeeded:
            return .success
        case .failed:
            return .warning
        }
    }

    private var elevenLabsImportStatusIcon: String {
        switch companionManager.elevenLabsVoiceImportStatus {
        case .idle:
            return "square.and.arrow.down"
        case .importing:
            return "arrow.down.circle"
        case .succeeded:
            return "checkmark.circle"
        case .failed:
            return "xmark.octagon"
        }
    }

    private var speechPreviewStatusTone: StudioStatusTone {
        switch companionManager.speechPreviewStatus {
        case .idle:
            return .neutral
        case .previewing:
            return .info
        case .succeeded:
            return companionManager.speechFallbackSummary == nil ? .success : .warning
        case .failed:
            return .warning
        }
    }

    private var speechPreviewStatusIcon: String {
        switch companionManager.speechPreviewStatus {
        case .idle:
            return "speaker.wave.2"
        case .previewing:
            return "speaker.wave.2.fill"
        case .succeeded:
            return companionManager.speechFallbackSummary == nil ? "checkmark.circle" : "speaker.slash"
        case .failed:
            return "xmark.octagon"
        }
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
    private var pluginSetupCards: some View {
        if shouldShowPluginSetupFlow {
            StudioCard(title: "Desktop Bridge Setup", subtitle: "A one-time setup step for this machine") {
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
                }
            }
        } else {
            StudioCard(title: "Desktop Bridge", subtitle: "The OpenClaw bridge is already set up on this machine") {
                VStack(alignment: .leading, spacing: 12) {
                    StudioStatusPill(label: "Ready", tone: .success)

                    Text("Clicky is already connected to OpenClaw here. You should not need to repeat setup unless you reinstall OpenClaw or move to a different machine.")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var diagnosticsSupportReportText: String {
        let contextLines = [
            "Clicky Support Report",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "App Auth: \(companionManager.clickyLaunchAuthStatusLabel)",
            "Entitlement: \(companionManager.clickyLaunchEntitlementStatusLabel)",
            "Checkout: \(companionManager.clickyLaunchBillingStatusLabel)",
            "Speech Provider: \(companionManager.clickySpeechProviderMode.displayName)",
            "Resolved Output: \(companionManager.effectiveVoiceOutputDisplayName)",
            "OpenClaw Agent: \(companionManager.inferredOpenClawAgentIdentifier ?? "Not detected")",
            "Shell Trust: \(companionManager.clickyShellServerTrustLabel)",
            "Shell Freshness: \(companionManager.clickyShellServerFreshnessLabel)",
            "Session Binding: \(companionManager.clickyShellServerBindingLabel)",
            "",
            "Recent Logs",
            ClickyDiagnosticsStore.shared.formattedRecentLogText()
        ]

        return contextLines.joined(separator: "\n")
    }

    private func exportDiagnosticsSupportReport() {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "clicky-support-report.txt"
        savePanel.title = "Export Clicky Support Report"
        savePanel.message = "This report contains redacted diagnostics and recent logs."

        guard savePanel.runModal() == .OK,
              let url = savePanel.url else { return }

        do {
            try diagnosticsSupportReportText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
        }
    }

    private func supportActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
            }
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.card.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private func launchAccessButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
            }
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.card.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private func launchAccessPrimaryButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.primary)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
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
                Text(subtitle)
                    .font(ClickyTypography.mono(size: 12, weight: .medium))
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Text(title)
                    .font(ClickyTypography.display(size: 30))
                    .foregroundColor(theme.textPrimary)
            }

            content
        }
        .clickyGlassCard(cornerRadius: 30, padding: 24)
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

private struct StudioCallout: View {
    @Environment(\.clickyTheme) private var theme

    let tone: StudioStatusTone
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(foregroundColor)
                .frame(width: 16, height: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(message)
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
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
            return Color.white.opacity(0.02)
        case .success:
            return theme.success.opacity(0.10)
        case .warning:
            return theme.warning.opacity(0.10)
        case .info:
            return theme.accent.opacity(0.10)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral:
            return theme.strokeSoft
        case .success:
            return theme.success.opacity(0.28)
        case .warning:
            return theme.warning.opacity(0.28)
        case .info:
            return theme.accent.opacity(0.28)
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
