//
//  CompanionStudioNextView.swift
//  leanring-buddy
//
//  Parallel replacement Studio root with top tabs and scene-by-scene rebuilds.
//

import AppKit
import SwiftUI

private enum CompanionStudioNextSection: String, CaseIterable, Identifiable, Hashable {
    case companion
    case profile
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .companion:
            return "Companion"
        case .profile:
            return "Profile"
        case .support:
            return "Support"
        }
    }

    var subtitle: String {
        switch self {
        case .companion:
            return "Daily shell controls"
        case .profile:
            return "Account, access, and app"
        case .support:
            return "Diagnostics and backstage tools"
        }
    }

    var systemImage: String {
        switch self {
        case .companion:
            return "sparkles"
        case .profile:
            return "person.crop.circle"
        case .support:
            return "stethoscope"
        }
    }
}

struct CompanionStudioNextView: View {
    @ObservedObject var companionManager: CompanionManager

    @AppStorage("clickySupportModeEnabled") private var isSupportModeEnabled = false
    @State private var selection: CompanionStudioNextSection = .companion

    private let palette = CompanionStudioScalaPalette()

    private var theme: ClickyTheme {
        companionManager.activeClickyTheme
    }

    private var availableSections: [CompanionStudioNextSection] {
        CompanionStudioNextSection.allCases.filter { section in
            if section == .support {
                return isSupportModeEnabled
            }
            return true
        }
    }

    var body: some View {
        ZStack {
            CompanionStudioNextBackdrop(theme: theme, palette: palette)

            VStack(alignment: .leading, spacing: 18) {
                CompanionStudioWindowHeader(
                    theme: theme,
                    palette: palette,
                    sections: availableSections,
                    selection: $selection
                )

                CompanionStudioSceneShell {
                    currentScene
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 22)
            .padding(.bottom, 12)
            .background(outerShell)
        }
        .modifier(CompanionStudioNextWindowBackgroundClearStyle())
        .background(CompanionStudioNextWindowConfigurator())
        .onChange(of: isSupportModeEnabled) { _, newValue in
            if !newValue && selection == .support {
                selection = .companion
            }
        }
    }

    @ViewBuilder
    private var currentScene: some View {
        switch selection {
        case .companion:
            CompanionStudioCompanionScene(
                companionManager: companionManager,
                isSupportModeEnabled: $isSupportModeEnabled
            )
        case .profile:
            CompanionStudioProfileScene(companionManager: companionManager)
        case .support:
            CompanionStudioSupportScene(
                companionManager: companionManager,
                isSupportModeEnabled: $isSupportModeEnabled
            )
        }
    }

    @ViewBuilder
    private var outerShell: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

        if #available(macOS 26.0, *) {
            Color.clear
                .padding(12)
                .glassEffect(.clear, in: shape)
                .overlay(
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.10),
                                    palette.sage.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.10), radius: 18, y: 8)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.fill(Color.white.opacity(0.06))
                )
                .overlay(
                    shape.stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        }
    }
}

private struct CompanionStudioWindowHeader: View {
    let theme: ClickyTheme
    let palette: CompanionStudioScalaPalette
    let sections: [CompanionStudioNextSection]
    @Binding var selection: CompanionStudioNextSection

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("clicky")
                    .font(ClickyTypography.brand(size: 34))
                    .foregroundColor(palette.brandWordmark)

                Text("Studio")
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.shellSecondaryText)
                    .tracking(1.0)
            }

            Spacer(minLength: 0)

            topTabs
        }
    }

    @ViewBuilder
    private var topTabs: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    tabButtons
                }
            } else {
                tabButtons
            }
        }
    }

    private var tabButtons: some View {
        HStack(spacing: 14) {
            ForEach(sections) { section in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selection = section
                    }
                } label: {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .help(section.title)
                .modifier(CompanionStudioToolbarIconButtonModifier(isSelected: selection == section))
            }
        }
    }
}

private struct CompanionStudioSceneShell<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 920, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }
}

private struct CompanionStudioCompanionScene: View {
    @ObservedObject var companionManager: CompanionManager
    @Binding var isSupportModeEnabled: Bool

    @Environment(\.clickyTheme) private var theme
    @State private var isPersonaPopoverPresented = false
    @State private var isVoicePopoverPresented = false
    @State private var isThemePopoverPresented = false
    @State private var isProviderPanelExpanded = false
    @State private var isAdvancedToneExpanded = false
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            hero

            journeyCard

            personalizeCard

