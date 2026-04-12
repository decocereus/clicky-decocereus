//
//  ClickyAssistantTurnExecutor.swift
//  leanring-buddy
//
//  Executes canonical assistant turn plans through the registered backend adapters.
//

import Foundation

final class ClickyAssistantTurnExecutor {
    private let providerRegistry: ClickyAssistantProviderRegistry

    init(providerRegistry: ClickyAssistantProviderRegistry) {
        self.providerRegistry = providerRegistry
    }

    func execute(
        _ plan: ClickyAssistantTurnPlan,
        onTextChunk: @MainActor @escaping @Sendable (String) -> Void
    ) async throws -> ClickyAssistantTurnResponse {
        let provider = try providerRegistry.provider(for: plan.backend)
        return try await provider.sendTurn(plan.request, onTextChunk: onTextChunk)
    }
}
