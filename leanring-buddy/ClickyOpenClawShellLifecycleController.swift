//
//  ClickyOpenClawShellLifecycleController.swift
//  leanring-buddy
//
//  Owns Clicky's OpenClaw shell registration lifecycle.
//

import Foundation

@MainActor
protocol ClickyOpenClawShellGateway {
    func registerShell(
        gatewayURLString: String,
        explicitGatewayAuthToken: String?,
        payload: OpenClawShellRegistrationPayload
    ) async throws -> String

    func sendShellHeartbeat(
        gatewayURLString: String,
        explicitGatewayAuthToken: String?,
        shellIdentifier: String
    ) async throws

    func fetchShellStatus(
        gatewayURLString: String,
        explicitGatewayAuthToken: String?,
        shellIdentifier: String
    ) async throws -> OpenClawShellStatusSnapshot

    func bindShellSession(
        gatewayURLString: String,
        explicitGatewayAuthToken: String?,
        shellIdentifier: String,
        sessionKey: String?
    ) async throws -> OpenClawShellStatusSnapshot
}

extension OpenClawGatewayCompanionAgent: ClickyOpenClawShellGateway {}

struct ClickyOpenClawShellLifecycleConfiguration {
    let selectedBackend: CompanionAgentBackend
    let gatewayURL: String
    let gatewayAuthToken: String
    let isGatewayRemote: Bool
    let isLocalPluginEnabled: Bool
    let effectiveAgentName: String
    let effectivePresentationName: String
    let personaScopeMode: ClickyPersonaScopeMode
    let sessionKey: String
}

@MainActor
final class ClickyOpenClawShellLifecycleController {
    private let gatewayAgent: ClickyOpenClawShellGateway
    private let routingController: ClickyBackendRoutingController
    private let configurationProvider: () -> ClickyOpenClawShellLifecycleConfiguration

    private var heartbeatTimer: Timer?
    private var registrationRetryTask: Task<Void, Never>?
    private var isRegistrationInFlight = false
    private var isHeartbeatInFlight = false

    init(
        gatewayAgent: ClickyOpenClawShellGateway,
        routingController: ClickyBackendRoutingController,
        configurationProvider: @escaping () -> ClickyOpenClawShellLifecycleConfiguration
    ) {
        self.gatewayAgent = gatewayAgent
        self.routingController = routingController
        self.configurationProvider = configurationProvider
    }

    var shellIdentifier: String {
        if let persistedIdentifier = UserDefaults.standard.string(forKey: "clickyShellIdentifier"),
           !persistedIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return persistedIdentifier
        }

