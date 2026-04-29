//
//  ClickyOpenClawStudioCoordinator.swift
//  leanring-buddy
//
//  Owns OpenClaw Studio-facing readiness, plugin, and identity helpers.
//

import Foundation

@MainActor
final class ClickyOpenClawStudioCoordinator {
    private let preferences: ClickyPreferencesStore
    private let backendRoutingController: ClickyBackendRoutingController
    private let gatewayAgent: OpenClawGatewayCompanionAgent
    private let shellLifecycleController: ClickyOpenClawShellLifecycleController
    private let selectedBackendProvider: () -> CompanionAgentBackend

    init(
        preferences: ClickyPreferencesStore,
        backendRoutingController: ClickyBackendRoutingController,
        gatewayAgent: OpenClawGatewayCompanionAgent,
        shellLifecycleController: ClickyOpenClawShellLifecycleController,
        selectedBackendProvider: @escaping () -> CompanionAgentBackend
    ) {
        self.preferences = preferences
        self.backendRoutingController = backendRoutingController
        self.gatewayAgent = gatewayAgent
        self.shellLifecycleController = shellLifecycleController
        self.selectedBackendProvider = selectedBackendProvider
    }

    var gatewayAuthSummary: String {
        Self.gatewayAuthSummary(explicitGatewayAuthToken: preferences.openClawGatewayAuthToken)
    }

    var isGatewayRemote: Bool {
        Self.isGatewayRemote(preferences.openClawGatewayURL)
    }

    var pluginIdentifier: String {
        Self.pluginIdentifier
    }

    var pluginStatus: ClickyOpenClawPluginStatus {
        Self.pluginStatus(openClawConfiguration: Self.loadLocalOpenClawConfiguration())
    }

    var pluginStatusLabel: String {
        Self.pluginStatusLabel(for: pluginStatus)
    }

    var pluginInstallPathHint: String {
        Self.pluginInstallPathHint()
    }

    var pluginInstallCommand: String {
        "openclaw plugins install \(pluginInstallPathHint)"
    }

    var pluginEnableCommand: String {
        "openclaw plugins enable \(pluginIdentifier) && openclaw gateway restart"
    }

    var remoteReadinessSummary: String {
        Self.remoteReadinessSummary(
            gatewayURLString: preferences.openClawGatewayURL,
            explicitGatewayAuthToken: preferences.openClawGatewayAuthToken
        )
    }

    var shellRegistrationStatusLabel: String {
        Self.shellRegistrationStatusLabel(for: backendRoutingController.clickyShellRegistrationStatus)
    }

    var shellServerSessionKeyLabel: String {
        backendRoutingController.clickyShellServerSessionKey ?? "No session bound yet"
    }

    var shellServerFreshnessLabel: String {
        backendRoutingController.clickyShellServerFreshnessState ?? "unknown"
    }

    var shellServerTrustLabel: String {
        backendRoutingController.clickyShellServerTrustState ?? "unknown"
    }

    var shellServerBindingLabel: String {
        backendRoutingController.clickyShellServerSessionBindingState ?? "unknown"
    }

    var effectiveAgentName: String {
        Self.effectiveAgentName(
            manualName: preferences.openClawAgentName,
            inferredName: backendRoutingController.inferredOpenClawAgentIdentityName
        )
    }

    var inferredIdentityDisplayName: String {
        Self.inferredIdentityDisplayName(
            emoji: backendRoutingController.inferredOpenClawAgentIdentityEmoji,
            name: backendRoutingController.inferredOpenClawAgentIdentityName
        )
    }

    var inferredIdentityEmojiLabel: String {
        Self.inferredIdentityEmojiLabel(backendRoutingController.inferredOpenClawAgentIdentityEmoji)
    }

    var inferredIdentityAvatarLabel: String {
        Self.inferredIdentityAvatarLabel(backendRoutingController.inferredOpenClawAgentIdentityAvatar)
    }

