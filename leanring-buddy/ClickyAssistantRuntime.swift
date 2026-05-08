//
//  ClickyAssistantRuntime.swift
//  leanring-buddy
//
//  Builds the assistant backend graph shared by normal and tutorial turns.
//

import Foundation

@MainActor
final class ClickyAssistantRuntime {
    let claudeAPI: ClaudeAPI
    let openClawGatewayCompanionAgent = OpenClawGatewayCompanionAgent()
    let codexRuntimeClient = CodexRuntimeClient()

    private let preferences: ClickyPreferencesStore
    private let openClawShellIdentifierProvider: @MainActor @Sendable () -> String

    init(
        preferences: ClickyPreferencesStore,
        openClawShellIdentifierProvider: @escaping @MainActor @Sendable () -> String
    ) {
        self.preferences = preferences
        self.openClawShellIdentifierProvider = openClawShellIdentifierProvider
        self.claudeAPI = ClaudeAPI(
            proxyURL: "\(CompanionRuntimeConfiguration.workerBaseURL)/chat",
            model: preferences.selectedModel
        )
    }

    lazy var turnExecutor: ClickyAssistantTurnExecutor = {
        ClickyAssistantTurnExecutor(providerRegistry: providerRegistry)
    }()

    lazy var responseRepairer = ClickyAssistantResponseRepairer(
        assistantTurnExecutor: turnExecutor
    )

    lazy var responseProcessor = ClickyAssistantResponseProcessor(
        repairer: responseRepairer
    )

    private lazy var providerRegistry = ClickyAssistantProviderRegistry(
        providers: [
            ClaudeAssistantProvider(claudeAPI: claudeAPI),
            CodexAssistantProvider(runtimeClient: codexRuntimeClient),
            OpenClawAssistantProvider(
                gatewayAgent: openClawGatewayCompanionAgent,
                configurationProvider: { [weak self] in
                    guard let self else {
                        return OpenClawAssistantProviderConfiguration(
                            gatewayURLString: "",
                            gatewayAuthToken: nil,
                            agentIdentifier: "",
                            sessionKey: "",
                            shellIdentifier: ""
                        )
                    }

                    return OpenClawAssistantProviderConfiguration(
                        gatewayURLString: self.preferences.openClawGatewayURL,
                        gatewayAuthToken: self.preferences.openClawGatewayAuthToken,
                        agentIdentifier: self.preferences.openClawAgentIdentifier,
                        sessionKey: self.preferences.openClawSessionKey,
                        shellIdentifier: self.openClawShellIdentifierProvider()
                    )
                }
            ),
        ]
    )
}
