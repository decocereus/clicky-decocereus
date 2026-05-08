//
//  CompanionStudioPopovers.swift
//  leanring-buddy
//
//  Popover surfaces for provider, voice, persona, theme, and cursor settings.
//

import SwiftUI

struct CompanionStudioProviderPopover: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var speechProviderController: ClickySpeechProviderController
    @State private var isImportVoiceExpanded = false

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _speechProviderController = ObservedObject(wrappedValue: companionManager.speechProviderController)
    }

    private var speechFallbackSummary: String? {
        if let lastSpeechFallbackMessage = speechProviderController.lastSpeechFallbackMessage {
            return lastSpeechFallbackMessage
        }

        guard preferences.clickySpeechProviderMode == .elevenLabsBYO else {
            return nil
        }

        if !companionManager.speechProviderCoordinator.hasStoredElevenLabsAPIKey {
            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Add your ElevenLabs API key. Clicky stores it only in Keychain on this Mac."
        }

        let selectedVoiceID = preferences.elevenLabsSelectedVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedVoiceID.isEmpty {
            if case .loaded = speechProviderController.elevenLabsVoiceFetchStatus,
               speechProviderController.elevenLabsAvailableVoices.isEmpty {
                return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. This ElevenLabs account does not have any voices available yet."
            }

            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Load voices and choose the one you want Clicky to use."
        }

        if speechProviderController.isElevenLabsCreditExhausted {
            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Your ElevenLabs credits are exhausted right now, so Clicky is using System Speech until you top up or switch voices."
        }

        return nil
    }

    private var hasStoredElevenLabsAPIKey: Bool {
        companionManager.speechProviderCoordinator.hasStoredElevenLabsAPIKey
    }

    private var elevenLabsStatusLabel: String {
        switch speechProviderController.elevenLabsVoiceFetchStatus {
        case .idle:
            return hasStoredElevenLabsAPIKey ? "Ready to load voices" : "API key needed"
        case .loading:
            return "Loading voices"
        case .loaded:
            return speechProviderController.elevenLabsAvailableVoices.isEmpty
                ? "No voices available"
                : "\(speechProviderController.elevenLabsAvailableVoices.count) voices available"
        case let .failed(message):
            return message
        }
    }

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
                    isSelected: preferences.clickySpeechProviderMode == .system
                ) {
                    companionManager.speechProviderCoordinator.setProviderMode(.system)
                }

                providerModeButton(
                    title: "ElevenLabs",
                    isSelected: preferences.clickySpeechProviderMode == .elevenLabsBYO
                ) {
                    companionManager.speechProviderCoordinator.setProviderMode(.elevenLabsBYO)
                }
            }

            if preferences.clickySpeechProviderMode == .system {
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
                    if let fallbackSummary = speechFallbackSummary {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Voice fallback active")
                                .font(ClickyTypography.body(size: 13, weight: .semibold))
                                .foregroundColor(palette.cardPrimaryText)

                            Text(fallbackSummary)
                                .font(.caption)
                                .foregroundColor(palette.cardSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(palette.cardAccent.opacity(0.32))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(palette.cardBorder.opacity(0.32), lineWidth: 0.8)
                                )
                        )
                    }

                    Text(hasStoredElevenLabsAPIKey ? "Update or remove your ElevenLabs API key." : "Add your ElevenLabs API key to unlock extra voices.")
                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                        .foregroundColor(palette.cardPrimaryText)

                    CompanionStudioElevenLabsAPIKeyField(speechProviderController: speechProviderController)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        Button {
                            companionManager.speechProviderCoordinator.saveAPIKey()
                        } label: {
                            Label(hasStoredElevenLabsAPIKey ? "Update API Key" : "Save API Key", systemImage: "key.horizontal")
                                .font(ClickyTypography.body(size: 13, weight: .semibold))
                        }
                        .modifier(CompanionStudioPrimaryButtonModifier())
                        .pointerCursor()

                        if hasStoredElevenLabsAPIKey {
                            Button {
                                companionManager.speechProviderCoordinator.deleteAPIKey()
                            } label: {
                                Label("Delete API Key", systemImage: "trash")
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                            }
                            .modifier(CompanionStudioSecondaryButtonModifier())
                            .pointerCursor()
                        }
                    }

                    if hasStoredElevenLabsAPIKey {
                        Text("Loaded voices")
                            .font(ClickyTypography.mono(size: 10, weight: .semibold))
                            .foregroundColor(palette.cardSecondaryText)

                        if speechProviderController.elevenLabsAvailableVoices.isEmpty {
                            Text(elevenLabsStatusLabel)
                                .font(.caption)
                                .foregroundColor(palette.cardSecondaryText)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(speechProviderController.elevenLabsAvailableVoices) { voice in
                                        Button {
                                            companionManager.speechProviderCoordinator.selectVoice(voice)
                                            companionManager.speechProviderCoordinator.previewCurrentOutput()
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

                                                if preferences.elevenLabsSelectedVoiceID == voice.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                }
                                            }
                                            .foregroundColor(palette.cardPrimaryText)
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(preferences.elevenLabsSelectedVoiceID == voice.id ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
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
                                CompanionStudioElevenLabsVoiceIDField(speechProviderController: speechProviderController)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    companionManager.speechProviderCoordinator.importVoiceByID()
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
        .animation(nil, value: preferences.clickySpeechProviderMode)
        .animation(nil, value: preferences.elevenLabsSelectedVoiceID)
        .animation(nil, value: speechProviderController.elevenLabsAvailableVoices.count)
        .onAppear {
            if preferences.clickySpeechProviderMode == .elevenLabsBYO &&
                hasStoredElevenLabsAPIKey &&
                speechProviderController.elevenLabsAvailableVoices.isEmpty {
                companionManager.speechProviderCoordinator.refreshVoices()
            }
        }
        .onChange(of: preferences.clickySpeechProviderMode) { _, newValue in
            guard newValue == .elevenLabsBYO else { return }
            if hasStoredElevenLabsAPIKey && speechProviderController.elevenLabsAvailableVoices.isEmpty {
                companionManager.speechProviderCoordinator.refreshVoices()
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

struct CompanionStudioVoicePresetPopover: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
    }

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
                        preferences.clickyVoicePreset = preset
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

                            if preferences.clickyVoicePreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(preferences.clickyVoicePreset == preset ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
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

struct CompanionStudioPersonaPresetPopover: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
    }

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
                        companionManager.settingsMutationCoordinator.setPersonaPreset(preset)
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

                            if preferences.clickyPersonaPreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(preferences.clickyPersonaPreset == preset ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
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

struct CompanionStudioThemePresetPopover: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
    }

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
                        preferences.clickyThemePreset = preset
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

                            if preferences.clickyThemePreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(preferences.clickyThemePreset == preset ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
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

struct CompanionStudioCursorPresetPopover: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cursor style")
                .font(ClickyTypography.section(size: 24))
                .foregroundColor(palette.cardPrimaryText)

            Text("Choose how Clicky should feel beside the cursor when it listens, thinks, and points.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ClickyCursorStyle.allCases) { style in
                    Button {
                        preferences.clickyCursorStyle = style
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(style.displayName)
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                                Text(style.summary)
                                    .font(.caption)
                                    .foregroundColor(palette.cardSecondaryText)
                            }

                            Spacer()

                            if preferences.clickyCursorStyle == style {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(preferences.clickyCursorStyle == style ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
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
