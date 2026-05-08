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
    @Published var currentTutorialImportDraft: TutorialImportDraft? {
        didSet { persistTutorialState() }
    }
    @Published var tutorialSessionState: TutorialSessionState? {
        didSet { persistTutorialState() }
    }
    @Published var isTutorialImportRunning: Bool = false
    @Published var tutorialImportStatusMessage: String?

    private let stateStore: ClickyTutorialStateStore

    init(stateStore: ClickyTutorialStateStore = ClickyTutorialStateStore()) {
        self.stateStore = stateStore

        if let snapshot = stateStore.load() {
            currentTutorialImportDraft = snapshot.currentImportDraft
            tutorialSessionState = snapshot.sessionState
        }
    }

    private func persistTutorialState() {
        do {
            try stateStore.save(
                ClickyTutorialStateSnapshot(
                    currentImportDraft: currentTutorialImportDraft,
                    sessionState: tutorialSessionState
                )
            )
        } catch {
            ClickyLogger.error(.app, "Failed to persist tutorial state error=\(error.localizedDescription)")
        }
    }
}
