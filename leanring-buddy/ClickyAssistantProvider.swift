//
//  ClickyAssistantProvider.swift
//  leanring-buddy
//
//  Provider adapter interface for mapping Clicky's canonical assistant
//  turn contract onto backend-specific transports.
//

import Foundation

protocol ClickyAssistantProvider: AnyObject {
    var backend: CompanionAgentBackend { get }

    func sendTurn(
        _ request: ClickyAssistantTurnRequest,
        onTextChunk: @MainActor @escaping @Sendable (String) -> Void
    ) async throws -> ClickyAssistantTurnResponse
}
