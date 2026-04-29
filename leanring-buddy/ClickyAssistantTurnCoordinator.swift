//
//  ClickyAssistantTurnCoordinator.swift
//  leanring-buddy
//
//  Runs the main assistant turn after preflight intent handlers complete.
//

import Foundation

@MainActor
final class ClickyAssistantTurnCoordinator {
    private let turnExecutor: ClickyAssistantTurnExecutor
    private let turnContextBuilder: ClickyAssistantTurnContextBuilder
    private let responseProcessor: ClickyAssistantResponseProcessor
    private let launchTurnGate: ClickyLaunchTurnGate
    private let launchPostTurnRecorder: ClickyLaunchPostTurnRecorder
    private let selectedBackendProvider: @MainActor () -> CompanionAgentBackend
    private let setVoiceState: @MainActor (CompanionVoiceState) -> Void
    private let playSpeech: @MainActor (String, ClickySpeechPlaybackPurpose) async -> ClickySpeechPlaybackOutcome
    private let playManagedPointSequence: @MainActor (String, [ClickyAssistantResponsePoint], [QueuedPointingTarget]) async -> Void
    private let queuePointingTargets: @MainActor ([QueuedPointingTarget]) -> Void
    private let openStudio: @MainActor () -> Void
    private let scheduleTransientHideIfNeeded: @MainActor () -> Void
    private let logActivePersonaForRequest: @MainActor (String, CompanionAgentBackend, String) -> Void
    private let logAgentResponse: @MainActor (String, CompanionAgentBackend) -> Void

    private var conversationHistory = ClickyAssistantConversationHistory()

    init(
        turnExecutor: ClickyAssistantTurnExecutor,
        turnContextBuilder: ClickyAssistantTurnContextBuilder,
        responseProcessor: ClickyAssistantResponseProcessor,
        launchTurnGate: ClickyLaunchTurnGate,
        launchPostTurnRecorder: ClickyLaunchPostTurnRecorder,
        selectedBackendProvider: @escaping @MainActor () -> CompanionAgentBackend,
        setVoiceState: @escaping @MainActor (CompanionVoiceState) -> Void,
        playSpeech: @escaping @MainActor (String, ClickySpeechPlaybackPurpose) async -> ClickySpeechPlaybackOutcome,
        playManagedPointSequence: @escaping @MainActor (String, [ClickyAssistantResponsePoint], [QueuedPointingTarget]) async -> Void,
        queuePointingTargets: @escaping @MainActor ([QueuedPointingTarget]) -> Void,
        openStudio: @escaping @MainActor () -> Void,
        scheduleTransientHideIfNeeded: @escaping @MainActor () -> Void,
        logActivePersonaForRequest: @escaping @MainActor (String, CompanionAgentBackend, String) -> Void,
        logAgentResponse: @escaping @MainActor (String, CompanionAgentBackend) -> Void
    ) {
        self.turnExecutor = turnExecutor
        self.turnContextBuilder = turnContextBuilder
        self.responseProcessor = responseProcessor
        self.launchTurnGate = launchTurnGate
        self.launchPostTurnRecorder = launchPostTurnRecorder
        self.selectedBackendProvider = selectedBackendProvider
        self.setVoiceState = setVoiceState
        self.playSpeech = playSpeech
        self.playManagedPointSequence = playManagedPointSequence
        self.queuePointingTargets = queuePointingTargets
        self.openStudio = openStudio
        self.scheduleTransientHideIfNeeded = scheduleTransientHideIfNeeded
        self.logActivePersonaForRequest = logActivePersonaForRequest
        self.logAgentResponse = logAgentResponse
    }

