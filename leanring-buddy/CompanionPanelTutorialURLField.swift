//
//  CompanionPanelTutorialURLField.swift
//  leanring-buddy
//
//  Tutorial import URL field owned by the tutorial controller rather than
//  building ad hoc bindings inside the panel body.
//

import SwiftUI

struct CompanionPanelTutorialURLField: View {
    @ObservedObject var tutorialController: ClickyTutorialController

    let placeholder: String
    let theme: ClickyTheme
    let contentTheme: ClickyTheme
    let onSubmit: () -> Void

    var body: some View {
        TextField(placeholder, text: $tutorialController.tutorialImportURLDraft)
            .textFieldStyle(.plain)
            .font(ClickyTypography.body(size: 12))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(contentTheme.card.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(contentTheme.border.opacity(0.78), lineWidth: 0.9)
            )
            .submitLabel(.go)
            .onSubmit(onSubmit)
    }
}
