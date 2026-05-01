//
//  CodexRuntimeClient.swift
//  leanring-buddy
//
//  Local Codex runtime bridge for ChatGPT-subscription-backed assistant turns.
//

import Foundation

struct CodexRuntimeStatusSnapshot {
    let isInstalled: Bool
    let executablePath: String?
    let isAuthenticated: Bool
    let authModeLabel: String?
    let configuredModel: String?
}

final class CodexRuntimeClient {
    nonisolated func inspectRuntime() -> CodexRuntimeStatusSnapshot {
        let executablePath = resolveExecutablePath()
        let authPayload = loadAuthPayload()
        let configModel = loadConfiguredModel()

        return CodexRuntimeStatusSnapshot(
            isInstalled: executablePath != nil,
            executablePath: executablePath,
            isAuthenticated: authPayload?.isAuthenticated ?? false,
            authModeLabel: authPayload?.authModeLabel,
            configuredModel: configModel
        )
    }

    nonisolated func executeTurn(
        request: ClickyAssistantTurnRequest,
        onTextChunk: @MainActor @escaping @Sendable (String) -> Void
    ) async throws -> ClickyAssistantTurnResponse {
        let runtimeStatus = inspectRuntime()
        let fileManager = FileManager.default
        let homeDirectoryURL = fileManager.homeDirectoryForCurrentUser
        let prompt = Self.renderPrompt(from: request)
        await MainActor.run {
            ClickyAgentTurnDiagnostics.logRenderedPrompt(
                backendLabel: "Codex",
                prompt: prompt
            )
        }
        let configuredModel = runtimeStatus.configuredModel?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let executionEnvironment = Self.executionEnvironment(
            fileManager: fileManager,
            homeDirectoryURL: homeDirectoryURL
        )

        guard runtimeStatus.isInstalled, let executablePath = runtimeStatus.executablePath else {
            throw NSError(
                domain: "CodexRuntimeClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Codex is not installed on this Mac."]
            )
        }

        guard runtimeStatus.isAuthenticated else {
            throw NSError(
                domain: "CodexRuntimeClient",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Codex is not signed in with ChatGPT on this Mac."]
            )
        }

        let executionTask = Task.detached(priority: .userInitiated) {
            let startTime = Date()
            let temporaryDirectoryURL = try fileManager.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: homeDirectoryURL,
                create: true
            )
            defer {
                try? fileManager.removeItem(at: temporaryDirectoryURL)
            }

            let outputFileURL = temporaryDirectoryURL.appendingPathComponent("codex-last-message.txt")
            let imageFileURLs = try Self.writeImageAttachments(
                request.imageAttachments,
                into: temporaryDirectoryURL
            )

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.currentDirectoryURL = homeDirectoryURL
            process.environment = executionEnvironment

            var arguments = [
                "-a", "never",
                "exec",
                "--json",
                "--skip-git-repo-check",
                "--ephemeral",
                "-s", "read-only",
                "-C", homeDirectoryURL.path,
                "-o", outputFileURL.path
            ]

            if let configuredModel,
               !configuredModel.isEmpty {
                arguments.append(contentsOf: ["-m", configuredModel])
            }

            arguments.append(contentsOf: Self.mcpConfigurationArguments(for: request.mcpServers))

            for imageFileURL in imageFileURLs {
                arguments.append(contentsOf: ["--image", imageFileURL.path])
            }

            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let stdinPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = stdinPipe