    func runTurn(
        transcript: String,
        historyTranscriptOverride: String?,
        hasCompletedOnboarding: Bool,
        allPermissionsGranted: Bool
    ) async {
        var launchAuthorization = LaunchAssistantTurnAuthorization.standard
        setVoiceState(.thinking)

        do {
            launchAuthorization = try await launchTurnGate.prepareAuthorizationForAssistantTurn(
                hasCompletedOnboarding: hasCompletedOnboarding,
                allPermissionsGranted: allPermissionsGranted
            )

            if let storedSession = launchAuthorization.session,
               !storedSession.entitlement.hasAccess,
               storedSession.trial?.status == "paywalled" {
                openStudio()
                setVoiceState(.responding)
                _ = await playSpeech(
                    ClickyLaunchTurnGate.paywallLockedMessage,
                    .systemMessage
                )
                return
            }

            let selectedBackend = selectedBackendProvider()
            let turnContext = try await turnContextBuilder.captureContext(backend: selectedBackend)

            guard !Task.isCancelled else { return }

            let plan = turnContextBuilder.makePlan(
                backend: selectedBackend,
                authorization: launchAuthorization,
                transcript: transcript,
                context: turnContext,
                conversationHistory: conversationHistory.exchanges
            )
            logActivePersonaForRequest(transcript, selectedBackend, plan.systemPrompt)

            let response = try await turnExecutor.execute(
                plan,
                onTextChunk: { _ in }
            )

            guard !Task.isCancelled else { return }

            let processedResponse = try await responseProcessor.process(
                rawResponseText: response.text,
                backend: selectedBackend,
                transcript: transcript,
                baseSystemPrompt: plan.systemPrompt,
                labeledImages: turnContext.labeledImages,
                focusContext: turnContext.focusContext,
                conversationHistory: conversationHistory.exchanges,
                screenCaptures: turnContext.screenCaptures
            )

            handlePointingState(for: processedResponse)

            conversationHistory.append(
                userTranscript: historyTranscriptOverride ?? transcript,
                assistantResponse: processedResponse.spokenText
            )

            ClickyLogger.debug(.agent, "Conversation history updated exchanges=\(conversationHistory.exchanges.count)")
            ClickyAnalytics.trackAIResponseReceived(response: processedResponse.spokenText)
            logAgentResponse(processedResponse.spokenText, selectedBackend)

            await launchPostTurnRecorder.recordSuccessfulAssistantTurn(
                authorization: launchAuthorization
            )

            await playProcessedResponse(processedResponse)
        } catch is CancellationError {
            // User spoke again; response was interrupted.
        } catch {
            await handleFailure(error, launchAuthorization: launchAuthorization)
        }

        if !Task.isCancelled {
            setVoiceState(.idle)
            scheduleTransientHideIfNeeded()
        }
    }

    private func handlePointingState(for processedResponse: ClickyProcessedAssistantResponse) {
        let resolvedTargets = processedResponse.resolvedTargets
        let managedNarrationSteps = processedResponse.managedNarrationSteps

        if !resolvedTargets.isEmpty {
            setVoiceState(.idle)
        }

        if !resolvedTargets.isEmpty && managedNarrationSteps.isEmpty {
            queuePointingTargets(resolvedTargets)
            let labels = resolvedTargets
                .compactMap { $0.elementLabel }
                .joined(separator: ", ")
            ClickyLogger.debug(.ui, "Element pointing queued count=\(resolvedTargets.count) labels=\(labels)")
        } else if !resolvedTargets.isEmpty {
            let labels = resolvedTargets
                .compactMap { $0.elementLabel }
                .joined(separator: ", ")
            ClickyLogger.debug(.ui, "Element pointing managed count=\(resolvedTargets.count) labels=\(labels)")
        } else {
            ClickyLogger.debug(.ui, "Element pointing skipped reason=no-targets")
        }
    }

    private func playProcessedResponse(_ processedResponse: ClickyProcessedAssistantResponse) async {
        let spokenText = processedResponse.spokenText
        let resolvedTargets = processedResponse.resolvedTargets
        let managedNarrationSteps = processedResponse.managedNarrationSteps

        if !managedNarrationSteps.isEmpty && managedNarrationSteps.count == resolvedTargets.count {
            setVoiceState(.responding)
            await playManagedPointSequence(
                spokenText,
                processedResponse.structuredResponse.points,
                resolvedTargets
            )
        } else if !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let playbackOutcome = await playSpeech(spokenText, .assistantResponse)
            if playbackOutcome.finalProviderDisplayName == "Unavailable" {
                if let fallbackMessage = playbackOutcome.fallbackMessage {
                    ClickyAnalytics.trackTTSError(error: fallbackMessage)
                }
                setVoiceState(.idle)
            } else if playbackOutcome.encounteredElevenLabsFailure,
                      let fallbackMessage = playbackOutcome.fallbackMessage {
                ClickyAnalytics.trackTTSError(error: fallbackMessage)
                setVoiceState(.responding)
            } else {
                setVoiceState(.responding)
            }
        }
    }

    private func handleFailure(
        _ error: Error,
        launchAuthorization: LaunchAssistantTurnAuthorization
    ) async {
        ClickyAnalytics.trackResponseError(error: error.localizedDescription)
        ClickyLogger.error(.agent, "Assistant response failed error=\(error.localizedDescription)")

        if launchAuthorization.shouldUsePaywallTurn {
            await launchPostTurnRecorder.recordPaywallFallback(
                authorization: launchAuthorization
            )

            setVoiceState(.responding)
            _ = await playSpeech(
                ClickyLaunchTurnGate.paywallLockedMessage,
                .assistantResponse
            )
        } else {
            setVoiceState(.idle)
        }
    }
}
