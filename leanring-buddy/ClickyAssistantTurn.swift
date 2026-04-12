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

struct ClickyAssistantTurnRequest: Sendable {
    let systemPrompt: String
    let userPrompt: String
    let conversationHistory: [ClickyAssistantConversationTurn]
    let imageAttachments: [ClickyAssistantImageAttachment]
    let focusContext: ClickyAssistantFocusContext?
}

struct ClickyAssistantTurnResponse: Sendable {
    let text: String
    let duration: TimeInterval
}
