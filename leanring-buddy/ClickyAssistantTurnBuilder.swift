//
//  ClickyAssistantTurnBuilder.swift
//  leanring-buddy
//
//  Builds Clicky's canonical assistant turn request from app-owned context.
//

import Foundation

struct ClickyAssistantLabeledImage: Sendable {
    let data: Data
    let label: String
    let mimeType: String?
}

struct ClickyAssistantTurnBuilder {
    func buildRequest(
        systemPrompt: String,
        userPrompt: String,
        conversationHistory: [(userTranscript: String, assistantResponse: String)],
        labeledImages: [ClickyAssistantLabeledImage],
        focusContext: ClickyAssistantFocusContext?,
        mcpServers: [ClickyAssistantMCPServerConfiguration] = []
    ) -> ClickyAssistantTurnRequest {
        ClickyAssistantTurnRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            conversationHistory: conversationHistory.map { exchange in
                ClickyAssistantConversationTurn(
                    userText: exchange.userTranscript,
                    assistantText: exchange.assistantResponse
                )
            },
            imageAttachments: labeledImages.map { labeledImage in
                ClickyAssistantImageAttachment(
                    data: labeledImage.data,
                    label: labeledImage.label,
                    mimeType: labeledImage.mimeType
                )
            },
            focusContext: focusContext,
            mcpServers: mcpServers
        )
    }
}
