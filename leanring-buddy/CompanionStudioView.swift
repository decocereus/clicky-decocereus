//
//  CompanionStudioView.swift
//  leanring-buddy
//
//  Desktop configuration surface for the companion shell.
//

import AppKit
import OSLog
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
    @Namespace private var studioGlassNamespace

    private var theme: ClickyTheme {
        companionManager.activeClickyTheme
    }

    private var sidebarTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .clickyTheme(theme)
        .ignoresSafeArea()
        .modifier(StudioWindowBackgroundClearStyle())
        .background(StudioWindowConfigurator())
        .onAppear {
            NotificationCenter.default.post(name: .clickyStudioDidAppear, object: nil)
            normalizeSelectedSection()
            ClickyUnifiedTelemetry.windowing.info("Studio content appeared")
            ClickyUnifiedTelemetry.navigation.info(
                "Studio section ready section=\(self.selectedSection.rawValue, privacy: .public) reason=appear"
            )
        }
        .onDisappear {
            NotificationCenter.default.post(name: .clickyStudioDidDisappear, object: nil)
        }
        .onChange(of: isSupportModeEnabled) { _, _ in
            normalizeSelectedSection()
            ClickyLogger.notice(.ui, "Support mode toggled enabled=\(isSupportModeEnabled)")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            sidebarBrandHeader

            sidebarStatusDeck

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(availableSections) { section in
                        Button(action: {
                            selectSection(section, reason: "sidebar")
                        }) {
                            studioSidebarRow(for: section)
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()
                    }
                }
                .padding(.trailing, 6)
            }

            sidebarFooter
        }
        .frame(minWidth: 280, idealWidth: 296, maxWidth: 320, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 18)
        .padding(.top, 26)
        .padding(.bottom, 18)
    }

    private var sidebarBrandHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Desktop Shell")
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(sidebarTheme.textMuted)
                .tracking(1.2)

            Text("clicky")
                .font(ClickyTypography.brand(size: 40))
                .foregroundColor(sidebarTheme.primary)

            Text("Studio")
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(sidebarTheme.textMuted)
                .tracking(1.1)

            Text("A chapter-driven command deck for the deeper parts of the companion.")
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(sidebarTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.clear)
    }

    private var sidebarStatusDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Snapshot")
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(sidebarTheme.textMuted)
                .tracking(1.0)

            VStack(spacing: 10) {
                StudioSidebarSignalRow(
                    title: "Backend",
                    value: companionManager.selectedAgentBackend.displayName,
                    tone: .info
                )

                StudioSidebarSignalRow(
                    title: "Voice",
                    value: companionManager.effectiveVoiceOutputDisplayName,
                    tone: companionManager.clickySpeechProviderMode == .system ? .neutral : .success
                )

                StudioSidebarSignalRow(
                    title: "Access",
                    value: companionManager.clickyLaunchEntitlementStatusLabel,
                    tone: companionManager.isClickyLaunchPaywallActive ? .warning : .success
                )
            }
        }
        .modifier(StudioGlassPanelModifier(cornerRadius: 24, tint: sidebarTheme.secondary.opacity(0.10), padding: 16))
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Notes")
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(sidebarTheme.textMuted)

            Text("The menu bar companion stays fast and compact. Studio owns the deeper routing, launch access, persona, and support chapters.")
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(sidebarTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                StudioStatusPill(
                    label: companionManager.isOverlayVisible ? "Cursor live" : "Cursor ready",
                    tone: companionManager.isOverlayVisible ? .success : .neutral
                )

                StudioStatusPill(
                    label: isSupportModeEnabled ? "Support on" : "Support off",
                    tone: isSupportModeEnabled ? .warning : .neutral
                )
            }
        }
        .modifier(StudioGlassPanelModifier(cornerRadius: 22, tint: .white.opacity(0.02), padding: 16))
    }

    private var availableSections: [CompanionStudioSection] {
        CompanionStudioSection.allCases.filter { section in
            if section == .designLab || section == .diagnostics {
                return isSupportModeEnabled
            }
            return true
        }
    }

    private func normalizeSelectedSection() {
        if !availableSections.contains(selectedSection) {
            selectedSection = .general
            ClickyUnifiedTelemetry.navigation.info(
                "Studio section selected section=\(self.selectedSection.rawValue, privacy: .public) reason=normalized"
            )
        }
    }

    private func selectSection(_ section: CompanionStudioSection, reason: String) {
        guard selectedSection != section else { return }

        withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
            selectedSection = section
        }

        ClickyUnifiedTelemetry.navigation.info(
            "Studio section selected section=\(section.rawValue, privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    private var detailPane: some View {
        ZStack(alignment: .topLeading) {
            detailPaneBackdrop

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    studioOverviewBand
                    sectionHero

                    Group {
                        sectionContent
                    }
                    .id(selectedSection)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        )
                    )
                }
                .frame(maxWidth: 980, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.top, 26)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(12, for: .scrollIndicators)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: selectedSection)
    }

    @ViewBuilder
    private var detailPaneBackdrop: some View {
        if #available(macOS 26.0, *) {
            StudioDetailBackdrop(theme: theme)
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .backgroundExtensionEffect()
        } else {
            StudioDetailBackdrop(theme: theme)
                .frame(maxWidth: .infinity)
                .frame(height: 360)
        }
    }

    private func studioSidebarRow(for section: CompanionStudioSection) -> some View {
        let isSelected = selectedSection == section

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? sectionAccent.opacity(0.18) : sidebarTheme.secondary.opacity(0.55))
                    .frame(width: 34, height: 34)

                Image(systemName: section.iconSystemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? sectionAccent : sidebarTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(section.title)
                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                        .foregroundColor(sidebarTheme.textPrimary)

                    if isSelected {
                        Text("LIVE")
                            .font(ClickyTypography.mono(size: 9, weight: .semibold))
                            .foregroundColor(sectionAccent)
                            .tracking(0.8)
                    }
                }

                Text(section.subtitle)
                    .font(ClickyTypography.mono(size: 10, weight: .medium))
                    .foregroundColor(sidebarTheme.textMuted)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isSelected ? sectionAccent : sidebarTheme.textMuted.opacity(0.8))
                .opacity(isSelected ? 1 : 0.45)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(sidebarRowBackground(section: section, isSelected: isSelected))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func sidebarRowBackground(section: CompanionStudioSection, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        if isSelected {
            if #available(macOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular.tint(sectionAccent.opacity(0.12)).interactive(), in: shape)
                    .glassEffectID("sidebar-\(section.rawValue)", in: studioGlassNamespace)
            } else {
                shape
                    .fill(sidebarTheme.card.opacity(0.82))
                    .overlay(shape.stroke(sectionAccent.opacity(0.22), lineWidth: 1))
            }
        } else {
            shape
                .fill(sidebarTheme.card.opacity(0.30))
                .overlay(shape.stroke(sidebarTheme.border.opacity(0.22), lineWidth: 1))
        }
    }

    private var sectionHero: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text(sectionChapterLabel)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(sectionAccent)
                    .tracking(1.2)

                Text(selectedSection.title)
                    .font(ClickyTypography.display(size: 48))
                    .foregroundStyle(.primary)

                Text(sectionHeroDescription)
                    .font(ClickyTypography.body(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !sectionHeroBadges.isEmpty {
                    if #available(macOS 26.0, *) {
                        GlassEffectContainer(spacing: 10) {
                            HStack(spacing: 10) {
                                ForEach(sectionHeroBadges, id: \.label) { badge in
                                    StudioStatusPill(label: "\(badge.label): \(badge.value)", tone: badge.tone)
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            ForEach(sectionHeroBadges, id: \.label) { badge in
                                StudioStatusPill(label: "\(badge.label): \(badge.value)", tone: badge.tone)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            sectionHeroControlDeck
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .background(sectionHeroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 10)
    }

    private var studioOverviewBand: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    overviewBandCards
                }
            } else {
                overviewBandCards
            }
        }
    }

    private var overviewBandCards: some View {
        HStack(alignment: .center, spacing: 12) {
            StudioOverviewMetricCard(
                eyebrow: "Status",
                value: companionManager.isOverlayVisible ? "Listening-ready" : "Standing by",
                detail: companionManager.voiceState.displayTitle,
                accent: theme.glowA
            )

            StudioOverviewMetricCard(
                eyebrow: "Agent",
                value: companionManager.selectedAgentBackend.displayName,
                detail: companionManager.selectedAgentBackend == .claude ? companionManager.selectedModel : companionManager.inferredOpenClawAgentIdentityDisplayName,
                accent: theme.primary
            )

            StudioOverviewMetricCard(
                eyebrow: "Voice",
                value: companionManager.effectiveVoiceOutputDisplayName,
                detail: companionManager.clickyVoicePreset.displayName,
                accent: theme.accent
            )

            StudioOverviewMetricCard(
                eyebrow: "Launch",
                value: companionManager.clickyLaunchEntitlementStatusLabel,
                detail: companionManager.clickyLaunchTrialStatusLabel,
                accent: theme.warning
            )
        }
    }

    @ViewBuilder
    private var sectionHeroBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(sectionAccent.opacity(0.05)), in: shape)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            .clear,
                            sectionAccent.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                )
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            sectionAccent.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                )
        }
    }

    private var sectionHeroControlDeck: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Focus")
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(sectionHeroControlSummary)
                    .font(ClickyTypography.body(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            sectionHeroPrimaryAction
        }
        .frame(width: 280, alignment: .leading)
        .padding(18)
        .background(sectionHeroControlDeckBackground)
    }

    @ViewBuilder
    private var sectionHeroControlDeckBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.02)), in: shape)
        } else {
            shape
                .fill(theme.card.opacity(0.40))
                .overlay(
                    shape.stroke(theme.border.opacity(0.30), lineWidth: 0.8)
                )
        }
    }

    private var sectionHeroControlSummary: String {
        switch selectedSection {
        case .general:
            return "Tune the daily shell behavior without letting Studio turn into a cluttered inspector."
        case .openClaw:
            return "Keep the OpenClaw bridge healthy, visible, and easy to verify without exposing raw setup noise by default."
        case .voiceAppearance:
            return "Shape how Clicky sounds and presents itself so the desktop shell feels coherent, not just configurable."
        case .integrations:
            return "Handle sign-in, purchase, restore, and trial state in one commercial chapter with clean, confident actions."
        case .designLab:
            return "Compare alternate Studio directions before committing the product shell to one visual language."
        case .diagnostics:
            return "Surface backstage tools only when support work is intentional, not mixed into the everyday user path."
        }
    }

    @ViewBuilder
    private var sectionHeroPrimaryAction: some View {
        switch selectedSection {
        case .general:
            neutralStudioButton(title: "Open Companion Panel", systemImage: "sparkles") {
                NotificationCenter.default.post(name: .clickyShowPanel, object: nil)
            }
        case .openClaw:
            neutralStudioButton(
                title: openClawConnectionButtonLabel,
                systemImage: "bolt.horizontal.circle.fill",
                isEnabled: !isTestingOpenClawConnection
            ) {
                companionManager.testOpenClawConnection()
            }
        case .voiceAppearance:
            neutralStudioButton(
                title: companionManager.isSpeechPreviewInFlight ? "Playing..." : "Preview Voice",
                systemImage: "play.circle",
                isEnabled: !companionManager.isSpeechPreviewInFlight
            ) {
                companionManager.previewCurrentSpeechOutput()
            }
        case .integrations:
            launchAccessPrimaryButton(
                title: "Buy Launch Pass",
                systemImage: "creditcard",
                isEnabled: canStartLaunchCheckout
            ) {
                companionManager.startClickyLaunchCheckout()
            }
        case .designLab:
            neutralStudioButton(title: "Explore Concepts", systemImage: "square.on.square") {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    selectedSection = .designLab
                }
            }
        case .diagnostics:
            neutralStudioButton(title: "Copy Support Report", systemImage: "doc.on.doc") {
                copyDiagnosticsSupportReport()
            }
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
        case .designLab:
            StudioDesignLabView(companionManager: companionManager)
        case .diagnostics:
            diagnosticsSectionContent
        }
    }

    private var generalSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Companion", subtitle: "The everyday shell chapter should feel like one composed surface, not three unrelated cards") {
                VStack(alignment: .leading, spacing: 22) {
                    StudioSubsection(title: "Shell Snapshot", subtitle: "The pieces users actually feel every day") {
                        VStack(spacing: 12) {
                            StudioKeyValueRow(label: "Hotkey", value: "Control + Option")
                            StudioKeyValueRow(label: "Overlay", value: companionManager.isOverlayVisible ? "Visible" : "Hidden")
                            StudioKeyValueRow(label: "Speech to Text", value: companionManager.buddyDictationManager.transcriptionProviderDisplayName)
                            StudioKeyValueRow(label: "Speech Output", value: companionManager.effectiveVoiceOutputDisplayName)
                            StudioKeyValueRow(label: "Backend Mode", value: CompanionRuntimeConfiguration.isWorkerConfigured ? "Cloud worker configured" : "Local fallback mode")
                        }
                    }

                    StudioChapterDivider()

                    StudioSubsection(title: "Agent", subtitle: "Choose which brain powers the companion without exposing the deeper debug controls here") {
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
                                Text("OpenClaw is selected. Use the Connection chapter to configure local or remote Gateway access.")
                                    .font(.system(size: 12))
                                    .foregroundColor(DS.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    StudioChapterDivider()

                    StudioSubsection(title: "Quick Controls", subtitle: "Only the daily product controls belong here") {
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

                            Text("This keeps the fast menu bar companion intact while giving Studio room for deeper configuration elsewhere.")
                                .font(.system(size: 12))
                                .foregroundColor(DS.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    StudioChapterDivider()

                    StudioSubsection(title: "Support Tools", subtitle: "Backstage controls stay hidden until you explicitly reveal them") {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle("Enable support mode", isOn: $isSupportModeEnabled)
                                .toggleStyle(.switch)
                                .tint(theme.primary)

                            Text(isSupportModeEnabled
                                 ? "Support mode is on. Studio now reveals the Support and Design Lab chapters for diagnostics, launch simulation, and internal reports."
                                 : "Support mode is off. This keeps diagnostics, launch simulation, and internal reports out of the normal Studio navigation.")
                                .font(.system(size: 12))
                                .foregroundColor(DS.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var openClawSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Connection", subtitle: "Bring your existing OpenClaw agent into Clicky without turning this chapter into a wall of setup cards") {
                VStack(alignment: .leading, spacing: 22) {
                    StudioSubsection(title: "Gateway Status", subtitle: "The current link between Clicky and OpenClaw") {
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

                    StudioChapterDivider()

                    StudioSubsection(title: "Identity in Clicky", subtitle: "Choose how your existing OpenClaw agent shows up inside Clicky") {
                        VStack(alignment: .leading, spacing: 14) {
                            StudioKeyValueRow(
                                label: "Current agent",
                                value: companionManager.inferredOpenClawAgentIdentityDisplayName
                            )

                            neutralStudioButton(
                                title: "Refresh OpenClaw Identity",
                                systemImage: "arrow.clockwise"
                            ) {
                                companionManager.refreshOpenClawAgentIdentity()
                            }

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

                    neutralStudioButton(
                        title: openClawConnectionButtonLabel,
                        systemImage: "bolt.horizontal.circle.fill",
                        isEnabled: !isTestingOpenClawConnection
                    ) {
                        companionManager.testOpenClawConnection()
                    }

                    connectionStatusView
                }
            }

            pluginSetupCards
        }
    }

    private var voiceAppearanceSectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioCard(title: "Voice & Persona", subtitle: "This chapter owns how Clicky sounds, looks, and presents itself on your Mac") {
                VStack(alignment: .leading, spacing: 22) {
                    StudioSubsection(title: "Persona Preset", subtitle: "Pick the default personality layer for Clicky") {
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

                    StudioChapterDivider()

                    StudioSubsection(title: "Tone Notes", subtitle: "These instructions shape how Clicky speaks inside the app") {
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
                }
            }

            StudioCard(title: "Voice Output", subtitle: "Choose how Clicky speaks and preview it before the next turn") {
                VStack(alignment: .leading, spacing: 22) {
                    StudioSubsection(title: "Provider", subtitle: "Pick the voice engine for this Mac") {
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
                    }

                    if companionManager.clickySpeechProviderMode == .system {
                        systemSpeechPanel
                    } else {
                        elevenLabsSpeechPanel
                    }

                    StudioChapterDivider()

                    StudioSubsection(title: "Voice Preset", subtitle: "Shape the delivery style after the provider is chosen") {
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

                            StudioKeyValueRow(label: "Selected provider", value: companionManager.clickySpeechProviderMode.displayName)
                            StudioKeyValueRow(label: "Current output", value: companionManager.effectiveVoiceOutputDisplayName)
                        }
                    }
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
                        StudioStatusPill(label: launchAccessPrimaryStatus.label, tone: launchAccessPrimaryStatus.tone)
                        if let secondaryLaunchAccessStatus {
                            StudioStatusPill(label: secondaryLaunchAccessStatus.label, tone: secondaryLaunchAccessStatus.tone)
                        }
                    }

                    HStack(spacing: 10) {
                        launchAccessButton(
                            title: "Sign In",
                            systemImage: "person.crop.circle.badge.plus",
                            isEnabled: canStartLaunchSignIn
                        ) {
                            companionManager.startClickyLaunchSignIn()
                        }

                        launchAccessButton(
                            title: "Sign Out",
                            systemImage: "person.crop.circle.badge.xmark",
                            isEnabled: canSignOutLaunchSession
                        ) {
                            companionManager.signOutClickyLaunchSession()
                        }
                    }

                    HStack(spacing: 10) {
                        launchAccessPrimaryButton(
                            title: "Buy Launch Pass",
                            systemImage: "creditcard",
                            isEnabled: canStartLaunchCheckout
                        ) {
                            companionManager.startClickyLaunchCheckout()
                        }

                        launchAccessButton(
                            title: "Restore Access",
                            systemImage: "arrow.clockwise.circle",
                            isEnabled: canRestoreLaunchAccess
                        ) {
                            companionManager.restoreClickyLaunchAccess()
                        }
                    }

                    HStack(spacing: 10) {
                        launchAccessButton(
                            title: "Refresh Access",
                            systemImage: "arrow.clockwise",
                            isEnabled: canRefreshLaunchAccess
                        ) {
                            companionManager.refreshClickyLaunchEntitlement()
                        }
                    }

                    Text(launchAccessGuidanceText)
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
                            copyDiagnosticsSupportReport()
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
                        StudioKeyValueRow(label: "Account", value: companionManager.clickyLaunchAuthStatusLabel)
                        StudioKeyValueRow(label: "Entitlement", value: companionManager.clickyLaunchEntitlementStatusLabel)
                        StudioKeyValueRow(label: "Trial", value: companionManager.clickyLaunchTrialStatusLabel)
                        StudioKeyValueRow(label: "Checkout", value: companionManager.clickyLaunchBillingStatusLabel)

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
        let storedLaunchSession = ClickyAuthSessionStore.load()
        var contextLines = [
            "Clicky Support Report",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "Support Mode: \(isSupportModeEnabled ? "Enabled" : "Disabled")",
            "App Auth: \(companionManager.clickyLaunchAuthStatusLabel)",
            "Entitlement: \(companionManager.clickyLaunchEntitlementStatusLabel)",
            "Trial: \(companionManager.clickyLaunchTrialStatusLabel)",
            "Checkout: \(companionManager.clickyLaunchBillingStatusLabel)",
            "Paywall: \(companionManager.isClickyLaunchPaywallActive ? "Active" : "Inactive")",
            "Speech Provider: \(companionManager.clickySpeechProviderMode.displayName)",
            "Resolved Output: \(companionManager.effectiveVoiceOutputDisplayName)",
            "OpenClaw Agent: \(companionManager.inferredOpenClawAgentIdentifier ?? "Not detected")",
            "Shell Trust: \(companionManager.clickyShellServerTrustLabel)",
            "Shell Freshness: \(companionManager.clickyShellServerFreshnessLabel)",
            "Session Binding: \(companionManager.clickyShellServerBindingLabel)",
        ]

        if let storedLaunchSession {
            contextLines.append("Stored Session: Present")
            contextLines.append("Stored User ID: \(storedLaunchSession.userID)")
            contextLines.append("Stored Grace Until: \(storedLaunchSession.entitlement.gracePeriodEndsAt ?? "None")")
            contextLines.append("Trial Activated At: \(storedLaunchSession.trial?.trialActivatedAt ?? "None")")
            contextLines.append("Welcome Delivered At: \(storedLaunchSession.trial?.welcomePromptDeliveredAt ?? "None")")
            contextLines.append("Last Credit Consumed At: \(storedLaunchSession.trial?.lastCreditConsumedAt ?? "None")")
            contextLines.append("Paywall Activated At: \(storedLaunchSession.trial?.paywallActivatedAt ?? "None")")
        } else {
            contextLines.append("Stored Session: Missing")
        }

        if let shellStatusSummary = companionManager.clickyShellServerStatusSummary,
           !shellStatusSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextLines.append("")
            contextLines.append("Raw Shell Summary")
            contextLines.append(shellStatusSummary)
        }

        contextLines.append("")
        contextLines.append("Diagnostics Entries: \(ClickyDiagnosticsStore.shared.entries.count)")
        contextLines.append("")
        contextLines.append("Recent Logs")
        contextLines.append(ClickyDiagnosticsStore.shared.formattedRecentLogText(limit: 160))

        return ClickyLogger.redactForDiagnostics(contextLines.joined(separator: "\n"))
    }

    private var launchAccessGuidanceText: String {
        if companionManager.requiresLaunchRepurchaseForCompanionUse {
            return "This account no longer has an active launch entitlement. New assisted turns stay locked until you buy the launch pass again, or restore access if this looks wrong."
        }

        if companionManager.requiresLaunchEntitlementRefreshForCompanionUse {
            return "Your cached unlock grace has expired. Run Refresh Access before starting a new assisted turn so Clicky can confirm your entitlement."
        }

        switch companionManager.clickyLaunchAuthState {
        case .signedOut:
            return "Sign in before you buy or restore access. Once you are signed in, Clicky can sync your purchase and keep the unlock state durable across reinstalls."
        case .restoring, .signingIn:
            return "Clicky is syncing your launch access state right now. Once that settles, buy, restore, and refresh will all use the same backend-authoritative path."
        case .failed(let message):
            return message
        case .signedIn:
            break
        }

        if companionManager.isClickyLaunchPaywallActive {
            return "You already got to try the real screen-aware companion flow with a limited number of assisted turns. New assisted turns are now locked until you buy the launch pass or restore an existing purchase. Refresh Access is the lightweight resync path after checkout."
        }

        switch companionManager.clickyLaunchTrialState {
        case .unlocked:
            return "Clicky is unlocked on this Mac. Use Refresh Access after a purchase callback if the entitlement looks stale, or Restore Access when you are returning on a reinstall or another Mac."
        case .active(let remainingCredits):
            return "You are in the launch trial with \(remainingCredits) credits left. Credits only decrement after real assisted turns, never during onboarding, restore, or purchase flow."
        case .armed:
            return "You have one free turn left before the paywall. After that, new assisted turns lock until you buy or restore access."
        case .inactive:
            return "Finish onboarding and make your first real companion turn to activate the launch trial. Technical simulation controls stay tucked away in Support mode."
        case .paywalled:
            return "The paywall is active. You already tried the limited launch experience; what is locked now is new assisted turns. Buy the launch pass to unlock Clicky now, or restore access if this account already owns it."
        case .failed(let message):
            return message
        }
    }

    private var launchAccessPrimaryStatus: (label: String, tone: StudioStatusTone) {
        if companionManager.requiresLaunchRepurchaseForCompanionUse {
            return ("Purchase required", .warning)
        }

        if companionManager.requiresLaunchEntitlementRefreshForCompanionUse {
            return ("Refresh required", .warning)
        }

        switch companionManager.clickyLaunchAuthState {
        case .signedOut:
            return ("Sign-in required", .info)
        case .restoring, .signingIn:
            return ("Syncing access", .info)
        case .failed:
            return ("Access issue", .warning)
        case .signedIn:
            break
        }

        if companionManager.isClickyLaunchPaywallActive {
            return ("Locked", .warning)
        }

        switch companionManager.clickyLaunchTrialState {
        case .unlocked:
            return ("Unlocked", .success)
        case .active:
            return ("Trial active", .warning)
        case .armed:
            return ("Paywall next", .warning)
        case .inactive:
            return ("Trial ready", .info)
        case .paywalled:
            return ("Locked", .warning)
        case .failed:
            return ("Access issue", .warning)
        }
    }

    private var secondaryLaunchAccessStatus: (label: String, tone: StudioStatusTone)? {
        if companionManager.requiresLaunchRepurchaseForCompanionUse {
            return ("Entitlement inactive", .warning)
        }

        if companionManager.requiresLaunchEntitlementRefreshForCompanionUse {
            return ("Grace expired", .warning)
        }

        switch companionManager.clickyLaunchTrialState {
        case .active(let remainingCredits):
            return ("\(remainingCredits) credits left", .info)
        case .unlocked:
            return ("Restore available", .neutral)
        case .armed:
            return ("Buy before next turn", .warning)
        case .inactive, .paywalled, .failed:
            return nil
        }
    }

    private var isLaunchAccessSyncing: Bool {
        switch companionManager.clickyLaunchAuthState {
        case .restoring, .signingIn:
            return true
        case .signedOut, .signedIn, .failed:
            break
        }

        switch companionManager.clickyLaunchBillingState {
        case .openingCheckout, .waitingForCompletion:
            return true
        case .idle, .canceled, .completed, .failed:
            return false
        }
    }

    private var canStartLaunchSignIn: Bool {
        switch companionManager.clickyLaunchAuthState {
        case .signedOut, .failed:
            return true
        case .restoring, .signingIn, .signedIn:
            return false
        }
    }

    private var canSignOutLaunchSession: Bool {
        switch companionManager.clickyLaunchAuthState {
        case .signedIn, .failed:
            return true
        case .signedOut, .restoring, .signingIn:
            return false
        }
    }

    private var canStartLaunchCheckout: Bool {
        guard companionManager.isClickyLaunchSignedIn else {
            return false
        }

        guard !isLaunchAccessSyncing else {
            return false
        }

        switch companionManager.clickyLaunchTrialState {
        case .unlocked:
            return false
        case .inactive, .active, .armed, .paywalled, .failed:
            return true
        }
    }

    private var canRestoreLaunchAccess: Bool {
        companionManager.isClickyLaunchSignedIn && !isLaunchAccessSyncing
    }

    private var canRefreshLaunchAccess: Bool {
        companionManager.isClickyLaunchSignedIn && !isLaunchAccessSyncing
    }

    private func copyDiagnosticsSupportReport() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnosticsSupportReportText, forType: .string)
        ClickyLogger.notice(.ui, "Copied diagnostics support report")
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
            ClickyLogger.notice(.ui, "Exported diagnostics support report")
        } catch {
            ClickyLogger.error(.ui, "Failed to export diagnostics support report error=\(error.localizedDescription)")
            NSSound.beep()
        }
    }

    private func supportActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        neutralStudioButton(title: title, systemImage: systemImage, action: action)
    }

    private func launchAccessButton(
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        neutralStudioButton(title: title, systemImage: systemImage, isEnabled: isEnabled, action: action)
    }

    private func launchAccessPrimaryButton(
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
            }
            .foregroundColor(isEnabled ? .white : Color.white.opacity(0.45))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .modifier(StudioProminentActionButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
        .pointerCursor(isEnabled: isEnabled)
    }

    private func neutralStudioButton(
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
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
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .modifier(StudioActionButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
        .pointerCursor(isEnabled: isEnabled)
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
        let cardTheme = theme.contentSurfaceTheme

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(subtitle)
                    .font(ClickyTypography.mono(size: 12, weight: .medium))
                    .foregroundColor(cardTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Text(title)
                    .font(ClickyTypography.display(size: 30))
                    .foregroundColor(cardTheme.textPrimary)
            }

            content
        }
        .clickyTheme(cardTheme)
        .modifier(
            StudioReadablePanelModifier(
                cornerRadius: 28,
                fill: cardTheme.card.opacity(0.92),
                accent: cardTheme.secondary.opacity(0.14),
                border: cardTheme.border.opacity(0.50),
                padding: 22
            )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 16, y: 8)
    }
}

private struct StudioSidebarSignalRow: View {
    let title: String
    let value: String
    let tone: StudioStatusTone

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ClickyTypography.mono(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.9)

                Text(value)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            StudioStatusPill(label: tone.sidebarLabel, tone: tone)
        }
    }
}

