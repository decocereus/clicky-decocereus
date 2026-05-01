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
            systemPrompt: appendCodexComputerUseGuidance(
                to: request.systemPrompt,
                mcpServers: request.mcpServers
            ),
            userPrompt: appendFocusContext(to: request.userPrompt, focusContext: request.focusContext),
            conversationHistory: request.conversationHistory,
            imageAttachments: request.imageAttachments,
            focusContext: request.focusContext,
            mcpServers: request.mcpServers
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

    private func appendCodexComputerUseGuidance(
        to systemPrompt: String,
        mcpServers: [ClickyAssistantMCPServerConfiguration]
    ) -> String {
        guard mcpServers.contains(where: { $0.name == "background-computer-use" }) else {
            return systemPrompt
        }

        return """
        \(systemPrompt)

        codex computer-use routing:
        - Clicky's BackgroundComputerUse MCP server is exposed to Codex under the MCP server name `computer-use`.
        - When reading MCP resources or calling MCP tools, use the `computer-use` server name, not `background-computer-use`.
        - If the user asks you to interact with the current desktop app and the action is safe, use the computer-use tools directly instead of giving manual steps.
        - Keep simple desktop tasks short: observe the relevant app/window, act, then verify once. Do not repeatedly call get_app_state when the latest state or action result is enough.
        - Prefer get_window_state for a known window after the first observation; use get_app_state only when you still need to select the app/window.
        """
    }
}
