//
//  ClickyAssistantTurnPlan.swift
//  leanring-buddy
//
//  Transport-neutral plan for one assistant turn.
//

import Foundation

struct ClickyAssistantTurnPlan: Sendable {
    let backend: CompanionAgentBackend
    let systemPrompt: String
    let request: ClickyAssistantTurnRequest
}