        let generatedIdentifier = "clicky-shell-\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(generatedIdentifier, forKey: "clickyShellIdentifier")
        return generatedIdentifier
    }

    func registerNow() {
        let configuration = configurationProvider()
        if configuration.selectedBackend != .openClaw {
            routingController.clickyShellRegistrationStatus = .failed(message: "Switch the Agent backend to OpenClaw before registering the Clicky shell.")
            ClickyLogger.error(.plugin, "Shell registration blocked because backend is not OpenClaw")
            return
        }

        if configuration.gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            routingController.clickyShellRegistrationStatus = .failed(message: "Set an OpenClaw Gateway URL before registering the Clicky shell.")
            ClickyLogger.error(.plugin, "Shell registration blocked because gateway URL is empty")
            return
        }

        if !configuration.isGatewayRemote && !configuration.isLocalPluginEnabled {
            routingController.clickyShellRegistrationStatus = .failed(message: "Enable the local clicky-shell plugin first, then try registering again.")
            ClickyLogger.error(.plugin, "Shell registration blocked because clicky-shell plugin is not enabled")
            return
        }

        attemptRegistration()
    }

    func refreshStatusNow() {
        fetchServerStatus()
    }

    func bindSession() {
        guard shouldAttemptRegistration else { return }

        let configuration = configurationProvider()
        Task { @MainActor in
            do {
                let status = try await gatewayAgent.bindShellSession(
                    gatewayURLString: configuration.gatewayURL,
                    explicitGatewayAuthToken: configuration.gatewayAuthToken,
                    shellIdentifier: shellIdentifier,
                    sessionKey: normalizedSessionKey(configuration.sessionKey)
                )

                applyServerStatus(status)
            } catch {
                routingController.clickyShellRegistrationStatus = .failed(message: error.localizedDescription)
            }
        }
    }

    func refreshLifecycle() {
        stop()

        guard shouldAttemptRegistration else {
            routingController.clickyShellRegistrationStatus = .idle
            routingController.clickyShellServerFreshnessState = nil
            routingController.clickyShellServerStatusSummary = nil
            routingController.clickyShellServerSessionBindingState = nil
            routingController.clickyShellServerSessionKey = nil
            routingController.clickyShellServerTrustState = nil
            return
        }

        attemptRegistration()
    }

    func stop() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        registrationRetryTask?.cancel()
        registrationRetryTask = nil
        isRegistrationInFlight = false
        isHeartbeatInFlight = false
    }

    private var shouldAttemptRegistration: Bool {
        let configuration = configurationProvider()
        guard configuration.selectedBackend == .openClaw else { return false }
        guard !configuration.gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        if configuration.isGatewayRemote {
            return true
        }

        return configuration.isLocalPluginEnabled
    }

    private func attemptRegistration() {
        guard shouldAttemptRegistration else { return }
        guard !isRegistrationInFlight else { return }

        isRegistrationInFlight = true
        routingController.clickyShellRegistrationStatus = .registering

        let configuration = configurationProvider()
        let payload = OpenClawShellRegistrationPayload(
            agentIdentityName: configuration.effectiveAgentName,
            shellIdentifier: shellIdentifier,
            shellLabel: shellLabel,
            bridgeVersion: bridgeVersion,
            cursorPointingProtocol: ClickyShellCapabilities.cursorPointingProtocol,
            capabilities: ClickyShellCapabilities.capabilityIdentifiers,
            clickyShellCapabilityVersion: ClickyShellCapabilities.shellCapabilityVersion,
            clickyPresentationName: configuration.effectivePresentationName,
            personaScope: configuration.personaScopeMode == .overrideInClicky ? "clicky-local-override" : "openclaw-identity",
            runtimeMode: runtimeMode,
            screenContextTransport: ClickyShellCapabilities.screenContextTransport,
            sessionKey: normalizedSessionKey(configuration.sessionKey),
            shellProtocolVersion: ClickyShellCapabilities.shellProtocolVersion,
            speechOutputMode: ClickyShellCapabilities.speechOutputMode,
            supportsInlineTextBubble: ClickyShellCapabilities.supportsInlineTextBubble,
            registeredAtMilliseconds: Int(Date().timeIntervalSince1970 * 1000)
        )

        Task { @MainActor in
            defer {
                isRegistrationInFlight = false
            }

            do {
                let summary = try await gatewayAgent.registerShell(
                    gatewayURLString: configuration.gatewayURL,
                    explicitGatewayAuthToken: configuration.gatewayAuthToken,
                    payload: payload
                )

                routingController.clickyShellRegistrationStatus = .registered(summary: summary)
                registrationRetryTask?.cancel()
                registrationRetryTask = nil
                routingController.clickyShellServerFreshnessState = "fresh"
                routingController.clickyShellServerStatusSummary = summary
                routingController.clickyShellServerSessionBindingState = payload.sessionKey == nil ? "unbound" : "bound"
                routingController.clickyShellServerSessionKey = payload.sessionKey
                routingController.clickyShellServerTrustState = configuration.isGatewayRemote ? "trusted-remote" : "trusted-local"
                ClickyLogger.debug(.plugin, "Clicky shell registered summary=\(summary)")
                startHeartbeatTimer()
                fetchServerStatus()
            } catch {
                routingController.clickyShellRegistrationStatus = .failed(message: error.localizedDescription)
                ClickyLogger.error(.plugin, "Clicky shell registration failed error=\(error.localizedDescription)")
                scheduleRegistrationRetry()
            }
        }
    }

    private func scheduleRegistrationRetry() {
        guard shouldAttemptRegistration else { return }
        guard registrationRetryTask == nil else { return }

        registrationRetryTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            registrationRetryTask = nil

            guard !Task.isCancelled else { return }
            guard shouldAttemptRegistration else { return }

            attemptRegistration()
        }
    }

    private func startHeartbeatTimer() {
        heartbeatTimer?.invalidate()

        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.sendHeartbeat()
            }
        }
    }

    private func sendHeartbeat() async {
        guard shouldAttemptRegistration else { return }
        guard !isRegistrationInFlight else { return }
        guard !isHeartbeatInFlight else { return }

        isHeartbeatInFlight = true
        defer {
            isHeartbeatInFlight = false
        }

        let configuration = configurationProvider()
        do {
            try await gatewayAgent.sendShellHeartbeat(
                gatewayURLString: configuration.gatewayURL,
                explicitGatewayAuthToken: configuration.gatewayAuthToken,
                shellIdentifier: shellIdentifier
            )
            ClickyLogger.debug(.plugin, "Clicky shell heartbeat sent shellId=\(shellIdentifier)")
        } catch {
            routingController.clickyShellRegistrationStatus = .failed(message: error.localizedDescription)
            ClickyLogger.error(.plugin, "Clicky shell heartbeat failed error=\(error.localizedDescription)")
            heartbeatTimer?.invalidate()
            heartbeatTimer = nil
            scheduleRegistrationRetry()
        }
    }

    private func fetchServerStatus() {
        guard shouldAttemptRegistration else { return }

        let configuration = configurationProvider()
        Task { @MainActor in
            do {
                let status = try await gatewayAgent.fetchShellStatus(
                    gatewayURLString: configuration.gatewayURL,
                    explicitGatewayAuthToken: configuration.gatewayAuthToken,
                    shellIdentifier: shellIdentifier
                )

                applyServerStatus(status)
            } catch {
                routingController.clickyShellServerStatusSummary = error.localizedDescription
            }
        }
    }

    private func applyServerStatus(_ status: OpenClawShellStatusSnapshot) {
        routingController.clickyShellServerStatusSummary = status.summary
        routingController.clickyShellServerFreshnessState = status.freshnessState
        routingController.clickyShellServerSessionBindingState = status.sessionBindingState
        routingController.clickyShellServerSessionKey = status.sessionKey
        routingController.clickyShellServerTrustState = status.trustState
    }

    private var shellLabel: String {
        let hostName = Host.current().localizedName ?? "This Mac"
        return "Clicky on \(hostName)"
    }

    private var bridgeVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var runtimeMode: String {
        #if DEBUG
        return "debug"
        #else
        return "production"
        #endif
    }

    private func normalizedSessionKey(_ sessionKey: String) -> String? {
        let trimmed = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
