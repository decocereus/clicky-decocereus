//
//  ClickyTutorialImportVoiceIntentCoordinator.swift
//  leanring-buddy
//
//  Handles voice turns that ask Clicky to import a tutorial.
//

import Foundation

@MainActor
final class ClickyTutorialImportVoiceIntentCoordinator {
    private let tutorialController: ClickyTutorialController
    private let surfaceController: ClickySurfaceController
    private let playSpeech: @MainActor (String, ClickySpeechPlaybackPurpose) async -> ClickySpeechPlaybackOutcome

    init(
        tutorialController: ClickyTutorialController,
        surfaceController: ClickySurfaceController,
        playSpeech: @escaping @MainActor (String, ClickySpeechPlaybackPurpose) async -> ClickySpeechPlaybackOutcome
    ) {
        self.tutorialController = tutorialController
        self.surfaceController = surfaceController
        self.playSpeech = playSpeech
    }

    func handleIntentIfNeeded(for transcript: String) async -> Bool {
        let normalizedTranscript = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard ClickyTutorialModeIntentMatcher.isImportIntent(normalizedTranscript) else {
            return false
        }

        tutorialController.tutorialImportStatusMessage = "Open the companion menu and paste the YouTube URL to begin."
        NotificationCenter.default.post(name: .clickyShowPanel, object: nil)
        surfaceController.voiceState = .responding
        _ = await playSpeech(
            "open the companion menu and paste the youtube url to begin. once it's there, hit start learning and i'll guide you through it.",
            .systemMessage
        )
        return true
    }
}