private struct StudioOverviewMetricCard: View {
    @Environment(\.clickyTheme) private var theme

    let eyebrow: String
    let value: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(theme.textMuted)
                .tracking(1.0)

            Text(value)
                .font(ClickyTypography.section(size: 22))
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)

            Text(detail)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(theme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .modifier(StudioGlassPanelModifier(cornerRadius: 24, tint: accent.opacity(0.08), padding: 18))
    }
}

private struct StudioSubsection<Content: View>: View {
    @Environment(\.clickyTheme) private var theme

    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ClickyTypography.section(size: 20))
                    .foregroundColor(theme.textPrimary)

                Text(subtitle)
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StudioChapterDivider: View {
    @Environment(\.clickyTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.strokeSoft.opacity(0.8))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

private struct StudioWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            guard let window = view.window else { return }

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false

            window.toolbar = nil
            window.styleMask.insert(.fullSizeContentView)
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }

            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false

            window.toolbar = nil
            window.styleMask.insert(.fullSizeContentView)
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }

            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
        }
    }
}

private struct StudioWindowBackgroundClearStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.containerBackground(Color.clear, for: .window)
        } else {
            content
        }
    }
}

private struct StudioDetailBackdrop: View {
    let theme: ClickyTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.background.opacity(0.96),
                    theme.muted.opacity(0.92),
                    theme.background.opacity(0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    theme.glowA.opacity(0.18),
                    .clear,
                    theme.glowB.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)

