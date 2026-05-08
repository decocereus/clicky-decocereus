//
//  CompanionStudioCompanionPersonalizeCard.swift
//  leanring-buddy
//
//  Personalization controls for the Companion Studio scene.
//

import SwiftUI

struct CompanionStudioCompanionPersonalizeCard: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @Binding var isSupportModeEnabled: Bool
    @Binding var isPersonaPopoverPresented: Bool
    @Binding var isVoicePopoverPresented: Bool
    @Binding var isThemePopoverPresented: Bool
    @Binding var isCursorPopoverPresented: Bool
    @Binding var isProviderPanelExpanded: Bool
    @Binding var isAdvancedToneExpanded: Bool

    @Environment(\.clickyTheme) private var theme
    private let palette = CompanionStudioScalaPalette()

    init(
        companionManager: CompanionManager,
        isSupportModeEnabled: Binding<Bool>,
        isPersonaPopoverPresented: Binding<Bool>,
        isVoicePopoverPresented: Binding<Bool>,
        isThemePopoverPresented: Binding<Bool>,
        isCursorPopoverPresented: Binding<Bool>,
        isProviderPanelExpanded: Binding<Bool>,
        isAdvancedToneExpanded: Binding<Bool>
    ) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _isSupportModeEnabled = isSupportModeEnabled
        _isPersonaPopoverPresented = isPersonaPopoverPresented
        _isVoicePopoverPresented = isVoicePopoverPresented
        _isThemePopoverPresented = isThemePopoverPresented
        _isCursorPopoverPresented = isCursorPopoverPresented
        _isProviderPanelExpanded = isProviderPanelExpanded
        _isAdvancedToneExpanded = isAdvancedToneExpanded
    }

    private var selectedAgentBackend: CompanionAgentBackend {
        preferences.selectedAgentBackend
    }

    var body: some View {
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
                    primaryControls
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    styleControls
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
    }

    private var primaryControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            CompanionStudioPreferenceBlock(
                title: "Assistant mode",
                subtitle: "Choose whether Clicky replies through Claude, Codex on this Mac, or your OpenClaw setup.",
                content: AnyView(
                    HStack(spacing: 10) {
                        assistantModeButton(
                            title: "Claude",
                            isSelected: selectedAgentBackend == .claude
                        ) {
                            companionManager.settingsMutationCoordinator.setSelectedBackend(.claude)
                        }

                        assistantModeButton(
                            title: "Codex",
                            isSelected: selectedAgentBackend == .codex
                        ) {
                            companionManager.settingsMutationCoordinator.setSelectedBackend(.codex)
                        }

                        assistantModeButton(
                            title: "OpenClaw",
                            isSelected: selectedAgentBackend == .openClaw
                        ) {
                            companionManager.settingsMutationCoordinator.setSelectedBackend(.openClaw)
                        }
                    }
                )
            )

            if selectedAgentBackend == .codex {
                CompanionStudioPreferenceBlock(
                    title: "Codex on this Mac",
                    subtitle: "Clicky uses your local Codex install directly, keeping the interaction simple and fully inside Clicky.",
                    content: AnyView(
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No extra thread or project setup is needed here anymore. Once Codex is installed and signed in, Clicky can route answers through it like any other backend.")
                                .font(.caption)
                                .foregroundColor(palette.cardSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 8) {
                                CompanionStudioGlassChip(text: "Local runtime")
                                CompanionStudioGlassChip(text: "ChatGPT subscription")
                            }
                        }
                    )
                )
            }

            CompanionStudioPreferenceRow(
                title: "Pointer guidance",
                subtitle: "Let Clicky point to things on screen when that makes the answer easier to follow.",
                control: AnyView(
                    CompanionStudioPointerGuidanceToggle(
                        preferences: preferences,
                        onSetClickyCursorEnabled: companionManager.surfaceLifecycleCoordinator.setCursorEnabled,
                        theme: theme
                    )
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
    }

    private var styleControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current style")
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(preferences.clickyPersonaPreset.definition.summary)
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
                    HStack(spacing: 12) {
                        themePresetButton
                        cursorPresetButton
                    }
                    providerButton
                }

                VStack(spacing: 12) {
                    personaPresetButton
                    voicePresetButton
                    themePresetButton
                    cursorPresetButton
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
                CompanionStudioAdvancedToneEditor(
                    preferences: preferences,
                    palette: palette
                )
            }
        }
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
                value: preferences.clickyVoicePreset.displayName,
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
                value: preferences.clickyPersonaPreset.definition.displayName,
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
                value: preferences.clickyThemePreset.displayName,
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

    private var cursorPresetButton: some View {
        Button {
            isCursorPopoverPresented.toggle()
        } label: {
            CompanionStudioMiniMetric(
                title: "Cursor",
                value: preferences.clickyCursorStyle.displayName,
                allowExpansion: true
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .popover(isPresented: $isCursorPopoverPresented, arrowEdge: .bottom) {
            CompanionStudioCursorPresetPopover(companionManager: companionManager)
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
                    value: preferences.clickySpeechProviderMode.displayName,
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
}
