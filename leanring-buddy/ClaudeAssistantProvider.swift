//
//  ClaudeAssistantProvider.swift
//  leanring-buddy
//
//  Anthropic/Claude adapter for Clicky's canonical assistant turn contract.
//

import Foundation

final class ClaudeAssistantProvider: ClickyAssistantProvider {
    let backend: CompanionAgentBackend = .claude

    private let claudeAPI: ClaudeAPI
    private let focusContextFormatter = ClickyAssistantFocusContextFormatter()

    init(claudeAPI: ClaudeAPI) {
        self.claudeAPI = claudeAPI
    }

    func sendTurn(
        _ request: ClickyAssistantTurnRequest,
        onTextChunk: @MainActor @escaping @Sendable (String) -> Void
    ) async throws -> ClickyAssistantTurnResponse {
        let userPrompt = appendFocusContext(to: request.userPrompt, focusContext: request.focusContext)

        ClickyAgentTurnDiagnostics.logProviderRequest(
            backendLabel: backend.displayName,
            systemPrompt: request.systemPrompt,
            userPrompt: userPrompt,
            conversationHistoryCount: request.conversationHistory.count,
            imageLabels: request.imageAttachments.map(\.label)
        )

        let response = try await claudeAPI.analyzeImageStreaming(
            images: request.imageAttachments.map { attachment in
                (data: attachment.data, label: attachment.label)
            },
            systemPrompt: request.systemPrompt,
            conversationHistory: request.conversationHistory.map { turn in
                (userPlaceholder: turn.userText, assistantResponse: turn.assistantText)
            },
            userPrompt: userPrompt,
            onTextChunk: onTextChunk
        )

        return ClickyAssistantTurnResponse(
            text: response.text,
            duration: response.duration
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