    func testConnection() {
        if case .testing = backendRoutingController.openClawConnectionStatus {
            return
        }

        backendRoutingController.openClawConnectionStatus = .testing

        Task { @MainActor in
            do {
                let summary = try await gatewayAgent.testConnection(
                    gatewayURLString: preferences.openClawGatewayURL,
                    explicitGatewayAuthToken: preferences.openClawGatewayAuthToken
                )
                backendRoutingController.openClawConnectionStatus = .connected(summary: summary)
                ClickyLogger.notice(.gateway, "OpenClaw connection test succeeded summary=\(summary)")
                refreshAgentIdentity()
            } catch {
                backendRoutingController.openClawConnectionStatus = .failed(message: error.localizedDescription)
                ClickyLogger.error(.gateway, "OpenClaw connection test failed error=\(error.localizedDescription)")
            }
        }
    }

    func registerShellNow() {
        if selectedBackendProvider() != .openClaw {
            backendRoutingController.clickyShellRegistrationStatus = .failed(message: "Switch the Agent backend to OpenClaw before registering the Clicky shell.")
            ClickyLogger.error(.plugin, "Shell registration blocked because backend is not OpenClaw")
            return
        }

        if preferences.openClawGatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            backendRoutingController.clickyShellRegistrationStatus = .failed(message: "Set an OpenClaw Gateway URL before registering the Clicky shell.")
            ClickyLogger.error(.plugin, "Shell registration blocked because gateway URL is empty")
            return
        }

        if !isGatewayRemote && pluginStatus != .enabled {
            backendRoutingController.clickyShellRegistrationStatus = .failed(message: "Enable the local clicky-shell plugin first, then try registering again.")
            ClickyLogger.error(.plugin, "Shell registration blocked because clicky-shell plugin is not enabled")
            return
        }

