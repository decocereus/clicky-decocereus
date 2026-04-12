//
//  ClickyAssistantProviderRegistry.swift
//  leanring-buddy
//
//  Backend-to-provider lookup for Clicky's canonical assistant contract.
//

import Foundation

final class ClickyAssistantProviderRegistry {
    private let providersByBackend: [CompanionAgentBackend: ClickyAssistantProvider]

    init(providers: [ClickyAssistantProvider]) {
        var providersByBackend: [CompanionAgentBackend: ClickyAssistantProvider] = [:]
        for provider in providers {
            providersByBackend[provider.backend] = provider
        }
        self.providersByBackend = providersByBackend
    }

    func provider(for backend: CompanionAgentBackend) throws -> ClickyAssistantProvider {
        guard let provider = providersByBackend[backend] else {
            throw NSError(
                domain: "ClickyAssistantProviderRegistry",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No assistant provider is registered for \(backend.displayName)."]
            )
        }

        return provider
    }
}
