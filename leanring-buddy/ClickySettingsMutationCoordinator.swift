//
//  ClickySettingsMutationCoordinator.swift
//  leanring-buddy
//
//  Owns settings mutations that have runtime side effects.
//

import Foundation

@MainActor
final class ClickySettingsMutationCoordinator {
    private let preferences: ClickyPreferencesStore
    private let backendRoutingController: ClickyBackendRoutingController
    private let claudeAPI: ClaudeAPI
    private let openClawShellLifecycleController: ClickyOpenClawShellLifecycleController
    private let refreshOpenClawAgentIdentity: () -> Void
    private let refreshCodexRuntimeStatus: () -> Void

    init(
        preferences: ClickyPreferencesStore,
        backendRoutingController: ClickyBackendRoutingController,
        claudeAPI: ClaudeAPI,
        openClawShellLifecycleController: ClickyOpenClawShellLifecycleController,
        refreshOpenClawAgentIdentity: @escaping () -> Void,
        refreshCodexRuntimeStatus: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.backendRoutingController = backendRoutingController
        self.claudeAPI = claudeAPI
        self.openClawShellLifecycleController = openClawShellLifecycleController
        self.refreshOpenClawAgentIdentity = refreshOpenClawAgentIdentity
        self.refreshCodexRuntimeStatus = refreshCodexRuntimeStatus
    }

    func setPersonaPreset(_ preset: ClickyPersonaPreset) {
        preferences.clickyPersonaPreset = preset
        preferences.clickyThemePreset = preset.definition.defaultThemePreset
        preferences.clickyVoicePreset = preset.definition.defaultVoicePreset
        preferences.clickyCursorStyle = preset.definition.defaultCursorStyle
    }

    func setSelectedModel(_ model: String) {
        guard preferences.selectedModel != model else { return }
        preferences.selectedModel = model
        UserDefaults.standard.set(model, forKey: "selectedClaudeModel")
        claudeAPI.model = model
    }

    func setSelectedBackend(_ selectedBackend: CompanionAgentBackend) {
        guard preferences.selectedAgentBackend != selectedBackend else { return }
        preferences.selectedAgentBackend = selectedBackend
        openClawShellLifecycleController.refreshLifecycle()
        refreshOpenClawAgentIdentity()
        refreshCodexRuntimeStatus()
    }

    func setOpenClawGatewayURL(_ gatewayURL: String) {
        guard preferences.openClawGatewayURL != gatewayURL else { return }
        preferences.openClawGatewayURL = gatewayURL
        refreshGatewaySensitiveOpenClawState()
    }

    func setOpenClawAgentIdentifier(_ agentIdentifier: String) {
        guard preferences.openClawAgentIdentifier != agentIdentifier else { return }
        preferences.openClawAgentIdentifier = agentIdentifier
        refreshOpenClawAgentIdentity()
    }

    func setOpenClawGatewayAuthToken(_ authToken: String) {
        guard preferences.openClawGatewayAuthToken != authToken else { return }
        preferences.openClawGatewayAuthToken = authToken
        refreshGatewaySensitiveOpenClawState()
    }

    func setOpenClawSessionKey(_ sessionKey: String) {
        guard preferences.openClawSessionKey != sessionKey else { return }
        preferences.openClawSessionKey = sessionKey
        backendRoutingController.openClawConnectionStatus = .idle

        if case .registered = backendRoutingController.clickyShellRegistrationStatus {
            openClawShellLifecycleController.bindSession()
        } else {
            openClawShellLifecycleController.refreshLifecycle()
        }

        refreshOpenClawAgentIdentity()
    }

    private func refreshGatewaySensitiveOpenClawState() {
        backendRoutingController.openClawConnectionStatus = .idle
        openClawShellLifecycleController.refreshLifecycle()
        refreshOpenClawAgentIdentity()
    }
}
