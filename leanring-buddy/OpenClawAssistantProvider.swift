//
//  OpenClawAssistantProvider.swift
//  leanring-buddy
//
//  OpenClaw Gateway adapter for Clicky's canonical assistant turn contract.
//

import Foundation

struct OpenClawAssistantProviderConfiguration {
    let gatewayURLString: String
    let gatewayAuthToken: String?
    let agentIdentifier: String
    let sessionKey: String
    let shellIdentifier: String
}

final class OpenClawAssistantProvider: ClickyAssistantProvider {
    let backend: CompanionAgentBackend = .openClaw

    private let gatewayAgent: OpenClawGatewayCompanionAgent
    private let configurationProvider: @MainActor @Sendable () -> OpenClawAssistantProviderConfiguration
    private let computerUseToolHandler: @MainActor @Sendable (OpenClawComputerUseToolRequest) async -> [String: Any]
    private let focusContextFormatter = ClickyAssistantFocusContextFormatter()

    init(
        gatewayAgent: OpenClawGatewayCompanionAgent,
        configurationProvider: @escaping @MainActor @Sendable () -> OpenClawAssistantProviderConfiguration,
        computerUseToolHandler: @escaping @MainActor @Sendable (OpenClawComputerUseToolRequest) async -> [String: Any]
    ) {
        self.gatewayAgent = gatewayAgent
        self.configurationProvider = configurationProvider
        self.computerUseToolHandler = computerUseToolHandler
    }

    func sendTurn(
        _ request: ClickyAssistantTurnRequest,
        onTextChunk: @MainActor @escaping @Sendable (String) -> Void
    ) async throws -> ClickyAssistantTurnResponse {
        let configuration = await MainActor.run {
            configurationProvider()
        }
        let userPrompt = appendFocusContext(to: request.userPrompt, focusContext: request.focusContext)
        let openClawImages = request.imageAttachments.map { attachment in
            OpenClawGatewayImageAttachment(
                imageData: attachment.data,
                label: attachment.label,
                mimeType: attachment.mimeType ?? "image/jpeg"
            )
        }
        let messageBody = buildGatewayMessageBody(
            imageLabels: openClawImages.map(\.label),
            userPrompt: userPrompt
        )

        ClickyAgentTurnDiagnostics.logProviderRequest(
            backendLabel: backend.displayName,
            systemPrompt: request.systemPrompt,
            userPrompt: userPrompt,
            conversationHistoryCount: request.conversationHistory.count,
            imageLabels: request.imageAttachments.map(\.label),
            extraContext: """
            sessionKey=\(configuration.sessionKey)
            shellIdentifier=\(configuration.shellIdentifier)
            agentIdentifier=\(configuration.agentIdentifier)
            """
        )
        ClickyComputerUseDebugTrace.shared.recordOpenClawDispatch(
            sessionKey: configuration.sessionKey,
            shellIdentifier: configuration.shellIdentifier,
            agentIdentifier: configuration.agentIdentifier,
            systemPrompt: request.systemPrompt,
            userPrompt: userPrompt,
            imageLabels: openClawImages.map(\.label),
            messageBody: messageBody
        )

        let response = try await gatewayAgent.analyzeImageStreaming(
            gatewayURLString: configuration.gatewayURLString,
            explicitGatewayAuthToken: configuration.gatewayAuthToken,
            configuredAgentIdentifier: configuration.agentIdentifier,
            configuredSessionKey: configuration.sessionKey,
            shellIdentifier: configuration.shellIdentifier,
            images: openClawImages,
            systemPrompt: request.systemPrompt,
            userPrompt: userPrompt,
            computerUseToolHandler: computerUseToolHandler,
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

    private func buildGatewayMessageBody(
        imageLabels: [String],
        userPrompt: String
    ) -> String {
        var messageSections: [String] = []
        if !imageLabels.isEmpty {
            let formattedLabels = imageLabels.enumerated().map { index, label in
                "attachment \(index + 1): \(label)"
            }.joined(separator: "\n")
            messageSections.append(
                """
                Attached screen captures:
                \(formattedLabels)
                Use the attached images as the current screen context.
                """
            )
        }

        let trimmedUserPrompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUserPrompt.isEmpty {
            messageSections.append(trimmedUserPrompt)
        }
        return messageSections.joined(separator: "\n\n")
    }
}