        shellLifecycleController.registerNow()
    }

    func refreshShellStatusNow() {
        shellLifecycleController.refreshStatusNow()
    }

    func refreshAgentIdentity() {
        guard selectedBackendProvider() == .openClaw else { return }
        guard !preferences.openClawGatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task { @MainActor in
            do {
                let agentIdentitySnapshot = try await gatewayAgent.fetchAgentIdentity(
                    gatewayURLString: preferences.openClawGatewayURL,
                    explicitGatewayAuthToken: preferences.openClawGatewayAuthToken,
                    agentIdentifier: trimmedNilIfEmpty(preferences.openClawAgentIdentifier),
                    sessionKey: trimmedNilIfEmpty(preferences.openClawSessionKey)
                )

                backendRoutingController.inferredOpenClawAgentIdentityName = agentIdentitySnapshot.name
                backendRoutingController.inferredOpenClawAgentIdentityEmoji = agentIdentitySnapshot.emoji
                backendRoutingController.inferredOpenClawAgentIdentityAvatar = agentIdentitySnapshot.avatar
                backendRoutingController.inferredOpenClawAgentIdentifier = agentIdentitySnapshot.agentIdentifier
                ClickyLogger.info(.gateway, "Fetched OpenClaw identity name=\(agentIdentitySnapshot.name ?? "unknown")")

                if preferences.openClawAgentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let inferredAgentIdentifier = agentIdentitySnapshot.agentIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !inferredAgentIdentifier.isEmpty {
                    preferences.openClawAgentIdentifier = inferredAgentIdentifier
                }

                if preferences.openClawAgentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let inferredAgentIdentityName = agentIdentitySnapshot.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !inferredAgentIdentityName.isEmpty {
                    preferences.openClawAgentName = inferredAgentIdentityName
                }
            } catch {
                backendRoutingController.inferredOpenClawAgentIdentityAvatar = nil
                backendRoutingController.inferredOpenClawAgentIdentifier = nil
                backendRoutingController.inferredOpenClawAgentIdentityName = nil
                backendRoutingController.inferredOpenClawAgentIdentityEmoji = nil
            }
        }
    }

    static let pluginIdentifier = "clicky-shell"

    static func gatewayAuthSummary(explicitGatewayAuthToken: String) -> String {
        if !explicitGatewayAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Using token from Studio settings"
        }

        return OpenClawGatewayCompanionAgent.localGatewayAuthTokenSummary()
    }

    static func isGatewayRemote(_ gatewayURLString: String) -> Bool {
        guard let gatewayURL = URL(string: gatewayURLString),
              let host = gatewayURL.host?.lowercased() else {
            return false
        }

        return gatewayURL.scheme == "wss"
            || !(host == "127.0.0.1" || host == "localhost" || host == "::1")
    }

    static func pluginStatus(openClawConfiguration: [String: Any]?) -> ClickyOpenClawPluginStatus {
        guard let plugins = openClawConfiguration?["plugins"] as? [String: Any],
              let entries = plugins["entries"] as? [String: Any],
              let clickyEntry = entries[pluginIdentifier] as? [String: Any] else {
            return .notConfigured
        }

        let isEnabled = (clickyEntry["enabled"] as? Bool) ?? false
        return isEnabled ? .enabled : .disabled
    }

    static func pluginStatusLabel(for status: ClickyOpenClawPluginStatus) -> String {
        switch status {
        case .enabled:
            return "Enabled in local OpenClaw config"
        case .disabled:
            return "Installed but disabled"
        case .notConfigured:
            return "Not configured in local OpenClaw yet"
        }
    }

    static func pluginInstallPathHint() -> String {
        #if DEBUG
        let repositoryRootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repositoryRootURL.appendingPathComponent("plugins/openclaw-clicky-shell").path
        #else
        return "/path/to/clicky-decocereus/plugins/openclaw-clicky-shell"
        #endif
    }

    static func remoteReadinessSummary(
        gatewayURLString: String,
        explicitGatewayAuthToken: String
    ) -> String {
        if isGatewayRemote(gatewayURLString) {
            if !explicitGatewayAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Remote Gateway is configured with an explicit Studio token."
            }

            return "Remote Gateway URL is set. Add a Studio token if the remote host does not share your local ~/.openclaw auth."
        }

        return "Local Gateway is ready. Remote-ready mode works once you switch the Gateway URL to wss:// and provide a valid token."
    }

    static func shellRegistrationStatusLabel(for status: ClickyShellRegistrationStatus) -> String {
        switch status {
        case .idle:
            return "Shell not registered yet"
        case .registering:
            return "Registering Clicky shell"
        case .registered:
            return "Shell registered"
        case .failed:
            return "Shell registration failed"
        }
    }

    static func effectiveAgentName(manualName: String, inferredName: String?) -> String {
        let manualName = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manualName.isEmpty {
            return manualName
        }

        let inferredName = inferredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !inferredName.isEmpty {
            return inferredName
        }

        return "your OpenClaw agent"
    }

    static func inferredIdentityDisplayName(emoji: String?, name: String?) -> String {
        let emojiPrefix = emoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let identityName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !emojiPrefix.isEmpty && !identityName.isEmpty {
            return "\(emojiPrefix) \(identityName)"
        }

        if !identityName.isEmpty {
            return identityName
        }

        return "Not detected yet"
    }

    static func inferredIdentityEmojiLabel(_ emoji: String?) -> String {
        let emojiValue = emoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return emojiValue.isEmpty ? "No emoji provided by OpenClaw" : emojiValue
    }

    static func inferredIdentityAvatarLabel(_ avatar: String?) -> String {
        let avatarValue = avatar?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return avatarValue.isEmpty ? "No avatar provided by OpenClaw" : "Avatar available from OpenClaw"
    }

    private static func loadLocalOpenClawConfiguration() -> [String: Any]? {
        let openClawHomeDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw", isDirectory: true)
        let configurationFileURL = openClawHomeDirectoryURL.appendingPathComponent("openclaw.json")

        guard let configurationData = try? Data(contentsOf: configurationFileURL),
              let configurationJSON = try? JSONSerialization.jsonObject(with: configurationData) as? [String: Any] else {
            return nil
        }

        return configurationJSON
    }

    private func trimmedNilIfEmpty(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
