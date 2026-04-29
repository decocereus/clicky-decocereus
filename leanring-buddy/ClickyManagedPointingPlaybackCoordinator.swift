//
//  ClickyManagedPointingPlaybackCoordinator.swift
//  leanring-buddy
//
//  Runs narrated multi-target pointing sequences for assistant walkthroughs.
//

import Foundation

@MainActor
final class ClickyManagedPointingPlaybackCoordinator {
    private let pointingSequenceController: ClickyPointingSequenceController
    private let playSpeech: @MainActor (String, ClickySpeechPlaybackPurpose) async -> ClickySpeechPlaybackOutcome
    private let waitForSpeechPlaybackToFinish: @MainActor () async -> Void

    init(
        pointingSequenceController: ClickyPointingSequenceController,
        playSpeech: @escaping @MainActor (String, ClickySpeechPlaybackPurpose) async -> ClickySpeechPlaybackOutcome,
        waitForSpeechPlaybackToFinish: @escaping @MainActor () async -> Void
    ) {
        self.pointingSequenceController = pointingSequenceController
        self.playSpeech = playSpeech
        self.waitForSpeechPlaybackToFinish = waitForSpeechPlaybackToFinish
    }

    func play(
        introText: String,
        responsePoints: [ClickyAssistantResponsePoint],
        resolvedTargets: [QueuedPointingTarget]
    ) async {
        let narrationSteps = ClickyPointingCoordinator.managedPointNarrationSteps(from: responsePoints)
        guard !narrationSteps.isEmpty, narrationSteps.count == resolvedTargets.count else {
            return
        }

        let hasExplicitPerPointNarration = responsePoints.allSatisfy { responsePoint in
            let trimmedExplanation = responsePoint.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !trimmedExplanation.isEmpty
        }

        if hasExplicitPerPointNarration,
           !introText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let playbackOutcome = await playSpeech(introText, .assistantResponse)
            if playbackOutcome.finalProviderDisplayName == "Unavailable" {
                return
            }
            await waitForSpeechPlaybackToFinish()
        }

        pointingSequenceController.beginManagedSequence()
        pointingSequenceController.queue(resolvedTargets)

        for (index, narrationStep) in narrationSteps.enumerated() {
            await pointingSequenceController.waitForTargetArrival()

            let playbackOutcome = await playSpeech(narrationStep.spokenText, .assistantResponse)
            if playbackOutcome.finalProviderDisplayName == "Unavailable" {
                pointingSequenceController.requestManagedSequenceReturn()
                return
            }
            await waitForSpeechPlaybackToFinish()

            if index < narrationSteps.count - 1 {
                pointingSequenceController.advance()
            } else {
                pointingSequenceController.requestManagedSequenceReturn()
            }
        }
    }
}
