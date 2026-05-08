//
//  CompanionPanelFlowState.swift
//  leanring-buddy
//
//  Pure screen selection state for the menu-bar companion panel.
//

struct CompanionPanelFlowState {
    let isLaunchPaywallActive: Bool
    let hasCompletedOnboarding: Bool
    let isLaunchAuthPending: Bool
    let requiresLaunchSignInForCompanionUse: Bool
    let allPermissionsGranted: Bool
    let onboardingStage: CompanionPanelOnboardingStage
    let isShowingTutorialFlow: Bool
    let hasVisibleTutorialPlayback: Bool
    let isTutorialImportRunning: Bool
    let tutorialImportStatus: TutorialImportStatus?
    let isTutorialExtractorConfigured: Bool

    var panelScreen: CompanionPanelScreen {
        if isLaunchPaywallActive {
            return .locked
        }

        if hasCompletedOnboarding {
            if isLaunchAuthPending || requiresLaunchSignInForCompanionUse {
                return .signIn
            }

            if let tutorialPanelScreen {
                return tutorialPanelScreen
            }

            return allPermissionsGranted ? .active : .repair
        }

        switch onboardingStage {
        case .welcome:
            return .welcome
        case .signIn:
            return .signIn
        case .permissions:
            return .permissions
        case .ready:
            return .ready
        }
    }

    var tutorialPanelScreen: CompanionPanelScreen? {
        guard isShowingTutorialFlow || hasVisibleTutorialPlayback else {
            return nil
        }

        if hasVisibleTutorialPlayback {
            return .tutorialPlayback
        }

        if isTutorialImportRunning {
            switch tutorialImportStatus {
            case .compiling:
                return .tutorialCompiling
            case .pending, .extracting, .extracted, .ready, .failed, .none:
                return .tutorialExtracting
            }
        }

        if let tutorialImportStatus {
            switch tutorialImportStatus {
            case .failed:
                return .tutorialFailed
            case .ready:
                return .tutorialReady
            case .compiling:
                return .tutorialCompiling
            case .extracting, .extracted:
                return .tutorialExtracting
            case .pending:
                break
            }
        }

        if !isTutorialExtractorConfigured {
            return .tutorialImportMissingSetup
        }

        return .tutorialImportEntry
    }

    var isInTutorialPanelFlow: Bool {
        Self.isTutorialPanelScreen(panelScreen)
    }

    static func isTutorialPanelScreen(_ screen: CompanionPanelScreen) -> Bool {
        switch screen {
        case .tutorialEntry, .tutorialImportEntry, .tutorialImportMissingSetup, .tutorialExtracting, .tutorialCompiling, .tutorialReady, .tutorialPlayback, .tutorialFailed:
            return true
        case .welcome, .signIn, .permissions, .ready, .active, .locked, .repair:
            return false
        }
    }
}
