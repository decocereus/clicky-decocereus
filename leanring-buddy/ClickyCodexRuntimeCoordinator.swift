//
//  ClickyCodexRuntimeCoordinator.swift
//  leanring-buddy
//
//  Owns local Codex runtime readiness and setup actions.
//

import AppKit
import Foundation

@MainActor
final class ClickyCodexRuntimeCoordinator {
    private let backendRoutingController: ClickyBackendRoutingController
    private let runtimeClient: CodexRuntimeClient
    private let workspace: NSWorkspace

    init(
        backendRoutingController: ClickyBackendRoutingController,
        runtimeClient: CodexRuntimeClient,
        workspace: NSWorkspace = .shared
    ) {
        self.backendRoutingController = backendRoutingController
        self.runtimeClient = runtimeClient
        self.workspace = workspace
    }

    var statusLabel: String {
        Self.statusLabel(for: backendRoutingController.codexRuntimeStatus)
    }

    var summaryCopy: String {
        Self.summaryCopy(for: backendRoutingController.codexRuntimeStatus)
    }

    var readinessChipLabels: [String] {
        Self.readinessChipLabels(
            status: backendRoutingController.codexRuntimeStatus,
            authModeLabel: backendRoutingController.codexAuthModeLabel,
            configuredModelName: backendRoutingController.codexConfiguredModelName
        )
    }

    var configuredModelLabel: String {
        backendRoutingController.codexConfiguredModelName ?? "Use Codex default"
    }

    var accountLabel: String {
        backendRoutingController.codexAuthModeLabel ?? "ChatGPT sign-in needed"
    }

    func refreshRuntimeStatus() {
        backendRoutingController.codexRuntimeStatus = .checking

        Task { @MainActor in
            let snapshot = runtimeClient.inspectRuntime()
            backendRoutingController.codexConfiguredModelName = snapshot.configuredModel
            backendRoutingController.codexExecutablePath = snapshot.executablePath
            backendRoutingController.codexAuthModeLabel = snapshot.authModeLabel

            if !snapshot.isInstalled {
                backendRoutingController.codexRuntimeStatus = .failed(message: "Codex is not installed on this Mac yet.")
                ClickyLogger.error(.agent, "Codex runtime unavailable reason=not-installed")
                return
            }

            if !snapshot.isAuthenticated {
                backendRoutingController.codexRuntimeStatus = .failed(message: "Codex needs a ChatGPT sign-in before Clicky can use it.")
                ClickyLogger.error(.agent, "Codex runtime unavailable reason=not-authenticated")
                return
            }

            let modelLabel = snapshot.configuredModel ?? "default model"
            backendRoutingController.codexRuntimeStatus = .ready(summary: "Codex is ready on this Mac using \(modelLabel).")
            ClickyLogger.notice(.agent, "Codex runtime ready authMode=\(snapshot.authModeLabel ?? "unknown") model=\(modelLabel)")
        }
    }

    func openInstallPage() {
        guard let url = URL(string: "https://github.com/openai/codex") else { return }
        workspace.open(url)
    }

    func startLoginInTerminal() {
        let command = "codex login"
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }

    static func statusLabel(for status: CodexRuntimeStatus) -> String {
        switch status {
        case .idle:
            return "Not checked yet"
        case .checking:
            return "Checking Codex"
        case .ready:
            return "Ready"
        case .failed:
            return "Needs setup"
        }
    }

    static func summaryCopy(for status: CodexRuntimeStatus) -> String {
        switch status {
        case .idle:
            return "Codex runs locally on this Mac and can use your ChatGPT subscription when it is signed in and ready."
        case .checking:
            return "Clicky is checking whether Codex is installed and signed in on this Mac."
        case .ready(let summary):
            return summary
        case .failed(let message):
            return message
        }
    }

    static func readinessChipLabels(
        status: CodexRuntimeStatus,
        authModeLabel: String?,
        configuredModelName: String?
    ) -> [String] {
        var labels: [String] = []
        labels.append(statusLabel(for: status))

        if let authModeLabel = authModeLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !authModeLabel.isEmpty {
            labels.append(authModeLabel)
        }

        if let configuredModelName = configuredModelName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configuredModelName.isEmpty {
            labels.append(configuredModelName)
        }

        if labels.count == 1 {
            labels.append("Local runtime")
        }

        return labels
    }
}
