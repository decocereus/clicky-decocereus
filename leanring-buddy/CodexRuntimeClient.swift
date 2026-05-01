//
//  CodexRuntimeClient.swift
//  leanring-buddy
//
//  Local Codex runtime bridge for ChatGPT-subscription-backed assistant turns.
//

import Foundation

private final class PipeCapture: @unchecked Sendable {
    let pipe = Pipe()

    private let lock = NSLock()
    private var chunks = Data()

    func start() {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard data.isEmpty == false else { return }
            self?.append(data)
        }
    }

    func finish() -> Data {
        pipe.fileHandleForReading.readabilityHandler = nil
        let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
        if remaining.isEmpty == false {
            append(remaining)
        }

        lock.lock()
        defer { lock.unlock() }
        return chunks
    }

    private func append(_ data: Data) {
        lock.lock()
        chunks.append(data)
        lock.unlock()
    }
}

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
            let usesBackgroundComputerUse = request.mcpServers.contains { $0.name == "background-computer-use" }
            let codexWorkingDirectoryURL = usesBackgroundComputerUse ? temporaryDirectoryURL : homeDirectoryURL

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.currentDirectoryURL = codexWorkingDirectoryURL
            process.environment = executionEnvironment

            var arguments: [String]
            if usesBackgroundComputerUse {
                arguments = [
                    "--dangerously-bypass-approvals-and-sandbox",
                    "--disable", "shell_tool",
                    "exec",
                    "--json",
                    "--skip-git-repo-check",
                    "--ephemeral",
                    "-C", codexWorkingDirectoryURL.path,
                    "-o", outputFileURL.path
                ]
            } else {
                arguments = [
                    "-a", "never",
                    "exec",
                    "--json",
                    "--skip-git-repo-check",
                    "--ephemeral",
                    "-s", "read-only",
                    "-C", codexWorkingDirectoryURL.path,
                    "-o", outputFileURL.path
                ]
            }

            if let configuredModel,
               !configuredModel.isEmpty {
                arguments.append(contentsOf: ["-m", configuredModel])
            }

            let mcpArguments = Self.mcpConfigurationArguments(for: request.mcpServers)
            arguments.append(contentsOf: mcpArguments)
            if usesBackgroundComputerUse {
                let requestMCPServerNames = Set(
                    request.mcpServers.flatMap { server in
                        [server.name, Self.codexMCPServerName(for: server.name)]
                    }
                )
                let userConfiguredMCPServersToDisable = Self.userConfiguredMCPServerNames(
                    homeDirectoryURL: homeDirectoryURL
                )
                    .filter { !requestMCPServerNames.contains($0) }
                    .sorted()
                for serverName in userConfiguredMCPServersToDisable {
                    arguments.append(contentsOf: [
                        "-c", "mcp_servers.\(Self.codexConfigKeyPathSegment(serverName)).enabled=false"
                    ])
                }
                arguments.append(contentsOf: [
                    "-c", #"plugins."computer-use@openai-bundled".enabled=false"#
                ])
            }

            for imageFileURL in imageFileURLs {
                arguments.append(contentsOf: ["--image", imageFileURL.path])
            }

            process.arguments = arguments
            ClickyLogger.notice(
                .agent,
                "Codex launch prepared executable=\(executablePath) usesBackgroundComputerUse=\(usesBackgroundComputerUse) workingDirectory=\(codexWorkingDirectoryURL.path) mcpServerCount=\(request.mcpServers.count) mcpServers=\(Self.mcpServerNames(for: request.mcpServers)) mcpArgumentCount=\(mcpArguments.count) imageCount=\(imageFileURLs.count)"
            )

            let stdoutCapture = PipeCapture()
            let stderrCapture = PipeCapture()
            let stdinPipe = Pipe()
            process.standardOutput = stdoutCapture.pipe
            process.standardError = stderrCapture.pipe
            process.standardInput = stdinPipe

            stdoutCapture.start()
            stderrCapture.start()
            try process.run()
            if let promptData = prompt.data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(promptData)
            }
            stdinPipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()

            let stdoutData = stdoutCapture.finish()
            let stderrData = stderrCapture.finish()
            let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
            Self.logRuntimeDiagnostics(
                stdoutData: stdoutData,
                stderrText: stderrText
            )

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
            let duration = Date().timeIntervalSince(startTime)
            ClickyLogger.notice(
                .agent,
                "Codex runtime completed usesBackgroundComputerUse=\(usesBackgroundComputerUse) durationMs=\(Int(duration * 1000)) finalMessageLength=\(finalMessageText.count)"
            )

            await MainActor.run {
                onTextChunk(finalMessageText)
            }

            return ClickyAssistantTurnResponse(
                text: finalMessageText,
                duration: duration
            )
        }

        return try await executionTask.value
    }

    private nonisolated static func logRuntimeDiagnostics(
        stdoutData: Data,
        stderrText: String
    ) {
        let stderrSummary = stderrText
            .split(whereSeparator: \.isNewline)
            .filter { line in
                let lowercasedLine = line.lowercased()
                return lowercasedLine.contains("mcp")
                    || lowercasedLine.contains("error")
                    || lowercasedLine.contains("warn")
            }
            .prefix(8)
            .joined(separator: " | ")
        if !stderrSummary.isEmpty {
            ClickyLogger.notice(.agent, "Codex runtime diagnostics stderr=\(stderrSummary)")
        }

        guard let stdoutText = String(data: stdoutData, encoding: .utf8),
              !stdoutText.isEmpty else {
            return
        }

        let mcpEvents = stdoutText
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> (summary: String, server: String, tool: String, status: String)? in
                guard line.contains("\"type\":\"mcp_tool_call\"") else { return nil }
                guard let lineData = String(line).data(using: .utf8),
                      let payload = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let item = payload["item"] as? [String: Any],
                      item["type"] as? String == "mcp_tool_call" else {
                    return ("unparsed-mcp-event", "unknown-server", "unknown-tool", "unknown-status")
                }

                let server = item["server"] as? String ?? "unknown-server"
                let tool = item["tool"] as? String ?? "unknown-tool"
                let status = item["status"] as? String ?? "unknown-status"
                let errorMessage = (item["error"] as? [String: Any])?["message"] as? String
                if let errorMessage {
                    return ("\(server).\(tool) status=\(status) error=\(errorMessage)", server, tool, status)
                }
                return ("\(server).\(tool) status=\(status)", server, tool, status)
            }
        let mcpEventSummaries = mcpEvents.map(\.summary)
        let trimmedMCPEventSummaries: [String]
        if mcpEventSummaries.count > 24 {
            trimmedMCPEventSummaries = Array(mcpEventSummaries.prefix(8))
                + ["... \(mcpEventSummaries.count - 16) earlier/later events omitted ..."]
                + Array(mcpEventSummaries.suffix(8))
        } else {
            trimmedMCPEventSummaries = mcpEventSummaries
        }

        if !trimmedMCPEventSummaries.isEmpty {
            ClickyLogger.notice(.agent, "Codex MCP events count=\(mcpEventSummaries.count) \(trimmedMCPEventSummaries.joined(separator: " | "))")
            let completedCounts = Dictionary(
                grouping: mcpEvents.filter { $0.status == "completed" },
                by: { "\($0.server).\($0.tool)" }
            )
                .map { key, events in "\(key)=\(events.count)" }
                .sorted()
                .joined(separator: ",")
            ClickyLogger.notice(.agent, "Codex MCP completed counts \(completedCounts.isEmpty ? "(none)" : completedCounts)")
        }
    }

    private nonisolated static func mcpConfigurationArguments(
        for servers: [ClickyAssistantMCPServerConfiguration]
    ) -> [String] {
        servers.flatMap { server in
            let serverName = codexMCPServerName(for: server.name)
            var arguments: [String] = [
                "-c", "mcp_servers.\(codexConfigKeyPathSegment(serverName)).command=\(tomlStringLiteral(server.commandPath))"
            ]

            if !server.arguments.isEmpty {
                let encodedArguments = server.arguments
                    .map(tomlStringLiteral)
                    .joined(separator: ", ")
                arguments.append(contentsOf: [
                    "-c", "mcp_servers.\(codexConfigKeyPathSegment(serverName)).args=[\(encodedArguments)]"
                ])
            }

            if let workingDirectoryPath = server.workingDirectoryPath?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !workingDirectoryPath.isEmpty {
                arguments.append(contentsOf: [
                    "-c", "mcp_servers.\(codexConfigKeyPathSegment(serverName)).cwd=\(tomlStringLiteral(workingDirectoryPath))"
                ])
            }

            return arguments
        }
    }

    private nonisolated static func codexMCPServerName(for serverName: String) -> String {
        if serverName == "background-computer-use" {
            return "computer-use"
        }

        return serverName
    }

    private nonisolated static func mcpServerNames(
        for servers: [ClickyAssistantMCPServerConfiguration]
    ) -> String {
        let names = servers.map(\.name).joined(separator: ",")
        return names.isEmpty ? "(none)" : names
    }

    private nonisolated static func userConfiguredMCPServerNames(
        homeDirectoryURL: URL
    ) -> Set<String> {
        let configURL = homeDirectoryURL
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("config.toml")
        guard let configText = try? String(contentsOf: configURL, encoding: .utf8) else {
            return []
        }

        var serverNames = Set<String>()
        for line in configText.split(whereSeparator: \.isNewline) {
            let trimmedLine = String(line).trimmingCharacters(in: .whitespaces)
            guard trimmedLine.hasPrefix("[mcp_servers."),
                  trimmedLine.hasSuffix("]") else {
                continue
            }

            let serverNameStart = trimmedLine.index(trimmedLine.startIndex, offsetBy: "[mcp_servers.".count)
            let serverNameEnd = trimmedLine.index(before: trimmedLine.endIndex)
            let rawServerName = String(trimmedLine[serverNameStart..<serverNameEnd])
            let serverName = unquotedCodexConfigKeyPathSegment(rawServerName)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !serverName.isEmpty {
                serverNames.insert(serverName)
            }
        }

        return serverNames
    }

    private nonisolated static func codexConfigKeyPathSegment(_ value: String) -> String {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        if value.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) {
            return value
        }

        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private nonisolated static func unquotedCodexConfigKeyPathSegment(_ value: String) -> String {
        guard value.hasPrefix("\""),
              value.hasSuffix("\""),
              value.count >= 2 else {
            return value
        }

        let start = value.index(after: value.startIndex)
        let end = value.index(before: value.endIndex)
        return String(value[start..<end])
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
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