            HStack(alignment: .top, spacing: 18) {
                connectionSummaryCard
                accessSummaryCard
            }
        }
    }

    private var hero: some View {
        CompanionStudioReadableCard(
            eyebrow: "Companion",
            title: "Your Everyday Copilot"
        ) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Clicky stays out of your way until you need it, then listens, thinks, speaks back, and helps point you in the right direction.")
                    .font(ClickyTypography.body(size: 14))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 14) {
                        openPanelButton

                        Text("Open the floating companion when you want the fastest way to talk to Clicky.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        openPanelButton

                        Text("Open the floating companion when you want the fastest way to talk to Clicky.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                    }
                }

                CompanionStudioHairline()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) {
                        heroSignalColumn(
                            title: "Assistant",
                            value: companionManager.effectiveClickyPresentationName,
                            detail: companionManager.selectedAgentBackend == .claude ? "Cloud companion" : "OpenClaw companion"
                        )
                        heroSignalColumn(
                            title: "Voice",
                            value: companionManager.effectiveVoiceOutputDisplayName,
                            detail: companionManager.clickyVoicePreset.displayName
                        )
                        heroSignalColumn(
                            title: "Guidance",
                            value: companionManager.isClickyCursorEnabled ? "Pointer guidance on" : "Pointer guidance off",
                            detail: "Screen help when needed"
                        )
                    }

                    VStack(spacing: 12) {
                        heroSignalStack(
                            title: "Assistant",
                            value: companionManager.effectiveClickyPresentationName,
                            detail: companionManager.selectedAgentBackend == .claude ? "Cloud companion" : "OpenClaw companion"
                        )
                        heroSignalStack(
                            title: "Voice",
                            value: companionManager.effectiveVoiceOutputDisplayName,
                            detail: companionManager.clickyVoicePreset.displayName
                        )
                        heroSignalStack(
                            title: "Guidance",
                            value: companionManager.isClickyCursorEnabled ? "Pointer guidance on" : "Pointer guidance off",
                            detail: "Screen help when needed"
                        )
                    }
                }
            }
        }
    }

    private var openPanelButton: some View {
        Button {
            NotificationCenter.default.post(name: .clickyShowPanel, object: nil)
        } label: {
            Label("Open Companion Panel", systemImage: "sparkles")
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .frame(minWidth: 180)
        }
        .modifier(CompanionStudioPrimaryButtonModifier())
        .pointerCursor()
    }

    private func heroSignalColumn(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(value)
                .font(ClickyTypography.section(size: 22))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private func heroSignalStack(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(value)
                .font(ClickyTypography.body(size: 16, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(2)
                .truncationMode(.tail)
                .minimumScaleFactor(0.90)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardAccent.opacity(0.40))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }

    private var journeyCard: some View {
        CompanionStudioReadableCard(
            eyebrow: "Flow",
            title: "How A Clicky Moment Works"
        ) {
            HStack(alignment: .top, spacing: 14) {
                CompanionStudioJourneyStep(
                    step: "01",
                    title: "Hold the shortcut",
                    copy: "Clicky starts listening the moment you hold Control + Option."
                )
                CompanionStudioJourneyStep(
                    step: "02",
                    title: "Ask naturally",
                    copy: "Say what you want help with in plain language, without opening a settings page first."
                )
                CompanionStudioJourneyStep(
                    step: "03",
                    title: "Get a spoken answer",
                    copy: "Clicky replies in your selected voice and can point at things on screen when it helps."
                )
            }
        }
    }

    private var personalizeCard: some View {
        CompanionStudioReadableCard(
            eyebrow: "Personalize",
            title: "Change The Feel"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Make the two or three changes most people reach for first: how Clicky answers, whether it points things out on screen, and the style it uses.")
                    .font(ClickyTypography.body(size: 14))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        CompanionStudioPreferenceBlock(
                            title: "Assistant mode",
                            subtitle: "Choose whether Clicky replies through Claude or through your OpenClaw setup on this Mac.",
                            content: AnyView(
                                HStack(spacing: 10) {
                                    assistantModeButton(
                                        title: "Claude",
                                        isSelected: companionManager.selectedAgentBackend == .claude
                                    ) {
                                        companionManager.setSelectedAgentBackend(.claude)
                                    }

                                    assistantModeButton(
                                        title: "OpenClaw",
                                        isSelected: companionManager.selectedAgentBackend == .openClaw
                                    ) {
                                        companionManager.setSelectedAgentBackend(.openClaw)
                                    }
                                }
                            )
                        )

                        CompanionStudioPreferenceRow(
                            title: "Pointer guidance",
                            subtitle: "Let Clicky point to things on screen when that makes the answer easier to follow.",
                            control: AnyView(
                                Toggle(
                                    "Show pointer guidance on screen",
                                    isOn: Binding(
                                        get: { companionManager.isClickyCursorEnabled },
                                        set: { companionManager.setClickyCursorEnabled($0) }
                                    )
                                )
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .tint(theme.primary)
                            )
                        )

                        CompanionStudioPreferenceRow(
                            title: "Support tools",
                            subtitle: "Keep the backstage tools hidden unless you are intentionally troubleshooting.",
                            control: AnyView(
                                Toggle("Enable support mode", isOn: $isSupportModeEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .tint(theme.accent)
                            )
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Current style")
                            .font(ClickyTypography.mono(size: 11, weight: .semibold))
                            .foregroundColor(palette.cardSecondaryText)
                            .tracking(0.8)

                        Text(companionManager.activeClickyPersonaSummary)
                            .font(ClickyTypography.body(size: 14, weight: .medium))
                            .foregroundColor(palette.cardPrimaryText)
                            .lineLimit(3)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: 72, alignment: .topLeading)

                        ViewThatFits(in: .horizontal) {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    personaPresetButton
                                    voicePresetButton
                                }
                                themePresetButton
                                providerButton
                            }

                            VStack(spacing: 12) {
                                personaPresetButton
                                voicePresetButton
                                themePresetButton
                                providerButton
                            }
                        }

                        if isProviderPanelExpanded {
                            CompanionStudioProviderPopover(companionManager: companionManager)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                isAdvancedToneExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isAdvancedToneExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Advanced tone notes")
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                            }
                            .foregroundColor(palette.cardPrimaryText)
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()

                        if isAdvancedToneExpanded {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Add any custom instructions you want Clicky to follow when it speaks.")
                                    .font(.caption)
                                    .foregroundColor(palette.cardSecondaryText)

                                TextEditor(text: $companionManager.clickyPersonaToneInstructions)
                                    .font(.system(size: 13))
                                    .frame(minHeight: 92)
                                    .scrollContentBackground(.hidden)
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(palette.cardAccent.opacity(0.38))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(palette.cardBorder.opacity(0.38), lineWidth: 0.8)
                                            )
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
    }

    private func assistantModeButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .modifier(CompanionStudioModeButtonModifier(isSelected: isSelected))
        .pointerCursor()
    }

    private var voicePresetButton: some View {
        Button {
            isVoicePopoverPresented.toggle()
        } label: {
            CompanionStudioMiniMetric(
                title: "Voice",
                value: companionManager.clickyVoicePreset.displayName,
                allowExpansion: true
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .popover(isPresented: $isVoicePopoverPresented, arrowEdge: .bottom) {
            CompanionStudioVoicePresetPopover(companionManager: companionManager)
                .frame(width: 360, height: 300)
        }
    }

    private var personaPresetButton: some View {
        Button {
            isPersonaPopoverPresented.toggle()
        } label: {
            CompanionStudioMiniMetric(
                title: "Persona",
                value: companionManager.clickyPersonaPreset.definition.displayName,
                allowExpansion: true
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .popover(isPresented: $isPersonaPopoverPresented, arrowEdge: .bottom) {
            CompanionStudioPersonaPresetPopover(companionManager: companionManager)
                .frame(width: 360, height: 340)
        }
    }

    private var themePresetButton: some View {
        Button {
            isThemePopoverPresented.toggle()
        } label: {
            CompanionStudioMiniMetric(
                title: "Theme",
                value: companionManager.clickyThemePreset.displayName,
                allowExpansion: true
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .popover(isPresented: $isThemePopoverPresented, arrowEdge: .bottom) {
            CompanionStudioThemePresetPopover(companionManager: companionManager)
                .frame(width: 360, height: 300)
        }
    }

    private var providerButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                isProviderPanelExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                CompanionStudioMiniMetric(
                    title: "Provider",
                    value: companionManager.clickySpeechProviderMode.displayName,
                    allowExpansion: true
                )

                HStack(spacing: 6) {
                    Image(systemName: isProviderPanelExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isProviderPanelExpanded ? "Hide voice library" : "Show voice library")
                        .font(.caption)
                        .foregroundColor(palette.cardSecondaryText)
                }
                .padding(.leading, 4)
            }
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private var connectionSummaryCard: some View {
        CompanionStudioReadableCard(
            eyebrow: "Connection",
            title: "Assistant Connection"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text(connectionSummaryCopy)
                    .font(ClickyTypography.body(size: 14))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    CompanionStudioGlassChip(text: connectionStatusChip)
                    CompanionStudioGlassChip(text: companionManager.isOpenClawGatewayRemote ? "Remote gateway" : "Local gateway")
                }

                VStack(spacing: 12) {
                    CompanionStudioKeyValueRow(label: "Assistant", value: companionManager.effectiveClickyPresentationName)
                    CompanionStudioKeyValueRow(label: "Gateway", value: companionManager.isOpenClawGatewayRemote ? "Remote OpenClaw" : "This Mac")
                }

                Button {
                    companionManager.testOpenClawConnection()
                } label: {
                    Label("Check Connection", systemImage: "bolt.horizontal.circle")
                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                        .frame(minWidth: 170)
                }
                .modifier(CompanionStudioPrimaryButtonModifier())
                .pointerCursor()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var accessSummaryCard: some View {
        CompanionStudioReadableCard(
            eyebrow: "Access",
            title: "Your Access"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                accessAccountHeader

                if companionManager.hasUnlimitedClickyLaunchAccess {
                    CompanionStudioAccessCelebrationCard()
                } else {
                    Text(accessSummaryCopy)
                        .font(ClickyTypography.body(size: 14))
                        .foregroundColor(palette.cardSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    ForEach(accessChipLabels, id: \.self) { label in
                        CompanionStudioGlassChip(text: label)
                    }
                }

                VStack(spacing: 12) {
                    CompanionStudioKeyValueRow(label: "Account", value: companionManager.clickyLaunchDisplayName)

                    if !companionManager.hasUnlimitedClickyLaunchAccess {
                        if companionManager.isClickyLaunchSignedIn {
                            CompanionStudioKeyValueRow(label: "Access", value: accessStatusLine)
                        }

                        if showsTrialRow {
                            CompanionStudioKeyValueRow(label: "Trial", value: companionManager.clickyLaunchTrialStatusLabel)
                        }

                        if showsCheckoutRow {
                            CompanionStudioKeyValueRow(label: "Checkout", value: companionManager.clickyLaunchBillingStatusLabel)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    accessPrimaryAction
                    accessSecondaryActions
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task(id: accessBackgroundSyncToken) {
            guard companionManager.isClickyLaunchSignedIn else {
                return
            }

            companionManager.refreshClickyLaunchEntitlementQuietlyIfNeeded(
                reason: "studio-access-card",
                minimumInterval: 15
            )
        }
    }

    private var connectionStatusChip: String {
        switch companionManager.openClawConnectionStatus {
        case .idle:
            return "Connection not checked yet"
        case .testing:
            return "Checking connection"
        case .connected:
            return "Connected"
        case .failed:
            return "Needs attention"
        }
    }

    private var connectionSummaryCopy: String {
        switch companionManager.openClawConnectionStatus {
        case .idle:
            return "Clicky is ready to connect through your chosen assistant path. Run a quick check any time you want to confirm everything is reachable."
        case .testing:
            return "Clicky is checking the connection right now."
        case .connected:
            return "Clicky can currently reach your assistant, so new conversations should go through without extra setup."
        case .failed:
            return "Clicky is having trouble reaching your assistant right now. A quick connection check can help you see whether anything needs attention."
        }
    }

    private var accessSummaryCopy: String {
        if companionManager.hasUnlimitedClickyLaunchAccess {
            return "Your subscription is live. Clicky is fully unlocked here, so you can talk to it as much as you want."
        }

        if companionManager.requiresLaunchSignInForCompanionUse {
            return "Sign in to start your Clicky trial and keep your access tied to your account."
        }

        if companionManager.isClickyLaunchPaywallActive {
            return "Your included taste is finished. Unlock Clicky to keep the companion with you across as many turns as you want."
        }

        if companionManager.clickyLaunchBillingStatusLabel == "Waiting for purchase" {
            return "Clicky is checking your purchase in the background so this Mac can unlock itself as soon as it lands."
        }

        return "Your account is in good shape, and Clicky is quietly keeping your access up to date on this Mac."
    }

    private var accessAccountHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            CompanionStudioAccessAvatar(
                initials: companionManager.clickyLaunchDisplayInitials,
                imageURL: companionManager.clickyLaunchProfileImageURL,
                palette: palette
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(companionManager.clickyLaunchDisplayName)
                    .font(ClickyTypography.section(size: 24))
                    .foregroundColor(palette.cardPrimaryText)
                    .lineLimit(1)

                Text(accessHeaderSubtitle)
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var accessHeaderSubtitle: String {
        if companionManager.hasUnlimitedClickyLaunchAccess {
            return "You’re fully unlocked on this Mac."
        }

        if companionManager.requiresLaunchSignInForCompanionUse {
            return "Sign in once to tie your trial and future access to your account."
        }

        if companionManager.isClickyLaunchPaywallActive {
            return "Your trial has wrapped, but this is where Clicky can unlock for good."
        }

        return "Clicky keeps this Mac in sync with your access in the background."
    }

    private var accessChipLabels: [String] {
        if companionManager.hasUnlimitedClickyLaunchAccess {
            return ["Subscription active", "Unlimited access"]
        }

        if companionManager.requiresLaunchSignInForCompanionUse {
            return ["Sign in required"]
        }

        if companionManager.isClickyLaunchPaywallActive {
            return ["Trial finished", "Unlock available"]
        }

        if companionManager.clickyLaunchBillingStatusLabel == "Waiting for purchase" {
            return ["Finishing purchase"]
        }

        return ["Ready on this Mac"]
    }

    private var accessStatusLine: String {
        if companionManager.isClickyLaunchPaywallActive {
            return "Needs unlock"
        }

        if companionManager.clickyLaunchBillingStatusLabel == "Waiting for purchase" {
            return "Checking purchase"
        }

        return "Ready to use"
    }

    private var showsTrialRow: Bool {
        !companionManager.hasUnlimitedClickyLaunchAccess
    }

    private var showsCheckoutRow: Bool {
        !companionManager.hasUnlimitedClickyLaunchAccess
            && companionManager.isClickyLaunchSignedIn
            && companionManager.clickyLaunchBillingStatusLabel != "Idle"
    }

    private var accessBackgroundSyncToken: String {
        [
            companionManager.clickyLaunchAuthStatusLabel,
            companionManager.clickyLaunchBillingStatusLabel,
            companionManager.clickyLaunchTrialStatusLabel
        ].joined(separator: "|")
    }

    @ViewBuilder
    private var accessPrimaryAction: some View {
        if companionManager.requiresLaunchSignInForCompanionUse {
            Button {
                companionManager.startClickyLaunchSignIn()
            } label: {
                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 150)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        } else if companionManager.isClickyLaunchPaywallActive {
            Button {
                companionManager.startClickyLaunchCheckout()
            } label: {
                Label("Unlock Clicky", systemImage: "creditcard")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 150)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        }
    }

    @ViewBuilder
    private var accessSecondaryActions: some View {
        if companionManager.isClickyLaunchSignedIn {
            Button {
                companionManager.signOutClickyLaunchSession()
            } label: {
                Text("Sign Out")
                    .font(ClickyTypography.body(size: 12, weight: .semibold))
                    .foregroundColor(palette.cardSecondaryText)
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
    }

}

private struct CompanionStudioProfileScene: View {
    @ObservedObject var companionManager: CompanionManager
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CompanionStudioReadableCard(
                eyebrow: "Profile",
                title: "Your Account"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This page keeps your account, access, and app maintenance in one calmer place instead of mixing them into the daily companion experience.")
                        .font(ClickyTypography.body(size: 14))
                        .foregroundColor(palette.cardSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        CompanionStudioGlassChip(text: companionManager.clickyLaunchAuthStatusLabel)
                        CompanionStudioGlassChip(text: companionManager.clickyLaunchEntitlementStatusLabel)
                        CompanionStudioGlassChip(text: companionManager.clickyLaunchBillingStatusLabel)
                    }
                }
            }

            HStack(alignment: .top, spacing: 18) {
                CompanionStudioReadableCard(
                    eyebrow: "Account",
                    title: "Your Access"
                ) {
                    VStack(spacing: 12) {
                        CompanionStudioKeyValueRow(label: "Signed in as", value: companionManager.clickyLaunchAuthStatusLabel)
                        CompanionStudioKeyValueRow(label: "Access", value: companionManager.clickyLaunchEntitlementStatusLabel)
                        CompanionStudioKeyValueRow(label: "Trial", value: companionManager.clickyLaunchTrialStatusLabel)
                        CompanionStudioKeyValueRow(label: "Checkout", value: companionManager.clickyLaunchBillingStatusLabel)
                    }
                }

                CompanionStudioReadableCard(
                    eyebrow: "App",
                    title: "Keep Clicky Up To Date"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use this page when you want to check your access, restore a purchase, or make sure Clicky is up to date.")
                            .font(.body)
                            .foregroundColor(palette.cardPrimaryText)

                        Button {
                            NotificationCenter.default.post(name: .clickyCheckForUpdates, object: nil)
                        } label: {
                            Label("Check for Updates", systemImage: "arrow.down.circle")
                                .font(ClickyTypography.body(size: 13, weight: .semibold))
                                .frame(minWidth: 180)
                        }
                        .modifier(CompanionStudioPrimaryButtonModifier())
                        .pointerCursor()

                        Text("App updates, account state, and subscription access live here so the companion surface can stay focused on helping you get work done.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct CompanionStudioSupportScene: View {
    @ObservedObject var companionManager: CompanionManager
    @Binding var isSupportModeEnabled: Bool
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CompanionStudioReadableCard(
                eyebrow: "Support",
                title: "Backstage Tools"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This page is for troubleshooting and support work. It stays separate so the rest of Studio can stay calm and user-facing.")
                        .font(ClickyTypography.body(size: 14))
                        .foregroundColor(palette.cardSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle("Show support tools", isOn: $isSupportModeEnabled)
                        .toggleStyle(.switch)
                }
            }

            HStack(alignment: .top, spacing: 18) {
                CompanionStudioReadableCard(
                    eyebrow: "Current State",
                    title: "What Clicky Is Reporting"
                ) {
                    VStack(spacing: 12) {
                        CompanionStudioKeyValueRow(label: "Speech", value: companionManager.effectiveVoiceOutputDisplayName)
                        CompanionStudioKeyValueRow(label: "Bridge", value: companionManager.clickyOpenClawPluginStatusLabel)
                    }
                }

                CompanionStudioReadableCard(
                    eyebrow: "When To Use This",
                    title: "What Support Mode Is For"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use this when you are helping someone restore access, checking a connection issue, or confirming what Clicky is currently using behind the scenes.")
                            .font(.body)
                            .foregroundColor(palette.cardPrimaryText)

                        Text(companionManager.speechFallbackSummary ?? "No voice fallback is active right now.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct CompanionStudioProviderPopover: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var isImportVoiceExpanded = false

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice provider")
                .font(ClickyTypography.section(size: 24))
                .foregroundColor(palette.cardPrimaryText)

            Text("Choose the voice engine Clicky should use, then pick or import the voice you want.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                providerModeButton(
                    title: "System",
                    isSelected: companionManager.clickySpeechProviderMode == .system
                ) {
                    companionManager.clickySpeechProviderMode = .system
                }

                providerModeButton(
                    title: "ElevenLabs",
                    isSelected: companionManager.clickySpeechProviderMode == .elevenLabsBYO
                ) {
                    companionManager.clickySpeechProviderMode = .elevenLabsBYO
                    if companionManager.hasStoredElevenLabsAPIKey && companionManager.elevenLabsAvailableVoices.isEmpty {
                        companionManager.refreshElevenLabsVoices()
                    }
                }
            }

            if companionManager.clickySpeechProviderMode == .system {
                VStack(alignment: .leading, spacing: 10) {
                    Text("System speech is active on this Mac.")
                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                        .foregroundColor(palette.cardPrimaryText)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.cardAccent.opacity(0.40))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                        )
                )
                .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if !companionManager.hasStoredElevenLabsAPIKey {
                        Text("Add your ElevenLabs API key to unlock extra voices.")
                            .font(ClickyTypography.body(size: 13, weight: .semibold))
                            .foregroundColor(palette.cardPrimaryText)

                        SecureField("ElevenLabs API key", text: $companionManager.elevenLabsAPIKeyDraft)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            companionManager.saveElevenLabsAPIKey()
                        } label: {
                            Label("Save API Key", systemImage: "key.horizontal")
                                .font(ClickyTypography.body(size: 13, weight: .semibold))
                        }
                        .modifier(CompanionStudioPrimaryButtonModifier())
                        .pointerCursor()
                    } else {
                        Text("Loaded voices")
                            .font(ClickyTypography.mono(size: 10, weight: .semibold))
                            .foregroundColor(palette.cardSecondaryText)

                        if companionManager.elevenLabsAvailableVoices.isEmpty {
                            Text(companionManager.elevenLabsStatusLabel)
                                .font(.caption)
                                .foregroundColor(palette.cardSecondaryText)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(companionManager.elevenLabsAvailableVoices) { voice in
                                        Button {
                                            companionManager.selectElevenLabsVoice(voice)
                                            companionManager.previewCurrentSpeechOutput()
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(voice.name)
                                                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                                                    Text(voice.displaySubtitle)
                                                        .font(.caption)
                                                        .foregroundColor(palette.cardSecondaryText)
                                                }

                                                Spacer()

                                                if companionManager.elevenLabsSelectedVoiceID == voice.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                }
                                            }
                                            .foregroundColor(palette.cardPrimaryText)
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(companionManager.elevenLabsSelectedVoiceID == voice.id ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .pointerCursor()
                                    }
                                }
                            }
                            .frame(minHeight: 220, maxHeight: 220)
                        }

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                isImportVoiceExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isImportVoiceExpanded ? "chevron.up.circle.fill" : "square.and.arrow.down")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(isImportVoiceExpanded ? "Hide voice ID import" : "Import a voice by ID")
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                            }
                            .foregroundColor(palette.cardPrimaryText)
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()

                        if isImportVoiceExpanded {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Voice ID", text: $companionManager.elevenLabsImportVoiceIDDraft)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    companionManager.importElevenLabsVoiceByID()
                                } label: {
                                    Label("Import Voice", systemImage: "square.and.arrow.down")
                                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                                }
                                .modifier(CompanionStudioModeButtonModifier(isSelected: false))
                                .pointerCursor()
                            }
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.cardAccent.opacity(0.40))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                        )
                )
                .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 24)
        .background(palette.cardBackground)
        .animation(nil, value: companionManager.clickySpeechProviderMode)
        .animation(nil, value: companionManager.elevenLabsSelectedVoiceID)
        .animation(nil, value: companionManager.elevenLabsAvailableVoices.count)
        .onAppear {
            if companionManager.clickySpeechProviderMode == .elevenLabsBYO &&
                companionManager.hasStoredElevenLabsAPIKey &&
                companionManager.elevenLabsAvailableVoices.isEmpty {
                companionManager.refreshElevenLabsVoices()
            }
        }
        .onChange(of: companionManager.clickySpeechProviderMode) { _, newValue in
            guard newValue == .elevenLabsBYO else { return }
            if companionManager.hasStoredElevenLabsAPIKey && companionManager.elevenLabsAvailableVoices.isEmpty {
                companionManager.refreshElevenLabsVoices()
            }
        }
    }

    private func providerModeButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .modifier(CompanionStudioModeButtonModifier(isSelected: isSelected))
        .pointerCursor()
    }
}

private struct CompanionStudioVoicePresetPopover: View {
    @ObservedObject var companionManager: CompanionManager

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Voice style")
                .font(ClickyTypography.section(size: 24))
                .foregroundColor(palette.cardPrimaryText)

            Text("Pick the delivery style that makes Clicky sound right to you.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ClickyVoicePreset.allCases) { preset in
                    Button {
                        companionManager.clickyVoicePreset = preset
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.displayName)
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                                Text(preset.summary)
                                    .font(.caption)
                                    .foregroundColor(palette.cardSecondaryText)
                            }

                            Spacer()

                            if companionManager.clickyVoicePreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(companionManager.clickyVoicePreset == preset ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(palette.cardBackground)
    }
}

private struct CompanionStudioPersonaPresetPopover: View {
    @ObservedObject var companionManager: CompanionManager

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Persona")
                .font(ClickyTypography.section(size: 24))
                .foregroundColor(palette.cardPrimaryText)

            Text("Choose the overall feeling Clicky should bring. Picking a persona also resets the default voice, theme, and cursor pairing for that style.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ClickyPersonaPreset.allCases) { preset in
                    Button {
                        companionManager.setClickyPersonaPreset(preset)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.definition.displayName)
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                                Text(preset.definition.summary)
                                    .font(.caption)
                                    .foregroundColor(palette.cardSecondaryText)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            if companionManager.clickyPersonaPreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(companionManager.clickyPersonaPreset == preset ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(palette.cardBackground)
    }
}

private struct CompanionStudioThemePresetPopover: View {
    @ObservedObject var companionManager: CompanionManager

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Theme")
                .font(ClickyTypography.section(size: 24))
                .foregroundColor(palette.cardPrimaryText)

            Text("Choose the overall look Clicky should use inside the app.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ClickyThemePreset.allCases) { preset in
                    Button {
                        companionManager.clickyThemePreset = preset
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.displayName)
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                                Text(preset == .dark ? "Moody and focused" : "Warm and airy")
                                    .font(.caption)
                                    .foregroundColor(palette.cardSecondaryText)
                            }

                            Spacer()

                            if companionManager.clickyThemePreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(companionManager.clickyThemePreset == preset ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(palette.cardBackground)
    }
}

private struct CompanionStudioAccessAvatar: View {
    let initials: String
    let imageURL: String
    let palette: CompanionStudioScalaPalette

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.sage.opacity(0.92),
                            palette.cardAccent.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let avatarURL = resolvedAvatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    fallbackInitials
                }
                .clipShape(Circle())
            } else {
                fallbackInitials
            }

            Circle()
                .stroke(palette.cardBorder.opacity(0.55), lineWidth: 1)
        }
        .frame(width: 56, height: 56)
    }

    private var resolvedAvatarURL: URL? {
        let trimmedURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            return nil
        }

        return URL(string: trimmedURL)
    }

    private var fallbackInitials: some View {
        Text(initials.isEmpty ? "CU" : initials)
            .font(ClickyTypography.mono(size: 18, weight: .semibold))
            .foregroundColor(palette.cardPrimaryText)
    }
}

private struct CompanionStudioAccessCelebrationCard: View {
    @State private var isAnimating = false

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.sage.opacity(0.88),
                                palette.cardAccent.opacity(0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.50), lineWidth: 1)
                    )

                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(palette.cardPrimaryText)
                    .scaleEffect(isAnimating ? 1.03 : 0.98)
            }
            .frame(width: 60, height: 60)
            .shadow(color: palette.sage.opacity(isAnimating ? 0.18 : 0.08), radius: isAnimating ? 14 : 8, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Subscription active")
                    .font(ClickyTypography.section(size: 22))
                    .foregroundColor(palette.cardPrimaryText)

                Text("You’ve bought full access, so Clicky is now yours to use however much you want.")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.cardAccent.opacity(0.36))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.42), lineWidth: 0.9)
                )
        )
        .onAppear {
            guard !isAnimating else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

private struct CompanionStudioNextBackdrop: View {
    let theme: ClickyTheme
    let palette: CompanionStudioScalaPalette

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                Color.clear
            } else {
                LinearGradient(
                    colors: [
                        palette.shellBackgroundTop.opacity(0.92),
                        palette.shellBackgroundMid.opacity(0.90),
                        palette.shellBackgroundBottom.opacity(0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct CompanionStudioReadableCard<Content: View>: View {
    let palette = CompanionStudioScalaPalette()

    let eyebrow: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardSecondaryText)
                    .tracking(1.0)

                Text(title)
                    .font(ClickyTypography.section(size: 30))
                    .foregroundColor(palette.cardPrimaryText)
            }

            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(palette.cardBackground)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            palette.cardAccent.opacity(0.12),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.72), lineWidth: 0.9)
                )
        )
    }
}

