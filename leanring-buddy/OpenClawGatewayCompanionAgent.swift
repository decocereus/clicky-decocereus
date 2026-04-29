//
//  OpenClawGatewayCompanionAgent.swift
//  leanring-buddy
//
//  Minimal OpenClaw Gateway client for routing the companion's
//  transcript + screenshots through an existing OpenClaw agent.
//

import CryptoKit
import Foundation

struct OpenClawGatewayImageAttachment {
    let imageData: Data
    let label: String
    let mimeType: String
}

struct OpenClawShellRegistrationPayload {
    let agentIdentityName: String?
    let shellIdentifier: String
    let shellLabel: String
    let bridgeVersion: String
    let cursorPointingProtocol: String
    let capabilities: [String]
    let clickyShellCapabilityVersion: String
    let clickyPresentationName: String?
    let personaScope: String
    let runtimeMode: String
    let screenContextTransport: String
    let sessionKey: String?
    let shellProtocolVersion: String
    let speechOutputMode: String
    let supportsInlineTextBubble: Bool
    let registeredAtMilliseconds: Int
}

struct OpenClawShellStatusSnapshot {
    let freshnessState: String?
    let isRegistered: Bool
    let agentIdentityName: String?
    let clickyPresentationName: String?
    let personaScope: String?
    let sessionKey: String?
    let summary: String
    let sessionBindingState: String?
    let trustState: String?
}

struct OpenClawAgentIdentitySnapshot {
    let agentIdentifier: String?
    let avatar: String?
    let emoji: String?
    let name: String?
}

struct OpenClawComputerUseToolRequest: @unchecked Sendable {
    let requestIdentifier: String
    let route: String
    let payload: [String: Any]
    let statusText: String?
}

private struct OpenClawGatewayDeviceIdentity {
    let deviceIdentifier: String
    let publicKeyRawBase64URL: String
    let privateKey: Curve25519.Signing.PrivateKey

    static func makeEphemeral() -> OpenClawGatewayDeviceIdentity {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyRawData = privateKey.publicKey.rawRepresentation
        let publicKeyHash = SHA256.hash(data: publicKeyRawData)
        let deviceIdentifier = publicKeyHash.map { String(format: "%02x", $0) }.joined()

        return OpenClawGatewayDeviceIdentity(
            deviceIdentifier: deviceIdentifier,
            publicKeyRawBase64URL: base64URLEncodedString(data: publicKeyRawData),
            privateKey: privateKey
        )
    }
}

private func base64URLEncodedString(data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

actor OpenClawGatewayCompanionAgentSessionState {
    private var pendingResponses: [String: CheckedContinuation<[String: Any], Error>] = [:]
    private var connectChallengeContinuation: CheckedContinuation<String, Error>?
    private var trackedRunIdentifier: String?
    private var accumulatedAssistantText = ""
    private var lifecycleErrorMessage: String?

    func registerPendingResponse(
        requestIdentifier: String,
        continuation: CheckedContinuation<[String: Any], Error>
    ) {
        pendingResponses[requestIdentifier] = continuation
    }

    func resolvePendingResponse(
        requestIdentifier: String,
        payload: [String: Any]
    ) {
        guard let continuation = pendingResponses.removeValue(forKey: requestIdentifier) else { return }
        continuation.resume(returning: payload)
    }

    func rejectPendingResponse(
        requestIdentifier: String,
        error: Error
    ) {
        guard let continuation = pendingResponses.removeValue(forKey: requestIdentifier) else { return }
        continuation.resume(throwing: error)
    }

    func failAll(error: Error) {
        let continuations = pendingResponses.values
        pendingResponses.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: error)
        }

        if let connectChallengeContinuation {
            self.connectChallengeContinuation = nil
            connectChallengeContinuation.resume(throwing: error)
        }
    }

    func waitForConnectChallenge() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            connectChallengeContinuation = continuation
        }
    }

    func deliverConnectChallenge(_ nonce: String) {
        guard let connectChallengeContinuation else { return }
        self.connectChallengeContinuation = nil
        connectChallengeContinuation.resume(returning: nonce)
    }

    func setTrackedRunIdentifier(_ trackedRunIdentifier: String) {
        self.trackedRunIdentifier = trackedRunIdentifier
    }

    func clearTrackedRunIdentifier() {
        trackedRunIdentifier = nil
    }

    func handleAgentEventPayload(_ payload: [String: Any]) -> String? {
        guard let runIdentifier = payload["runId"] as? String else { return nil }
        guard trackedRunIdentifier == nil || trackedRunIdentifier == runIdentifier else { return nil }

        if trackedRunIdentifier == nil {
            trackedRunIdentifier = runIdentifier
        }

        let stream = (payload["stream"] as? String ?? "").lowercased()
        let data = payload["data"] as? [String: Any] ?? [:]

        if stream == "assistant" {
            if let delta = data["delta"] as? String, !delta.isEmpty {
                accumulatedAssistantText.append(delta)
                return accumulatedAssistantText
            }

            if let text = data["text"] as? String, !text.isEmpty {
                accumulatedAssistantText = text
                return accumulatedAssistantText
            }
        }

        if stream == "error" {
            lifecycleErrorMessage = (data["error"] as? String) ?? (data["message"] as? String) ?? lifecycleErrorMessage
        }

        if stream == "lifecycle" {
            let phase = (data["phase"] as? String ?? "").lowercased()
            if phase == "error" || phase == "failed" || phase == "cancelled" {
                lifecycleErrorMessage = (data["error"] as? String) ?? (data["message"] as? String) ?? lifecycleErrorMessage
            }
        }

        return nil
    }

    func accumulatedResponseText() -> String {
        accumulatedAssistantText
    }

    func lifecycleError() -> String? {
        lifecycleErrorMessage
    }

    func resetForNextRun() {
        trackedRunIdentifier = nil
        accumulatedAssistantText = ""
        lifecycleErrorMessage = nil
    }
}

