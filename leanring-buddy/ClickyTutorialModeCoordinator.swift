//
//  ClickyTutorialModeCoordinator.swift
//  leanring-buddy
//
//  Handles active tutorial-mode voice turns.
//

import Foundation

@MainActor
final class ClickyTutorialModeCoordinator {
    private let tutorialController: ClickyTutorialController
    private let playbackCoordinator: ClickyTutorialPlaybackCoordinator
    private let assistantTurnExecutor: ClickyAssistantTurnExecutor
    private let assistantResponseRepairer: ClickyAssistantResponseRepairer
    private let focusContextProvider: ClickyAssistantFocusContextProvider
    private let selectedBackendProvider: @MainActor () -> CompanionAgentBackend
    private let setVoiceState: @MainActor (CompanionVoiceState) -> Void
    private let playSpeech: @MainActor (String, ClickySpeechPlaybackPurpose) async -> Void
    private let queuePointingTargets: @MainActor ([QueuedPointingTarget]) -> Void

    private let assistantTurnBuilder = ClickyAssistantTurnBuilder()
    private var conversationHistory: [(userTranscript: String, assistantResponse: String)] = []

    init(
        tutorialController: ClickyTutorialController,
        playbackCoordinator: ClickyTutorialPlaybackCoordinator,
        assistantTurnExecutor: ClickyAssistantTurnExecutor,
        assistantResponseRepairer: ClickyAssistantResponseRepairer,
        focusContextProvider: ClickyAssistantFocusContextProvider,
        selectedBackendProvider: @escaping @MainActor () -> CompanionAgentBackend,
        setVoiceState: @escaping @MainActor (CompanionVoiceState) -> Void,
        playSpeech: @escaping @MainActor (String, ClickySpeechPlaybackPurpose) async -> Void,
        queuePointingTargets: @escaping @MainActor ([QueuedPointingTarget]) -> Void
    ) {
        self.tutorialController = tutorialController
        self.playbackCoordinator = playbackCoordinator
        self.assistantTurnExecutor = assistantTurnExecutor
        self.assistantResponseRepairer = assistantResponseRepairer
        self.focusContextProvider = focusContextProvider
        self.selectedBackendProvider = selectedBackendProvider
        self.setVoiceState = setVoiceState
        self.playSpeech = playSpeech
        self.queuePointingTargets = queuePointingTargets
    }

    func clearConversationHistory() {
        conversationHistory = []
    }

    func handleTurnIfNeeded(for transcript: String) async -> Bool {
        guard var sessionState = tutorialController.tutorialSessionState, sessionState.isActive else {
            return false
        }

        let normalizedTranscript = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if ClickyTutorialModeIntentMatcher.shouldStopTutorialMode(normalizedTranscript) {
            sessionState.isActive = false
            tutorialController.tutorialSessionState = sessionState
            clearConversationHistory()
            playbackCoordinator.stopPlayback()
            tutorialController.tutorialImportStatusMessage = "Tutorial mode ended."
            setVoiceState(.responding)
            await playSpeech(
                "okay, tutorial mode is done. we’re back to normal help now.",
                .systemMessage
            )
            return true
        }

        guard let lessonDraft = tutorialController.currentTutorialImportDraft?.compiledLessonDraft,
              lessonDraft.steps.indices.contains(sessionState.currentStepIndex) else {
            return false
        }

        let currentStep = lessonDraft.steps[sessionState.currentStepIndex]

        if ClickyTutorialModeIntentMatcher.shouldAdvanceStep(normalizedTranscript) {
            await advanceOrFinish(sessionState: sessionState, lessonDraft: lessonDraft)
            return true
        }

        if ClickyTutorialModeIntentMatcher.shouldRepeatCurrentStep(normalizedTranscript) {
            playbackCoordinator.updateBubble("\(currentStep.title). \(currentStep.instruction)")
            setVoiceState(.responding)
            await playSpeech(
                "\(currentStep.instruction) let me know once done and we will move on.",
                .systemMessage
            )
            return true
        }

        if ClickyTutorialModeIntentMatcher.shouldListSteps(normalizedTranscript) {
            let stepSummary = lessonDraft.steps
                .enumerated()
                .map { index, step in
                    "step \(index + 1), \(step.title)"
                }
                .joined(separator: ". ")
            setVoiceState(.responding)
            await playSpeech("here are the steps. \(stepSummary).", .systemMessage)
            return true
        }

        return await handleAgentTurn(
            transcript: transcript,
            tutorialSessionState: sessionState,
            currentStep: currentStep
        )
    }