            Circle()
                .fill(theme.glowA.opacity(0.20))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: -180, y: -110)

            Circle()
                .fill(theme.glowB.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 110)
                .offset(x: 240, y: -80)
        }
    }
}

private struct StudioActionButtonStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            content
                .foregroundColor(isEnabled ? theme.textPrimary : theme.textMuted)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.secondary.opacity(isEnabled ? 0.96 : 0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.border.opacity(isEnabled ? 0.78 : 0.46), lineWidth: 0.9)
                )
                .shadow(color: Color.black.opacity(isEnabled ? 0.06 : 0.02), radius: 8, y: 3)
        }
    }
}

private struct StudioProminentActionButtonStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            content
                .foregroundColor(isEnabled ? theme.accentForeground : theme.accentForeground.opacity(0.45))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isEnabled ? theme.accent : theme.accent.opacity(0.38))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
        }
    }
}

private struct StudioGlassPanelModifier: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    let cornerRadius: CGFloat
    let tint: Color
    let padding: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .background(
                Group {
                    if #available(macOS 26.0, *) {
                        shape
                            .fill(.clear)
                            .glassEffect(.regular.tint(tint), in: shape)
                    } else {
                        shape
                            .fill(theme.card.opacity(0.78))
                    }
                }
            )
            .overlay(
                shape
                    .stroke(theme.border.opacity(0.26), lineWidth: 0.85)
            )
    }
}

