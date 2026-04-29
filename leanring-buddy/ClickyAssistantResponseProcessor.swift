//
//  ClickyAssistantResponseProcessor.swift
//  leanring-buddy
//
//  Audits, repairs, parses, and resolves assistant responses.
//

import Foundation

struct ClickyProcessedAssistantResponse {
    let rawText: String
    let structuredResponse: ClickyAssistantStructuredResponse
    let spokenText: String
    let resolvedTargets: [QueuedPointingTarget]
    let managedNarrationSteps: [ManagedPointNarrationStep]
}

struct ClickyAssistantConversationHistory {
    private(set) var exchanges: [(userTranscript: String, assistantResponse: String)] = []

    mutating func append(
        userTranscript: String,
        assistantResponse: String,
        maximumCount: Int = 10
    ) {
        exchanges.append((
            userTranscript: userTranscript,
            assistantResponse: assistantResponse
        ))
        if exchanges.count > maximumCount {
            exchanges.removeFirst(exchanges.count - maximumCount)
        }
    }
}

@MainActor
final class ClickyAssistantResponseProcessor {
    private let repairer: ClickyAssistantResponseRepairer

    init(repairer: ClickyAssistantResponseRepairer) {
        self.repairer = repairer
    }

    func process(
        rawResponseText: String,
        backend: CompanionAgentBackend,
        transcript: String,
        baseSystemPrompt: String,
        labeledImages: [(data: Data, label: String)],
        focusContext: ClickyAssistantFocusContext,
        conversationHistory: [(userTranscript: String, assistantResponse: String)],
        screenCaptures: [CompanionScreenCapture]
    ) async throws -> ClickyProcessedAssistantResponse {
        ClickyAgentTurnDiagnostics.logRawResponse(
            backend: backend,
            response: rawResponseText
        )

        let initialAudit = repairer.audit(
            responseText: rawResponseText,
            transcript: transcript
        )

        let structuredResponse: ClickyAssistantStructuredResponse
        let finalRawText: String

        if initialAudit.needsRepair {
            let repairedResponse = try await repairer.repairIfNeeded(
                backend: backend,
                originalResponseText: rawResponseText,
                transcript: transcript,
                baseSystemPrompt: baseSystemPrompt,
                labeledImages: labeledImages,
                focusContext: focusContext,
                conversationHistory: conversationHistory,
                audit: initialAudit
            )

            finalRawText = repairedResponse.rawText
            structuredResponse = repairedResponse.structuredResponse

            ClickyAgentTurnDiagnostics.logRawResponse(
                backend: backend,
                response: finalRawText
            )
        } else {
            finalRawText = rawResponseText
            structuredResponse = try ClickyAssistantResponseContract.parse(
                rawResponse: rawResponseText,
                requiresPoints: ClickyAssistantResponseRepairer.transcriptRequiresVisiblePointing(transcript)
            )
        }

        let spokenText = structuredResponse.spokenText
        ClickyAgentTurnDiagnostics.logParsedResponse(
            backend: backend,
            mode: structuredResponse.mode,
            spokenResponse: spokenText,
            points: structuredResponse.points
        )

        let resolvedTargets = ClickyPointingCoordinator.resolvedPointingTargets(
            from: ClickyPointingCoordinator.parsedPointingTargets(from: structuredResponse.points),
            screenCaptures: screenCaptures
        )
        let managedNarrationSteps = ClickyPointingCoordinator.managedPointNarrationSteps(
            from: structuredResponse.points
        )

        return ClickyProcessedAssistantResponse(
            rawText: finalRawText,
            structuredResponse: structuredResponse,
            spokenText: spokenText,
            resolvedTargets: resolvedTargets,
            managedNarrationSteps: managedNarrationSteps
        )
    }
}