private struct CompanionStudioGlassChip: View {
    let text: String
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        let shape = Capsule(style: .continuous)

        Group {
            if #available(macOS 26.0, *) {
                Text(text)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassEffect(.regular, in: shape)
            } else {
                Text(text)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(shape.fill(.ultraThinMaterial))
            }
        }
        .fixedSize()
    }
}

private struct CompanionStudioJourneyStep: View {
    let step: String
    let title: String
    let copy: String

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(step)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.cardPrimaryText)
                    )

                Text(title)
                    .font(ClickyTypography.body(size: 14, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
            }

            Text(copy)
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardAccent.opacity(0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.48), lineWidth: 0.8)
                )
        )
    }
}

private struct CompanionStudioPreferenceRow: View {
    let title: String
    let subtitle: String
    let control: AnyView

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ClickyTypography.body(size: 14, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)

                Text(subtitle)
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            control
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardAccent.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }
}

private struct CompanionStudioPreferenceBlock: View {
    let title: String
    let subtitle: String
    let content: AnyView

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)

            Text(subtitle)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardAccent.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }
}

private struct CompanionStudioMiniMetric: View {
    let title: String
    let value: String
    var allowExpansion: Bool = false

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(value)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: allowExpansion ? .infinity : nil, alignment: .leading)
        .frame(minWidth: 0, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardAccent.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }
}

