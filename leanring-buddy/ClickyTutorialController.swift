//
//  ClickyTutorialController.swift
//  leanring-buddy
//
//  Observable tutorial import and playback state for the companion surfaces.
//

import Combine
import Foundation

@MainActor
final class ClickyTutorialController: ObservableObject {
    @Published var tutorialPlaybackState: TutorialPlaybackBindingState?
    @Published var tutorialPlaybackBubbleOpacity: Double = 0.0
    @Published var tutorialPlaybackLastCommand: TutorialPlaybackCommand?
    @Published var tutorialPlaybackCommandNonce: Int = 0
    @Published var tutorialImportURLDraft: String = ""
    @Published var currentTutorialImportDraft: TutorialImportDraft?
    @Published var tutorialSessionState: TutorialSessionState?
    @Published var isTutorialImportRunning: Bool = false
    @Published var tutorialImportStatusMessage: String?
}