private struct StudioReadablePanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fill: Color
    let accent: Color
    let border: Color
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                StudioReadablePanelBackground(
                    cornerRadius: cornerRadius,
                    fill: fill,
                    accent: accent,
                    border: border
                )
            )
    }
}

private struct StudioReadablePanelBackground: View {
    let cornerRadius: CGFloat
    let fill: Color
    let accent: Color
    let border: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(fill)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        accent,
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            )
            .overlay(
                shape.stroke(border, lineWidth: 0.9)
            )
    }
}

private enum StudioStatusTone {
    case neutral
    case success
    case warning
    case info
}

private extension StudioStatusTone {
    var sidebarLabel: String {
        switch self {
        case .neutral:
            return "CALM"
        case .success:
            return "READY"
        case .warning:
            return "WATCH"
        case .info:
            return "LIVE"
        }
    }
}

private extension CompanionVoiceState {
    var displayTitle: String {
        switch self {
        case .idle:
            return "Idle"
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
}

private struct StudioStatusPill: View {
    @Environment(\.clickyTheme) private var theme

    let label: String
    let tone: StudioStatusTone

    var body: some View {
        let shape = Capsule(style: .continuous)

        Group {
            if #available(macOS 26.0, *) {
                Text(label)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundStyle(foregroundColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(glassStyle, in: shape)
                    .fixedSize()
            } else {
                Text(label)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(foregroundColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        shape
                            .fill(backgroundColor)
                    )
                    .overlay(
                        shape
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .fixedSize()
            }
        }
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

    @available(macOS 26.0, *)
    private var glassStyle: Glass {
        switch tone {
        case .neutral:
            return .regular
        case .success:
            return .regular.tint(theme.success.opacity(0.22))
        case .warning:
            return .regular.tint(theme.warning.opacity(0.20))
        case .info:
            return .regular.tint(theme.accent.opacity(0.18))
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
                        .fill(theme.secondary.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.border.opacity(0.78), lineWidth: 1)
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
                        .fill(theme.secondary.opacity(0.9))
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
                        .fill(theme.secondary.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.border.opacity(0.78), lineWidth: 1)
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
                    .fill(theme.secondary.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.border.opacity(0.78), lineWidth: 1)
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
                    .fill(theme.secondary.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.border.opacity(0.78), lineWidth: 1)
            )
        }
    }
}