private struct CompanionStudioKeyValueRow: View {
    let label: String
    let value: String
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
    }
}

private struct CompanionStudioPrimaryButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.primary.opacity(0.10))
                )
        }
    }
}

private struct CompanionStudioModeButtonModifier: ViewModifier {
    private let palette = CompanionStudioScalaPalette()
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if isSelected {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
            } else {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
            }
        } else {
            content
                .foregroundColor(isSelected ? .white : palette.cardPrimaryText)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? palette.sage : palette.cardAccent.opacity(0.50))
                )
        }
    }
}

private struct CompanionStudioHairline: View {
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        palette.cardBorder.opacity(0.65),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

private struct CompanionStudioToolbarIconButtonModifier: ViewModifier {
    private let palette = CompanionStudioScalaPalette()
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        if #available(macOS 26.0, *) {
            if isSelected {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .background(
                        shape
                            .fill(palette.cardBackground.opacity(0.94))
                    )
                    .overlay(
                        shape
                            .stroke(Color.white.opacity(0.30), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 8, y: 3)
            } else {
                content
                    .foregroundColor(Color.white.opacity(0.88))
                    .background(
                        shape
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        shape
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                    )
            }
        } else {
            content
                .foregroundColor(isSelected ? palette.cardPrimaryText : Color.white.opacity(0.88))
                .background(
                    shape
                        .fill(isSelected ? palette.cardBackground.opacity(0.94) : Color.white.opacity(0.05))
                )
                .overlay(
                    shape
                        .stroke(isSelected ? Color.white.opacity(0.28) : Color.white.opacity(0.08), lineWidth: 0.6)
                )
        }
    }
}