    private func advanceOrFinish(
        sessionState: TutorialSessionState,
        lessonDraft: TutorialLessonDraft
    ) async {
        var updatedSessionState = sessionState
        if updatedSessionState.currentStepIndex + 1 < lessonDraft.steps.count {
            updatedSessionState.currentStepIndex += 1
            tutorialController.tutorialSessionState = updatedSessionState
            let nextStep = lessonDraft.steps[updatedSessionState.currentStepIndex]
            playbackCoordinator.updateBubble("\(nextStep.title). \(nextStep.instruction)")
            if let nextTimestamp = nextStep.sourceVideoPromptTimestamp {
                tutorialController.tutorialPlaybackState?.lastPromptTimestampSeconds = nextTimestamp
            }
            setVoiceState(.responding)
            await playSpeech(
                "\(nextStep.instruction) let me know once done and we will move on.",
                .systemMessage
            )
        } else {
            updatedSessionState.isActive = false
            tutorialController.tutorialSessionState = updatedSessionState
            playbackCoordinator.updateBubble("Tutorial complete.")
            setVoiceState(.responding)
            await playSpeech(
                "nice, that was the last step. you’re done with this tutorial unless you want to review anything.",
                .systemMessage
            )
        }
    }

    private func handleAgentTurn(
        transcript: String,
        tutorialSessionState: TutorialSessionState,
        currentStep: TutorialLessonStep
    ) async -> Bool {
        setVoiceState(.thinking)

        do {
            let screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()
            let labeledImages = screenCaptures.map { capture in
                ClickyAssistantLabeledImage(
                    data: capture.imageData,
                    label: capture.label,
                    mimeType: "image/jpeg"
                )
            }
            let focusContext = focusContextProvider.captureCurrentFocusContext()

            let tutorialAwarePrompt = ClickyTutorialModePromptBuilder.userPrompt(
                transcript: transcript,
                tutorialSessionState: tutorialSessionState,
                currentStep: currentStep,
                conversationHistory: conversationHistory
            )
            let systemPrompt = ClickyTutorialModePromptBuilder.systemPrompt()
            let request = assistantTurnBuilder.buildRequest(
                systemPrompt: systemPrompt,
                userPrompt: tutorialAwarePrompt,
                conversationHistory: conversationHistory,
                labeledImages: labeledImages,
                focusContext: focusContext
            )

            let selectedBackend = selectedBackendProvider()
            let response = try await assistantTurnExecutor.execute(
                ClickyAssistantTurnPlan(
                    backend: selectedBackend,
                    systemPrompt: systemPrompt,
                    request: request
                ),
                onTextChunk: { _ in }
            )

            ClickyAgentTurnDiagnostics.logRawResponse(
                backend: selectedBackend,
                response: response.text
            )

            let audit = assistantResponseRepairer.audit(
                responseText: response.text,
                transcript: transcript
            )
            let structuredResponse: ClickyAssistantStructuredResponse

            if audit.needsRepair {
                let repairImages = screenCaptures.map { capture in
                    (data: capture.imageData, label: capture.label)
                }
                let repairedResponse = try await assistantResponseRepairer.repairIfNeeded(
                    backend: selectedBackend,
                    originalResponseText: response.text,
                    transcript: transcript,
                    baseSystemPrompt: systemPrompt,
                    labeledImages: repairImages,
                    focusContext: focusContext,
                    conversationHistory: conversationHistory,
                    audit: audit
                )
                structuredResponse = repairedResponse.structuredResponse
                ClickyAgentTurnDiagnostics.logRawResponse(
                    backend: selectedBackend,
                    response: repairedResponse.rawText
                )
            } else {
                structuredResponse = try ClickyAssistantResponseContract.parse(
                    rawResponse: response.text,
                    requiresPoints: ClickyAssistantResponseRepairer.transcriptRequiresVisiblePointing(transcript)
                )
            }

            let spokenText = structuredResponse.spokenText
            ClickyAgentTurnDiagnostics.logParsedResponse(
                backend: selectedBackend,
                mode: structuredResponse.mode,
                spokenResponse: spokenText,
                points: structuredResponse.points
            )

            appendConversationTurn(transcript: transcript, spokenText: spokenText)
            playbackCoordinator.updateBubble(spokenText)

            if !structuredResponse.points.isEmpty {
                let initialFocusContext = focusContextProvider.captureCurrentFocusContext()
                let freshCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG(
                    cursorLocationOverride: CGPoint(
                        x: initialFocusContext.cursorX,
                        y: initialFocusContext.cursorY
                    )
                )
                let resolvedTargets = ClickyPointingCoordinator.resolvedPointingTargets(
                    from: ClickyPointingCoordinator.parsedPointingTargets(from: structuredResponse.points),
                    screenCaptures: freshCaptures
                )
                if !resolvedTargets.isEmpty {
                    queuePointingTargets(resolvedTargets)
                }
            }

            await playSpeech(spokenText, .assistantResponse)
            setVoiceState(.responding)
            return true
        } catch {
            setVoiceState(.idle)
            tutorialController.tutorialImportStatusMessage = error.localizedDescription
            return true
        }
    }

    private func appendConversationTurn(transcript: String, spokenText: String) {
        conversationHistory.append((
            userTranscript: transcript,
            assistantResponse: spokenText
        ))
        if conversationHistory.count > 10 {
            conversationHistory.removeFirst(conversationHistory.count - 10)
        }
    }
}
