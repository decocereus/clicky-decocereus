//
//  ClickyAssistantTurnTaskController.swift
//  leanring-buddy
//
//  Owns cancellation and creation of the active assistant turn task.
//

import Foundation

@MainActor
final class ClickyAssistantTurnTaskController {
    private let assistantTurnCoordinator: ClickyAssistantTurnCoordinator
    private let gatewayAgent: OpenClawGatewayCompanionAgent
    private let ttsClient: ElevenLabsTTSClient
    private let handleTutorialImportIntent: @MainActor (String) async -> Bool
    private let handleTutorialModeTurn: @MainActor (String) async -> Bool
    private let hasCompletedOnboarding: @MainActor () -> Bool
    private let allPermissionsGranted: @MainActor () -> Bool

    private var currentResponseTask: Task<Void, Never>?

    var isActive: Bool {
        currentResponseTask != nil
    }

    init(
        assistantTurnCoordinator: ClickyAssistantTurnCoordinator,
        gatewayAgent: OpenClawGatewayCompanionAgent,
        ttsClient: ElevenLabsTTSClient,
        handleTutorialImportIntent: @escaping @MainActor (String) async -> Bool,
        handleTutorialModeTurn: @escaping @MainActor (String) async -> Bool,
        hasCompletedOnboarding: @escaping @MainActor () -> Bool,
        allPermissionsGranted: @escaping @MainActor () -> Bool
    ) {
        self.assistantTurnCoordinator = assistantTurnCoordinator
        self.gatewayAgent = gatewayAgent
        self.ttsClient = ttsClient
        self.handleTutorialImportIntent = handleTutorialImportIntent
        self.handleTutorialModeTurn = handleTutorialModeTurn
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.allPermissionsGranted = allPermissionsGranted
    }

    func cancel() {
        currentResponseTask?.cancel()
    }

    func stop() {
        currentResponseTask?.cancel()
        currentResponseTask = nil
    }

    func submitTranscript(
        _ transcript: String,
        historyTranscriptOverride: String? = nil,
        skipsPreflightIntentHandlers: Bool = false
    ) {
        currentResponseTask?.cancel()
        gatewayAgent.cancelActiveRequest()
        ttsClient.stopPlayback()

        currentResponseTask = Task {
            if !skipsPreflightIntentHandlers {
                if await handleTutorialImportIntent(transcript) {
                    return
                }

                if await handleTutorialModeTurn(transcript) {
                    return
                }
            }

            await assistantTurnCoordinator.runTurn(
                transcript: transcript,
                historyTranscriptOverride: historyTranscriptOverride,
                hasCompletedOnboarding: hasCompletedOnboarding(),
                allPermissionsGranted: allPermissionsGranted()
            )
        }
    }
}