private struct CompanionStudioScalaPalette {
    let shellBackgroundTop = Color(hex: "#4C4958")
    let shellBackgroundMid = Color(hex: "#45414F")
    let shellBackgroundBottom = Color(hex: "#3D3A47")

    let shellTint = Color(hex: "#F5F2EE")
    let shellPrimaryText = Color(hex: "#FAF8F5")
    let shellSecondaryText = Color(hex: "#D7D1CB")

    let cardBackground = Color(hex: "#FAF8F5")
    let cardPrimaryText = Color(hex: "#1A1A1A")
    let cardSecondaryText = Color(hex: "#6B6B6B")
    let cardBorder = Color(hex: "#E3DBD2")
    let cardAccent = Color(hex: "#F5F2EE")

    let lavender = Color(hex: "#9B8FBF")
    let sage = Color(hex: "#7A9B8A")
    let sageText = Color(hex: "#AFC3B7")
    let brandWordmark = Color(hex: "#D9E4DA")
}

private struct CompanionStudioNextWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            guard let window = view.window else { return }

            positionTrafficLights(for: window)
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
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }

            positionTrafficLights(for: window)
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
        }
    }

    private func positionTrafficLights(for window: NSWindow) {
        guard
            let closeButton = window.standardWindowButton(.closeButton),
            let miniButton = window.standardWindowButton(.miniaturizeButton),
            let zoomButton = window.standardWindowButton(.zoomButton)
        else {
            return
        }

        let targetY: CGFloat = 14
        let startX: CGFloat = 14
        let spacing: CGFloat = 6

        closeButton.setFrameOrigin(NSPoint(x: startX, y: targetY))
        miniButton.setFrameOrigin(NSPoint(x: startX + closeButton.frame.width + spacing, y: targetY))
        zoomButton.setFrameOrigin(NSPoint(x: startX + closeButton.frame.width + miniButton.frame.width + (spacing * 2), y: targetY))
    }
}

private struct CompanionStudioNextWindowBackgroundClearStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.containerBackground(Color.clear, for: .window)
        } else {
            content
        }
    }
}
