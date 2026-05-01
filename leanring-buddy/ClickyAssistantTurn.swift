//
//  ClickyAssistantTurn.swift
//  leanring-buddy
//
//  Canonical provider-agnostic assistant turn contract for Clicky.
//

import Foundation

struct ClickyAssistantConversationTurn: Sendable {
    let userText: String
    let assistantText: String
}

struct ClickyAssistantImageAttachment: Sendable {
    let data: Data
    let label: String
    let mimeType: String?
}

struct ClickyAssistantMCPServerConfiguration: Sendable {
    let name: String
    let commandPath: String
    let arguments: [String]
    let workingDirectoryPath: String?
    let instructionResourceURI: String
}

struct ClickyAssistantTurnRequest: Sendable {
    let systemPrompt: String
    let userPrompt: String
    let conversationHistory: [ClickyAssistantConversationTurn]
    let imageAttachments: [ClickyAssistantImageAttachment]
    let focusContext: ClickyAssistantFocusContext?
    let mcpServers: [ClickyAssistantMCPServerConfiguration]
}

struct ClickyAssistantTurnResponse: Sendable {
    let text: String
    let duration: TimeInterval
}
