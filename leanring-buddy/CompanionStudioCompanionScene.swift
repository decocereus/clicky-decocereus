//
//  CompanionStudioCompanionScene.swift
//  leanring-buddy
//
//  Daily companion configuration surface for the Studio window.
//

import SwiftUI

struct CompanionStudioCompanionScene: View {
    let companionManager: CompanionManager
    @Binding var isSupportModeEnabled: Bool

    @State private var isPersonaPopoverPresented = false
    @State private var isVoicePopoverPresented = false
    @State private var isThemePopoverPresented = false
    @State private var isCursorPopoverPresented = false
    @State private var isProviderPanelExpanded = false
    @State private var isAdvancedToneExpanded = false

    init(companionManager: CompanionManager, isSupportModeEnabled: Binding<Bool>) {
        self.companionManager = companionManager
        _isSupportModeEnabled = isSupportModeEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CompanionStudioCompanionHeroCard(companionManager: companionManager)

            CompanionStudioCompanionJourneyCard()

            CompanionStudioCompanionPersonalizeCard(
                companionManager: companionManager,
                isSupportModeEnabled: $isSupportModeEnabled,
                isPersonaPopoverPresented: $isPersonaPopoverPresented,
                isVoicePopoverPresented: $isVoicePopoverPresented,
                isThemePopoverPresented: $isThemePopoverPresented,
                isCursorPopoverPresented: $isCursorPopoverPresented,
                isProviderPanelExpanded: $isProviderPanelExpanded,
                isAdvancedToneExpanded: $isAdvancedToneExpanded
            )

            HStack(alignment: .top, spacing: 18) {
                CompanionStudioCompanionConnectionCard(companionManager: companionManager)
                CompanionStudioCompanionAccessCard(companionManager: companionManager)
            }
        }
    }
}