final class OpenClawGatewayCompanionAgent {
    private static let defaultGatewayURLString = "ws://127.0.0.1:18789"
    private static let defaultSessionKey = "clicky-companion"
    private static let gatewayProtocolVersion = 3

    private let urlSession: URLSession
    private var activeSession: OpenClawGatewayCompanionRequestSession?

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 180
        urlSession = URLSession(configuration: configuration)
    }

    func cancelActiveRequest() {
        activeSession?.cancel()
        activeSession = nil
    }

    func analyzeImageStreaming(
        gatewayURLString: String,
        explicitGatewayAuthToken: String? = nil,
        configuredAgentIdentifier: String,
        configuredSessionKey: String,
        shellIdentifier: String?,
        images: [OpenClawGatewayImageAttachment],
        systemPrompt: String,
        userPrompt: String,
        computerUseToolHandler: (@MainActor @Sendable (OpenClawComputerUseToolRequest) async -> [String: Any])? = nil,
        onTextChunk: @MainActor @escaping @Sendable (String) -> Void
    ) async throws -> (text: String, duration: TimeInterval) {
        activeSession?.cancel()

        let requestSession = try OpenClawGatewayCompanionRequestSession(
            urlSession: urlSession,
            gatewayURLString: gatewayURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultGatewayURLString
                : gatewayURLString,
            gatewayAuthToken: Self.resolvedGatewayAuthToken(forExplicitGatewayAuthToken: explicitGatewayAuthToken),
            configuredAgentIdentifier: configuredAgentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
            sessionKey: configuredSessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultSessionKey
                : configuredSessionKey.trimmingCharacters(in: .whitespacesAndNewlines),
            shellIdentifier: shellIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            images: images,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            computerUseToolHandler: computerUseToolHandler,
            onTextChunk: onTextChunk
        )

        activeSession = requestSession
        defer {
            if activeSession === requestSession {
                activeSession = nil
            }
        }

        return try await requestSession.run()
    }

    func testConnection(
        gatewayURLString: String,
        explicitGatewayAuthToken: String? = nil
    ) async throws -> String {
        let requestSession = try OpenClawGatewayCompanionRequestSession(
            urlSession: urlSession,
            gatewayURLString: gatewayURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultGatewayURLString
                : gatewayURLString,
            gatewayAuthToken: Self.resolvedGatewayAuthToken(forExplicitGatewayAuthToken: explicitGatewayAuthToken),
            configuredAgentIdentifier: "",
            sessionKey: Self.defaultSessionKey,
            shellIdentifier: nil,
            images: [],
            systemPrompt: "",
            userPrompt: "",
            onTextChunk: { _ in }
        )

        return try await requestSession.runConnectionTest()
    }

    func registerShell(
        gatewayURLString: String,
        explicitGatewayAuthToken: String? = nil,
        payload: OpenClawShellRegistrationPayload
    ) async throws -> String {
        let requestSession = try OpenClawGatewayCompanionRequestSession(
            urlSession: urlSession,
            gatewayURLString: gatewayURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultGatewayURLString
                : gatewayURLString,
            gatewayAuthToken: Self.resolvedGatewayAuthToken(forExplicitGatewayAuthToken: explicitGatewayAuthToken),
            configuredAgentIdentifier: "",
            sessionKey: Self.defaultSessionKey,
            shellIdentifier: nil,
            images: [],
            systemPrompt: "",
            userPrompt: "",
            onTextChunk: { _ in }
        )

        return try await requestSession.runShellRegistration(payload: payload)
    }

    func sendShellHeartbeat(
        gatewayURLString: String,
        explicitGatewayAuthToken: String? = nil,
        shellIdentifier: String
    ) async throws {
        let requestSession = try OpenClawGatewayCompanionRequestSession(
            urlSession: urlSession,
            gatewayURLString: gatewayURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultGatewayURLString
                : gatewayURLString,
            gatewayAuthToken: Self.resolvedGatewayAuthToken(forExplicitGatewayAuthToken: explicitGatewayAuthToken),
            configuredAgentIdentifier: "",
            sessionKey: Self.defaultSessionKey,
            shellIdentifier: nil,
            images: [],
            systemPrompt: "",
            userPrompt: "",
            onTextChunk: { _ in }
        )

        try await requestSession.runShellHeartbeat(shellIdentifier: shellIdentifier)
    }

    func fetchShellStatus(
        gatewayURLString: String,
        explicitGatewayAuthToken: String? = nil,
        shellIdentifier: String
    ) async throws -> OpenClawShellStatusSnapshot {
        let requestSession = try OpenClawGatewayCompanionRequestSession(
            urlSession: urlSession,
            gatewayURLString: gatewayURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultGatewayURLString
                : gatewayURLString,
            gatewayAuthToken: Self.resolvedGatewayAuthToken(forExplicitGatewayAuthToken: explicitGatewayAuthToken),
            configuredAgentIdentifier: "",
            sessionKey: Self.defaultSessionKey,
            shellIdentifier: nil,
            images: [],
            systemPrompt: "",
            userPrompt: "",
            onTextChunk: { _ in }
        )

        return try await requestSession.runShellStatus(shellIdentifier: shellIdentifier)
    }

    func bindShellSession(
        gatewayURLString: String,
        explicitGatewayAuthToken: String? = nil,
        shellIdentifier: String,
        sessionKey: String?
    ) async throws -> OpenClawShellStatusSnapshot {
        let requestSession = try OpenClawGatewayCompanionRequestSession(
            urlSession: urlSession,
            gatewayURLString: gatewayURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultGatewayURLString
                : gatewayURLString,
            gatewayAuthToken: Self.resolvedGatewayAuthToken(forExplicitGatewayAuthToken: explicitGatewayAuthToken),
            configuredAgentIdentifier: "",
            sessionKey: Self.defaultSessionKey,
            shellIdentifier: nil,
            images: [],
            systemPrompt: "",
            userPrompt: "",
            onTextChunk: { _ in }
        )

        return try await requestSession.runShellSessionBinding(
            shellIdentifier: shellIdentifier,
            sessionKey: sessionKey
        )
    }

    func fetchAgentIdentity(
        gatewayURLString: String,
        explicitGatewayAuthToken: String? = nil,
        agentIdentifier: String?,
        sessionKey: String?
    ) async throws -> OpenClawAgentIdentitySnapshot {
        let requestSession = try OpenClawGatewayCompanionRequestSession(
            urlSession: urlSession,
            gatewayURLString: gatewayURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultGatewayURLString
                : gatewayURLString,
            gatewayAuthToken: Self.resolvedGatewayAuthToken(forExplicitGatewayAuthToken: explicitGatewayAuthToken),
            configuredAgentIdentifier: "",
            sessionKey: Self.defaultSessionKey,
            shellIdentifier: nil,
            images: [],
            systemPrompt: "",
            userPrompt: "",
            onTextChunk: { _ in }
        )

        return try await requestSession.runAgentIdentityFetch(
            agentIdentifier: agentIdentifier,
            sessionKey: sessionKey
        )
    }

    static func hasLocalGatewayAuthToken() -> Bool {
        resolveLocalGatewayAuthToken() != nil
    }

    static func localGatewayAuthTokenSummary() -> String {
        if hasLocalGatewayAuthToken() {
            return "Using token from ~/.openclaw/openclaw.json"
        }

        return "No local OpenClaw token found"
    }

    private static func resolvedGatewayAuthToken(forExplicitGatewayAuthToken explicitGatewayAuthToken: String?) -> String? {
        if let explicitGatewayAuthToken,
           !explicitGatewayAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicitGatewayAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return resolveLocalGatewayAuthToken()
    }

    private static func resolveLocalGatewayAuthToken() -> String? {
        let openClawHomeDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw", isDirectory: true)
        let configurationFileURL = openClawHomeDirectoryURL.appendingPathComponent("openclaw.json")

        guard let configurationData = try? Data(contentsOf: configurationFileURL),
              let configurationJSON = try? JSONSerialization.jsonObject(with: configurationData) as? [String: Any] else {
            return nil
        }

        if let gateway = configurationJSON["gateway"] as? [String: Any] {
            if let gatewayAuth = gateway["auth"] as? [String: Any],
               let token = gatewayAuth["token"] as? String,
               !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return token.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let legacyToken = gateway["token"] as? String,
               !legacyToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return legacyToken.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private final class OpenClawGatewayCompanionRequestSession {
        private let urlSession: URLSession
        private let gatewayURL: URL
        private let gatewayAuthToken: String?
        private let configuredAgentIdentifier: String
        private let sessionKey: String
        private let shellIdentifier: String?
        private let images: [OpenClawGatewayImageAttachment]
        private let systemPrompt: String
        private let userPrompt: String
        private let computerUseToolHandler: (@MainActor @Sendable (OpenClawComputerUseToolRequest) async -> [String: Any])?
        private let onTextChunk: @MainActor @Sendable (String) -> Void
        private let state = OpenClawGatewayCompanionAgentSessionState()
        private let deviceIdentity = OpenClawGatewayDeviceIdentity.makeEphemeral()

        private var webSocketTask: URLSessionWebSocketTask?
        private var receiveLoopTask: Task<Void, Never>?
        private var computerUsePollingTask: Task<Void, Never>?

        init(
            urlSession: URLSession,
            gatewayURLString: String,
            gatewayAuthToken: String?,
            configuredAgentIdentifier: String,
            sessionKey: String,
            shellIdentifier: String?,
            images: [OpenClawGatewayImageAttachment],
            systemPrompt: String,
            userPrompt: String,
            computerUseToolHandler: (@MainActor @Sendable (OpenClawComputerUseToolRequest) async -> [String: Any])? = nil,
            onTextChunk: @MainActor @escaping @Sendable (String) -> Void
        ) throws {
            self.urlSession = urlSession
            guard let gatewayURL = URL(string: gatewayURLString) else {
                throw NSError(
                    domain: "OpenClawGatewayCompanionAgent",
                    code: -8,
                    userInfo: [NSLocalizedDescriptionKey: "OpenClaw Gateway URL is invalid."]
                )
            }
            self.gatewayURL = gatewayURL
            self.gatewayAuthToken = gatewayAuthToken
            self.configuredAgentIdentifier = configuredAgentIdentifier
            self.sessionKey = sessionKey
            self.shellIdentifier = shellIdentifier
            self.images = images
            self.systemPrompt = systemPrompt
            self.userPrompt = userPrompt
            self.computerUseToolHandler = computerUseToolHandler
            self.onTextChunk = onTextChunk
        }

        func cancel() {
            receiveLoopTask?.cancel()
            receiveLoopTask = nil
            computerUsePollingTask?.cancel()
            computerUsePollingTask = nil
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil

            Task {
                await state.failAll(error: CancellationError())
                await state.resetForNextRun()
            }
        }

        func run() async throws -> (text: String, duration: TimeInterval) {
            let startTime = Date()
            await state.resetForNextRun()

            _ = try await connect()
            defer { cancel() }

            do {
                _ = try await request(
                    method: "sessions.patch",
                    params: [
                        "key": sessionKey,
                        "execSecurity": "deny",
                        "execAsk": "always",
                    ],
                    timeoutSeconds: 10
                )
            } catch {
                // Clicky computer use should flow through the plugin tools so
                // the app can own policy, progress, and runtime state. Older
                // gateways may not accept this patch, so the prompt/tool
                // contract remains the compatibility boundary.
            }

            let trimmedSystemPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            try await syncShellPromptContext(promptContext: trimmedSystemPrompt)
            startComputerUsePollingIfNeeded()

            let gatewayMessageBody = buildGatewayMessageBody()
            ClickyAgentTurnDiagnostics.logOpenClawGatewayDispatch(
                sessionKey: sessionKey,
                shellIdentifier: shellIdentifier,
                agentIdentifier: configuredAgentIdentifier.isEmpty ? nil : configuredAgentIdentifier,
                promptContext: trimmedSystemPrompt,
                messageBody: gatewayMessageBody
            )

            let agentRequestIdentifier = UUID().uuidString
            let acceptedPayload = try await request(
                method: "agent",
                params: buildAgentParams(
                    idempotencyKey: agentRequestIdentifier,
                    messageBody: gatewayMessageBody
                ),
                timeoutSeconds: 15
            )

            let acceptedRunIdentifier = (acceptedPayload["runId"] as? String) ?? agentRequestIdentifier
            await state.setTrackedRunIdentifier(acceptedRunIdentifier)

            let acceptedStatus = ((acceptedPayload["status"] as? String) ?? "").lowercased()
            ClickyAgentTurnDiagnostics.logOpenClawGatewayRunLifecycle(
                stage: "agent-accepted",
                sessionKey: sessionKey,
                runIdentifier: acceptedRunIdentifier,
                status: acceptedStatus,
                detail: String(describing: acceptedPayload)
            )
            if acceptedStatus != "ok" {
                let waitPayload = try await request(
                    method: "agent.wait",
                    params: [
                        "runId": acceptedRunIdentifier,
                        "timeoutMs": 120_000,
                    ],
                    timeoutSeconds: 130
                )

                let waitStatus = ((waitPayload["status"] as? String) ?? "").lowercased()
                ClickyAgentTurnDiagnostics.logOpenClawGatewayRunLifecycle(
                    stage: "agent-wait",
                    sessionKey: sessionKey,
                    runIdentifier: acceptedRunIdentifier,
                    status: waitStatus,
                    detail: String(describing: waitPayload)
                )
                if waitStatus == "timeout" {
                    throw NSError(
                        domain: "OpenClawGatewayCompanionAgent",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "OpenClaw Gateway run timed out."]
                    )
                }

                if waitStatus == "error" {
                    let lifecycleErrorMessage = await state.lifecycleError()
                    let errorMessage = (waitPayload["error"] as? String)
                        ?? lifecycleErrorMessage
                        ?? "OpenClaw Gateway run failed."
                    throw NSError(
                        domain: "OpenClawGatewayCompanionAgent",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage]
                    )
                }
            }

            let fullResponseText = await state.accumulatedResponseText()
            let lifecycleError = await state.lifecycleError()
            ClickyAgentTurnDiagnostics.logOpenClawGatewayRunLifecycle(
                stage: "agent-finished",
                sessionKey: sessionKey,
                runIdentifier: acceptedRunIdentifier,
                status: fullResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "empty-response" : "text-response",
                detail: lifecycleError ?? "responseLength=\(fullResponseText.count)"
            )
            if fullResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let lifecycleError,
               !lifecycleError.isEmpty {
                throw NSError(
                    domain: "OpenClawGatewayCompanionAgent",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: lifecycleError]
                )
            }

            return (text: fullResponseText, duration: Date().timeIntervalSince(startTime))
        }

        func runConnectionTest() async throws -> String {
            let helloPayload = try await connect()
            defer { cancel() }

            let protocolVersion = helloPayload["protocol"] as? Int ?? 0
            let server = helloPayload["server"] as? [String: Any] ?? [:]
            let serverVersion = (server["version"] as? String) ?? "unknown"
            let connectionIdentifier = (server["connId"] as? String) ?? "unknown"
            return "Connected to OpenClaw Gateway v\(serverVersion) (protocol \(protocolVersion), conn \(connectionIdentifier))"
        }

        func runShellRegistration(payload: OpenClawShellRegistrationPayload) async throws -> String {
            _ = try await connect()
            defer { cancel() }

            let registrationPayload = try await request(
                method: "clicky.shell.register",
                params: [
                    "agentIdentityName": payload.agentIdentityName as Any,
                    "shellId": payload.shellIdentifier,
                    "shellLabel": payload.shellLabel,
                    "bridgeVersion": payload.bridgeVersion,
                    "cursorPointingProtocol": payload.cursorPointingProtocol,
                    "capabilities": payload.capabilities,
                    "clickyShellCapabilityVersion": payload.clickyShellCapabilityVersion,
                    "clickyPresentationName": payload.clickyPresentationName as Any,
                    "personaScope": payload.personaScope,
                    "runtimeMode": payload.runtimeMode,
                    "screenContextTransport": payload.screenContextTransport,
                    "sessionKey": payload.sessionKey as Any,
                    "shellProtocolVersion": payload.shellProtocolVersion,
                    "speechOutputMode": payload.speechOutputMode,
                    "supportsInlineTextBubble": payload.supportsInlineTextBubble,
                    "registeredAt": payload.registeredAtMilliseconds,
                ],
                timeoutSeconds: 15
            )

            if let summary = registrationPayload["summary"] as? String,
               !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return summary
            }

            return "Clicky shell registered with OpenClaw."
        }

        func runShellHeartbeat(shellIdentifier: String) async throws {
            _ = try await connect()
            defer { cancel() }

            _ = try await request(
                method: "clicky.shell.heartbeat",
                params: [
                    "shellId": shellIdentifier,
                ],
                timeoutSeconds: 10
            )
        }

        func runShellStatus(shellIdentifier: String) async throws -> OpenClawShellStatusSnapshot {
            _ = try await connect()
            defer { cancel() }

            let statusPayload = try await request(
                method: "clicky.shell.status",
                params: [
                    "shellId": shellIdentifier,
                ],
                timeoutSeconds: 10
            )

            return OpenClawShellStatusSnapshot(
                freshnessState: ((statusPayload["registration"] as? [String: Any])?["freshnessState"] as? String),
                isRegistered: (statusPayload["found"] as? Bool) ?? false,
                agentIdentityName: ((statusPayload["registration"] as? [String: Any])?["agentIdentityName"] as? String),
                clickyPresentationName: ((statusPayload["registration"] as? [String: Any])?["clickyPresentationName"] as? String),
                personaScope: ((statusPayload["registration"] as? [String: Any])?["personaScope"] as? String),
                sessionKey: ((statusPayload["registration"] as? [String: Any])?["sessionKey"] as? String),
                summary: (statusPayload["summary"] as? String) ?? "No status summary returned.",
                sessionBindingState: ((statusPayload["registration"] as? [String: Any])?["sessionBindingState"] as? String),
                trustState: ((statusPayload["registration"] as? [String: Any])?["trustState"] as? String)
            )
        }

        func runShellSessionBinding(
            shellIdentifier: String,
            sessionKey: String?
        ) async throws -> OpenClawShellStatusSnapshot {
            _ = try await connect()
            defer { cancel() }

            var requestParams: [String: Any] = [
                "shellId": shellIdentifier,
            ]

            if let sessionKey,
               !sessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                requestParams["sessionKey"] = sessionKey
            }

            let bindingPayload = try await request(
                method: "clicky.shell.bind_session",
                params: requestParams,
                timeoutSeconds: 10
            )

            return OpenClawShellStatusSnapshot(
                freshnessState: ((bindingPayload["registration"] as? [String: Any])?["freshnessState"] as? String),
                isRegistered: true,
                agentIdentityName: ((bindingPayload["registration"] as? [String: Any])?["agentIdentityName"] as? String),
                clickyPresentationName: ((bindingPayload["registration"] as? [String: Any])?["clickyPresentationName"] as? String),
                personaScope: ((bindingPayload["registration"] as? [String: Any])?["personaScope"] as? String),
                sessionKey: ((bindingPayload["registration"] as? [String: Any])?["sessionKey"] as? String),
                summary: (bindingPayload["summary"] as? String) ?? "Clicky shell session binding updated.",
                sessionBindingState: ((bindingPayload["registration"] as? [String: Any])?["sessionBindingState"] as? String),
                trustState: ((bindingPayload["registration"] as? [String: Any])?["trustState"] as? String)
            )
        }

        func runAgentIdentityFetch(
            agentIdentifier: String?,
            sessionKey: String?
        ) async throws -> OpenClawAgentIdentitySnapshot {
            _ = try await connect()
            defer { cancel() }

            var requestParams: [String: Any] = [:]

            if let agentIdentifier,
               !agentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                requestParams["agentId"] = agentIdentifier
            }

            if let sessionKey,
               !sessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                requestParams["sessionKey"] = sessionKey
            }

            let identityPayload = try await request(
                method: "agent.identity.get",
                params: requestParams,
                timeoutSeconds: 10
            )

            return OpenClawAgentIdentitySnapshot(
                agentIdentifier: identityPayload["agentId"] as? String,
                avatar: identityPayload["avatar"] as? String,
                emoji: identityPayload["emoji"] as? String,
                name: identityPayload["name"] as? String
            )
        }

        private func connect() async throws -> [String: Any] {
            var webSocketRequest = URLRequest(url: gatewayURL)
            webSocketRequest.timeoutInterval = 15
            let webSocketTask = urlSession.webSocketTask(with: webSocketRequest)
            self.webSocketTask = webSocketTask
            webSocketTask.resume()

            receiveLoopTask = Task {
                await self.receiveMessages()
            }

            let connectChallenge = try await withTimeout(seconds: 15) {
                try await self.state.waitForConnectChallenge()
            }

            return try await request(
                method: "connect",
                params: try buildConnectParams(connectChallenge),
                timeoutSeconds: 15
            )
        }

        private func buildConnectParams(_ challengeNonce: String) throws -> [String: Any] {
            let signedAtMilliseconds = Int(Date().timeIntervalSince1970 * 1000)
            _ = challengeNonce
            let scopes = ["operator.admin", "operator.read", "operator.write"]
            let deviceAuthPayload = [
                "v3",
                deviceIdentity.deviceIdentifier,
                "gateway-client",
                "backend",
                "operator",
                scopes.joined(separator: ","),
                String(signedAtMilliseconds),
                gatewayAuthToken ?? "",
                challengeNonce,
                "darwin",
                "macos",
            ].joined(separator: "|")

            let deviceSignature = base64URLEncodedString(
                data: try deviceIdentity.privateKey.signature(for: Data(deviceAuthPayload.utf8))
            )

            var connectParams: [String: Any] = [
                "minProtocol": OpenClawGatewayCompanionAgent.gatewayProtocolVersion,
                "maxProtocol": OpenClawGatewayCompanionAgent.gatewayProtocolVersion,
                "client": [
                    "id": "gateway-client",
                    "version": "clicky",
                    "platform": "darwin",
                    "mode": "backend",
                    "deviceFamily": "macos",
                ],
                "role": "operator",
                "scopes": scopes,
                "device": [
                    "id": deviceIdentity.deviceIdentifier,
                    "publicKey": deviceIdentity.publicKeyRawBase64URL,
                    "signature": deviceSignature,
                    "signedAt": signedAtMilliseconds,
                    "nonce": challengeNonce,
                ],
            ]

            if let gatewayAuthToken,
               !gatewayAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                connectParams["auth"] = [
                    "token": gatewayAuthToken
                ]
            }

            return connectParams
        }

        private func buildAgentParams(
            idempotencyKey: String,
            messageBody: String
        ) -> [String: Any] {
            var agentParams: [String: Any] = [
                "message": messageBody,
                "sessionKey": sessionKey,
                "idempotencyKey": idempotencyKey,
                "timeout": 120_000,
            ]

            if !configuredAgentIdentifier.isEmpty {
                agentParams["agentId"] = configuredAgentIdentifier
            }

            if !images.isEmpty {
                agentParams["attachments"] = images.map { image in
                    [
                        "mimeType": image.mimeType,
                        "content": image.imageData.base64EncodedString(),
                    ]
                }
            }

            return agentParams
        }

        private func buildGatewayMessageBody() -> String {
            let imageLabels = images.enumerated().map { imageIndex, image in
                "attachment \(imageIndex + 1): \(image.label)"
            }.joined(separator: "\n")

            var messageSections: [String] = []
            if !imageLabels.isEmpty {
                messageSections.append("Attached screen captures:\n\(imageLabels)\nUse the attached images as the current screen context.")
            }

            let trimmedUserPrompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedUserPrompt.isEmpty {
                messageSections.append(trimmedUserPrompt)
            }
            return messageSections.joined(separator: "\n\n")
        }

        private func syncShellPromptContext(promptContext: String) async throws {
            let trimmedShellIdentifier = shellIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !trimmedShellIdentifier.isEmpty, !promptContext.isEmpty else {
                return
            }

            do {
                _ = try await request(
                    method: "clicky.shell.set_prompt_context",
                    params: [
                        "shellId": trimmedShellIdentifier,
                        "sessionKey": sessionKey,
                        "promptContext": promptContext,
                    ],
                    timeoutSeconds: 10
                )
            } catch {
                throw NSError(
                    domain: "OpenClawGatewayCompanionAgent",
                    code: -9,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to sync Clicky shell prompt context with OpenClaw. Make sure the clicky-shell plugin is installed, enabled, and registered for this session."
                    ]
                )
            }
        }

        private func startComputerUsePollingIfNeeded() {
            guard computerUsePollingTask == nil,
                  computerUseToolHandler != nil,
                  let shellIdentifier,
                  !shellIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            computerUsePollingTask = Task { [weak self] in
                guard let self else { return }
                await self.pollComputerUseRequests(
                    shellIdentifier: shellIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }

        private func pollComputerUseRequests(shellIdentifier: String) async {
            while !Task.isCancelled {
                do {
                    let payload = try await request(
                        method: "clicky.shell.next_computer_use_action",
                        params: [
                            "shellId": shellIdentifier,
                            "sessionKey": sessionKey,
                            "timeoutMs": 20_000,
                        ],
                        timeoutSeconds: 25
                    )

                    guard let requestPayload = payload["request"] as? [String: Any] else {
                        continue
                    }

                    guard let requestIdentifier = requestPayload["requestId"] as? String,
                          let route = requestPayload["route"] as? String else {
                        continue
                    }

                    let toolRequest = OpenClawComputerUseToolRequest(
                        requestIdentifier: requestIdentifier,
                        route: route,
                        payload: requestPayload["payload"] as? [String: Any] ?? [:],
                        statusText: requestPayload["statusText"] as? String
                    )

                    let result: [String: Any]
                    if let computerUseToolHandler {
                        result = await computerUseToolHandler(toolRequest)
                    } else {
                        result = [
                            "ok": false,
                            "error": "Clicky does not have a computer-use handler for this run.",
                        ]
                    }

                    _ = try await request(
                        method: "clicky.shell.complete_computer_use_action",
                        params: [
                            "shellId": shellIdentifier,
                            "sessionKey": sessionKey,
                            "requestId": requestIdentifier,
                            "result": result,
                        ],
                        timeoutSeconds: 10
                    )
                } catch is CancellationError {
                    return
                } catch {
                    ClickyLogger.error(
                        .computerUse,
                        "OpenClaw computer-use polling error=\(error.localizedDescription)"
                    )
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }

        private func request(
            method: String,
            params: [String: Any],
            timeoutSeconds: TimeInterval
        ) async throws -> [String: Any] {
            let requestIdentifier = UUID().uuidString
            ClickyAgentTurnDiagnostics.logOpenClawGatewayRPCRequest(
                method: method,
                requestIdentifier: requestIdentifier,
                timeoutSeconds: timeoutSeconds,
                params: params
            )

            return try await withTimeout(seconds: timeoutSeconds) {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
                    Task {
                        await self.state.registerPendingResponse(
                            requestIdentifier: requestIdentifier,
                            continuation: continuation
                        )

                        do {
                            try await self.sendFrame(
                                [
                                    "type": "req",
                                    "id": requestIdentifier,
                                    "method": method,
                                    "params": params,
                                ]
                            )
                        } catch {
                            await self.state.rejectPendingResponse(
                                requestIdentifier: requestIdentifier,
                                error: error
                            )
                        }
                    }
                }
            }
        }

        private func sendFrame(_ frame: [String: Any]) async throws {
            guard let webSocketTask else {
                throw NSError(
                    domain: "OpenClawGatewayCompanionAgent",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "OpenClaw Gateway WebSocket is not connected."]
                )
            }

            let frameData = try JSONSerialization.data(withJSONObject: frame)
            guard let frameJSONString = String(data: frameData, encoding: .utf8) else {
                throw NSError(
                    domain: "OpenClawGatewayCompanionAgent",
                    code: -5,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encode OpenClaw Gateway frame."]
                )
            }

            try await webSocketTask.send(.string(frameJSONString))
        }

        private func receiveMessages() async {
            guard let webSocketTask else { return }

            do {
                while !Task.isCancelled {
                    let message = try await webSocketTask.receive()
                    let messageText: String

                    switch message {
                    case .string(let text):
                        messageText = text
                    case .data(let data):
                        messageText = String(data: data, encoding: .utf8) ?? ""
                    @unknown default:
                        continue
                    }

                    try await handleIncomingMessage(messageText)
                }
            } catch is CancellationError {
                await state.failAll(error: CancellationError())
            } catch {
                await state.failAll(error: error)
            }
        }

        private func handleIncomingMessage(_ messageText: String) async throws {
            guard let messageData = messageText.data(using: .utf8),
                  let frame = try JSONSerialization.jsonObject(with: messageData) as? [String: Any],
                  let frameType = frame["type"] as? String else {
                return
            }

            if frameType == "event",
               let eventName = frame["event"] as? String {
                let payload = frame["payload"] as? [String: Any] ?? [:]

                if eventName == "connect.challenge",
                   let nonce = payload["nonce"] as? String,
                   !nonce.isEmpty {
                    await state.deliverConnectChallenge(nonce)
                    return
                }

                if eventName == "agent",
                   let nextTextChunk = await state.handleAgentEventPayload(payload) {
                    await MainActor.run {
                        onTextChunk(nextTextChunk)
                    }
                }

                return
            }

            if frameType == "res",
               let responseIdentifier = frame["id"] as? String,
               let responseIsOkay = frame["ok"] as? Bool {
                let responseMethod = frame["method"] as? String ?? "unknown"
                if responseIsOkay {
                    let payload = frame["payload"] as? [String: Any] ?? [:]
                    ClickyAgentTurnDiagnostics.logOpenClawGatewayRPCResponse(
                        method: responseMethod,
                        requestIdentifier: responseIdentifier,
                        ok: true,
                        payload: payload
                    )
                    await state.resolvePendingResponse(
                        requestIdentifier: responseIdentifier,
                        payload: payload
                    )
                } else {
                    let errorPayload = frame["error"] as? [String: Any] ?? [:]
                    let errorMessage = (errorPayload["message"] as? String)
                        ?? (errorPayload["code"] as? String)
                        ?? "OpenClaw Gateway request failed."
                    ClickyAgentTurnDiagnostics.logOpenClawGatewayRPCResponse(
                        method: responseMethod,
                        requestIdentifier: responseIdentifier,
                        ok: false,
                        errorMessage: errorMessage
                    )
                    let error = NSError(
                        domain: "OpenClawGatewayCompanionAgent",
                        code: -6,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage]
                    )
                    await state.rejectPendingResponse(
                        requestIdentifier: responseIdentifier,
                        error: error
                    )
                }
            }
        }

        private func withTimeout<T>(
            seconds: TimeInterval,
            operation: @escaping @Sendable () async throws -> T
        ) async throws -> T {
            try await withThrowingTaskGroup(of: T.self) { taskGroup in
                taskGroup.addTask {
                    try await operation()
                }

                taskGroup.addTask {
                    let nanoseconds = UInt64(max(seconds, 0) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanoseconds)
                    throw NSError(
                        domain: "OpenClawGatewayCompanionAgent",
                        code: -7,
                        userInfo: [NSLocalizedDescriptionKey: "OpenClaw Gateway request timed out."]
                    )
                }

                let result = try await taskGroup.next()!
                taskGroup.cancelAll()
                return result
            }
        }
    }
}
