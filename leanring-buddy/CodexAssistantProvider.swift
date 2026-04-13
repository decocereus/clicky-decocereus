//
//  CodexAssistantProvider.swift
//  leanring-buddy
//
//  Codex runtime adapter for Clicky's canonical assistant turn contract.
//

import Foundation

final class CodexAssistantProvider: ClickyAssistantProvider {
    let backend: CompanionAgentBackend = .codex

    private let runtimeClient: CodexRuntimeClient
    private let focusContextFormatter = ClickyAssistantFocusContextFormatter()

    init(runtimeClient: CodexRuntimeClient) {
        self.runtimeClient = runtimeClient
    }

    func sendTurn(
        _ request: ClickyAssistantTurnRequest,
        onTextChunk: @MainActor @escaping @Sendable (String) -> Void
    ) async throws -> ClickyAssistantTurnResponse {
        let enrichedRequest = ClickyAssistantTurnRequest(
            systemPrompt: request.systemPrompt,
            userPrompt: appendFocusContext(to: request.userPrompt, focusContext: request.focusContext),
            conversationHistory: request.conversationHistory,
            imageAttachments: request.imageAttachments,
            focusContext: request.focusContext
        )

        ClickyAgentTurnDiagnostics.logProviderRequest(
            backendLabel: backend.displayName,
            systemPrompt: enrichedRequest.systemPrompt,
            userPrompt: enrichedRequest.userPrompt,
            conversationHistoryCount: enrichedRequest.conversationHistory.count,
            imageLabels: enrichedRequest.imageAttachments.map(\.label)
        )

        return try await runtimeClient.executeTurn(
            request: enrichedRequest,
            onTextChunk: onTextChunk
        )
    }

    private func appendFocusContext(
        to userPrompt: String,
        focusContext: ClickyAssistantFocusContext?
    ) -> String {
        guard let focusContext else { return userPrompt }
        return """
        \(focusContextFormatter.formattedText(for: focusContext))

        User request:
        \(userPrompt)
        """
    }
}