            try process.run()
            if let promptData = prompt.data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(promptData)
            }
            stdinPipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrText = String(data: stderrData, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 {
                throw NSError(
                    domain: "CodexRuntimeClient",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: stderrText.isEmpty ? "Codex exited with status \(process.terminationStatus)." : stderrText]
                )
            }

            let finalMessageText = Self.readFinalMessage(
                outputFileURL: outputFileURL,
                stdoutData: stdoutData
            )

            await MainActor.run {
                onTextChunk(finalMessageText)
            }

            return ClickyAssistantTurnResponse(
                text: finalMessageText,
                duration: Date().timeIntervalSince(startTime)
            )
        }

        return try await executionTask.value
    }

    private nonisolated static func mcpConfigurationArguments(
        for servers: [ClickyAssistantMCPServerConfiguration]
    ) -> [String] {
        servers.flatMap { server in
            var arguments: [String] = [
                "-c", "mcp_servers.\(server.name).command=\(tomlStringLiteral(server.commandPath))"
            ]

            if !server.arguments.isEmpty {
                let encodedArguments = server.arguments
                    .map(tomlStringLiteral)
                    .joined(separator: ", ")
                arguments.append(contentsOf: [
                    "-c", "mcp_servers.\(server.name).args=[\(encodedArguments)]"
                ])
            }

            if let workingDirectoryPath = server.workingDirectoryPath?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !workingDirectoryPath.isEmpty {
                arguments.append(contentsOf: [
                    "-c", "mcp_servers.\(server.name).cwd=\(tomlStringLiteral(workingDirectoryPath))"
                ])
            }

            return arguments
        }
    }

    private nonisolated static func tomlStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private nonisolated func resolveExecutablePath() -> String? {
        let fileManager = FileManager.default
        let homeDirectoryPath = fileManager.homeDirectoryForCurrentUser.path
        let knownExecutableCandidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
        ]
        let homeRelativeCandidates = [
            "\(homeDirectoryPath)/.bun/bin/codex",
            "\(homeDirectoryPath)/.npm-global/bin/codex",
            "\(homeDirectoryPath)/bin/codex",
        ]

        for candidatePath in homeRelativeCandidates + knownExecutableCandidates {
            if fileManager.isExecutableFile(atPath: candidatePath) {
                return candidatePath
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "codex"]
        process.environment = Self.executionEnvironment(
            fileManager: fileManager,
            homeDirectoryURL: fileManager.homeDirectoryForCurrentUser
        )
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }

    private nonisolated static func executionEnvironment(
        fileManager: FileManager,
        homeDirectoryURL: URL
    ) -> [String: String] {
        let homeDirectoryPath = homeDirectoryURL.path
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = homeDirectoryPath

        var pathEntries: [String] = [
            "\(homeDirectoryPath)/.bun/bin",
            "\(homeDirectoryPath)/.npm-global/bin",
            "\(homeDirectoryPath)/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
        ]

        let nvmVersionsDirectory = URL(fileURLWithPath: homeDirectoryPath)
            .appendingPathComponent(".nvm", isDirectory: true)
            .appendingPathComponent("versions", isDirectory: true)
            .appendingPathComponent("node", isDirectory: true)

        if let versionDirectories = try? fileManager.contentsOfDirectory(
            at: nvmVersionsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            let sortedDirectories = versionDirectories.sorted { $0.lastPathComponent > $1.lastPathComponent }
            pathEntries.append(contentsOf: sortedDirectories.map { $0.appendingPathComponent("bin", isDirectory: true).path })
        }

        if let existingPath = environment["PATH"], !existingPath.isEmpty {
            pathEntries.append(contentsOf: existingPath.split(separator: ":").map(String.init))
        }

        environment["PATH"] = Array(NSOrderedSet(array: pathEntries)).compactMap { $0 as? String }.joined(separator: ":")
        return environment
    }

    private nonisolated func loadConfiguredModel() -> String? {
        let fileManager = FileManager.default
        let configURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("config.toml")

        guard let configText = try? String(contentsOf: configURL, encoding: .utf8) else { return nil }
        for line in configText.split(separator: "\n") {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("model") else { continue }
            let parts = trimmedLine.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let modelValue = parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if !modelValue.isEmpty {
                return modelValue
            }
        }
        return nil
    }

    private nonisolated func loadAuthPayload() -> (isAuthenticated: Bool, authModeLabel: String?)? {
        let fileManager = FileManager.default
        let authURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json")

        guard let authData = try? Data(contentsOf: authURL),
              let authJSON = try? JSONSerialization.jsonObject(with: authData) as? [String: Any] else {
            return nil
        }

        let authMode = (authJSON["auth_mode"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = authJSON["tokens"] as? [String: Any]
        let hasAccessToken = (tokens?["access_token"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false

        return (
            isAuthenticated: hasAccessToken,
            authModeLabel: authMode == "chatgpt" ? "ChatGPT subscription" : authMode
        )
    }

    private nonisolated static func renderPrompt(from request: ClickyAssistantTurnRequest) -> String {
        var sections: [String] = []
        sections.append("System instructions:\n\(request.systemPrompt)")

        if !request.conversationHistory.isEmpty {
            let history = request.conversationHistory.map { turn in
                "User: \(turn.userText)\nAssistant: \(turn.assistantText)"
            }.joined(separator: "\n\n")
            sections.append("Conversation so far:\n\(history)")
        }

        sections.append(
            """
            Runtime guardrails:
            - You are answering inside Clicky as a desktop companion.
            - Do not modify files, run shell commands, or inspect the local workspace unless the user explicitly asks for coding help that requires it.
            - Use the provided screenshots and focus context as the primary source of truth for what is on screen.
            """
        )

        sections.append("User request:\n\(request.userPrompt)")
        return sections.joined(separator: "\n\n")
    }

    private nonisolated static func writeImageAttachments(
        _ attachments: [ClickyAssistantImageAttachment],
        into directoryURL: URL
    ) throws -> [URL] {
        try attachments.enumerated().map { index, attachment in
            let fileExtension = attachment.mimeType == "image/png" ? "png" : "jpg"
            let fileURL = directoryURL.appendingPathComponent("clicky-attachment-\(index + 1).\(fileExtension)")
            try attachment.data.write(to: fileURL)
            return fileURL
        }
    }

    private nonisolated static func readFinalMessage(outputFileURL: URL, stdoutData: Data) -> String {
        if let outputText = try? String(contentsOf: outputFileURL, encoding: .utf8),
           !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
        for line in stdoutText.split(separator: "\n").reversed() {
            guard let lineData = String(line).data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = jsonObject["type"] as? String,
                  type == "item.completed",
                  let item = jsonObject["item"] as? [String: Any],
                  let itemType = item["type"] as? String,
                  itemType == "agent_message",
                  let text = item["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ""
    }
}
