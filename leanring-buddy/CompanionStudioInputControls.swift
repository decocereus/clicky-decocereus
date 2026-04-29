//
//  CompanionStudioInputControls.swift
//  leanring-buddy
//
//  Dedicated Studio controls that keep bindings out of the main scene bodies.
//

import SwiftUI

struct CompanionStudioPointerGuidanceToggle: View {
    @ObservedObject var preferences: ClickyPreferencesStore
    let onSetClickyCursorEnabled: (Bool) -> Void
    let theme: ClickyTheme

    var body: some View {
        Toggle(
            "Show pointer guidance on screen",
            isOn: Binding(
                get: { preferences.isClickyCursorEnabled },
                set: onSetClickyCursorEnabled
            )
        )
        .labelsHidden()
        .toggleStyle(.switch)
        .tint(theme.primary)
    }
}

struct CompanionStudioAdvancedToneEditor: View {
    @ObservedObject var preferences: ClickyPreferencesStore
    let palette: CompanionStudioScalaPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add any custom instructions you want Clicky to follow when it speaks.")
                .font(.caption)
                .foregroundColor(palette.cardSecondaryText)

            TextEditor(text: $preferences.clickyPersonaToneInstructions)
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

struct CompanionStudioElevenLabsAPIKeyField: View {
    @ObservedObject var speechProviderController: ClickySpeechProviderController

    var body: some View {
        SecureField("ElevenLabs API key", text: $speechProviderController.elevenLabsAPIKeyDraft)
            .textFieldStyle(.plain)
            .font(ClickyTypography.body(size: 13))
    }
}

struct CompanionStudioElevenLabsVoiceIDField: View {
    @ObservedObject var speechProviderController: ClickySpeechProviderController

    var body: some View {
        TextField("Voice ID", text: $speechProviderController.elevenLabsImportVoiceIDDraft)
            .textFieldStyle(.plain)
            .font(ClickyTypography.body(size: 13))
    }
}
