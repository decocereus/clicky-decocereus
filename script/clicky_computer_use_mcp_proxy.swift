#!/usr/bin/env swift

import Foundation

private enum ProxyPolicy: String {
    case observe
    case review
}

private let readOnlyToolNames: Set<String> = [
    "list_apps",
    "list_windows",
    "get_app_state",
    "get_window_state"
]

private let observeInstructionsPrefix = """
# Clicky Observe Mode

Clicky is exposing BackgroundComputerUse through an observe-only MCP proxy.

Allowed tools:
- list_apps
- list_windows
- get_app_state
- get_window_state

Do not plan or call mutating desktop tools in this mode. Clicky will reject clicks, scrolling, dragging, typing, keypresses, value changes, secondary actions, window moves, and window resizing. Use the allowed tools only to inspect current app and window state.

---

"""

private let reviewInstructionsPrefix = """
# Clicky Review Mode

Clicky is exposing BackgroundComputerUse through a review-gated MCP proxy.

Read-only tools run immediately. Mutating tools pause and wait for the user to approve or deny the exact tool call in Clicky's Studio. After approval, the proxy re-observes the target window before forwarding the mutation to BackgroundComputerUse.

Always inspect current state before requesting a mutation, prefer semantic targets from the latest observation, and expect denied, timed-out, stale-token, or failed fresh-observation actions to return an MCP tool error.

---

"""

private struct ServerLaunchConfiguration {
    let command: String
    let arguments: [String]
    let workingDirectory: String?
    let policy: ProxyPolicy
    let reviewDirectory: URL?
}

private enum ProxyError: Error, CustomStringConvertible {
    case missingValue(String)
    case missingServerCommand
    case childExited
    case reviewDirectoryRequired

    var description: String {
        switch self {
        case let .missingValue(flag):
            return "Missing value for \(flag)."
        case .missingServerCommand:
            return "Missing --server-command."
        case .childExited:
            return "BackgroundComputerUse MCP exited before returning a response."
        case .reviewDirectoryRequired:
            return "--review-dir is required when --policy review is used."
        }
    }
}

private enum ReviewDecision {
    case approved
    case denied
    case invalidDecision
    case timedOut
}

private final class ChildLineReader {
    private let handle: FileHandle
    private var buffer = Data()

    init(handle: FileHandle) {
        self.handle = handle
    }

    func readLine() -> String? {
        while true {
            if let newlineIndex = buffer.firstIndex(of: 10) {
                let lineData = buffer[..<newlineIndex]
                buffer.removeSubrange(...newlineIndex)
                return String(decoding: lineData, as: UTF8.self)
            }

            let nextByte = handle.readData(ofLength: 1)
            if nextByte.isEmpty {
                guard buffer.isEmpty == false else { return nil }
                let line = String(decoding: buffer, as: UTF8.self)
                buffer.removeAll()
                return line
            }
            buffer.append(nextByte)
        }
    }
}

private func parseLaunchConfiguration(arguments: [String]) throws -> ServerLaunchConfiguration {
    var command: String?
    var serverArguments: [String] = []
    var workingDirectory: String?
    var policy: ProxyPolicy = .observe
    var reviewDirectory: URL?
    var index = 0

    while index < arguments.count {
        let flag = arguments[index]
        switch flag {
        case "--server-command":
            index += 1
            guard index < arguments.count else { throw ProxyError.missingValue(flag) }
            command = arguments[index]
        case "--server-arg":
            index += 1
            guard index < arguments.count else { throw ProxyError.missingValue(flag) }
            serverArguments.append(arguments[index])
        case "--server-cwd":
            index += 1
            guard index < arguments.count else { throw ProxyError.missingValue(flag) }
            let value = arguments[index].trimmingCharacters(in: .whitespacesAndNewlines)
            workingDirectory = value.isEmpty ? nil : value
        case "--policy":
            index += 1
            guard index < arguments.count else { throw ProxyError.missingValue(flag) }
            policy = ProxyPolicy(rawValue: arguments[index]) ?? .observe
        case "--review-dir":
            index += 1
            guard index < arguments.count else { throw ProxyError.missingValue(flag) }
            reviewDirectory = URL(fileURLWithPath: arguments[index], isDirectory: true)
        default:
            fputs("Ignoring unsupported argument \(flag)\n", stderr)
        }
        index += 1
    }

    guard let command else { throw ProxyError.missingServerCommand }
    if policy == .review, reviewDirectory == nil {
        throw ProxyError.reviewDirectoryRequired
    }

    return ServerLaunchConfiguration(
        command: command,
        arguments: serverArguments,
        workingDirectory: workingDirectory,
        policy: policy,
        reviewDirectory: reviewDirectory
    )
}

private func jsonObject(from line: String) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
        return [:]
    }
    return object
}

private func jsonLine(from object: [String: Any]) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
}

private func writeLine(_ line: String, to handle: FileHandle) throws {
    try handle.write(contentsOf: Data((line + "\n").utf8))
}

private func send(_ object: [String: Any]) {
    guard let line = try? jsonLine(from: object) else { return }
    print(line)
    fflush(stdout)
}

private func stableDigest(_ value: String) -> String {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in value.utf8 {
        hash ^= UInt64(byte)
        hash &*= 0x100000001b3
    }
    return String(format: "%016llx", hash)
}

private func toolErrorResponse(id: Any, text: String) -> [String: Any] {
    [
        "jsonrpc": "2.0",
        "id": id,
        "result": [
            "content": [[
                "type": "text",
                "text": text
            ]],
            "isError": true
        ]
    ]
}

private func filterToolsListResponse(_ response: [String: Any], policy: ProxyPolicy) -> [String: Any] {
    guard policy == .observe else {
        return response
    }

    var filteredResponse = response
    guard var result = filteredResponse["result"] as? [String: Any],
          let tools = result["tools"] as? [[String: Any]] else {
        return response
    }

    result["tools"] = tools.filter { tool in
        guard let name = tool["name"] as? String else { return false }
        return readOnlyToolNames.contains(name)
    }
    filteredResponse["result"] = result
    return filteredResponse
}

private func filterResourcesListResponse(_ response: [String: Any], policy: ProxyPolicy) -> [String: Any] {
    var filteredResponse = response
    guard var result = filteredResponse["result"] as? [String: Any],
          let resources = result["resources"] as? [[String: Any]] else {
        return response
    }

    result["resources"] = resources.map { resource in
        var filteredResource = resource
        if filteredResource["uri"] as? String == "background-computer-use://instructions" {
            switch policy {
            case .observe:
                filteredResource["name"] = "Clicky Observe Mode Background Computer Use instructions"
                filteredResource["description"] = "Observe-only operating instructions for inspecting app and window state through BackgroundComputerUse."
            case .review:
                filteredResource["name"] = "Clicky Review Mode Background Computer Use instructions"
                filteredResource["description"] = "Review-gated operating instructions for using BackgroundComputerUse through Clicky."
            }
        }
        return filteredResource
    }
    filteredResponse["result"] = result
    return filteredResponse
}

private func filterResourceReadResponse(_ response: [String: Any], policy: ProxyPolicy) -> [String: Any] {
    var filteredResponse = response
    guard var result = filteredResponse["result"] as? [String: Any],
          let contents = result["contents"] as? [[String: Any]] else {
        return response
    }

    let prefix = policy == .observe ? observeInstructionsPrefix : reviewInstructionsPrefix
    result["contents"] = contents.map { content in
        var filteredContent = content
        if filteredContent["uri"] as? String == "background-computer-use://instructions",
           let text = filteredContent["text"] as? String {
            filteredContent["text"] = prefix + text
        }
        return filteredContent
    }
    filteredResponse["result"] = result
    return filteredResponse
}

private func writeReviewRequest(
    reviewDirectory: URL,
    requestID: String,
    toolName: String,
    arguments: Any,
    originalLine: String
) throws {
    let requestDigest = stableDigest(originalLine)
    cleanupExpiredReviewFiles(in: reviewDirectory)
    let pendingDirectory = reviewDirectory.appendingPathComponent("pending", isDirectory: true)
    try createPrivateDirectory(pendingDirectory)

    let payload: [String: Any] = [
        "id": requestID,
        "toolName": toolName,
        "arguments": arguments,
        "requestDigest": requestDigest,
        "createdAt": ISO8601DateFormatter().string(from: Date())
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    let pendingURL = pendingDirectory.appendingPathComponent("\(requestID).json")
    try data.write(to: pendingURL, options: .atomic)
    try setPrivateFilePermissions(pendingURL)
}

private func waitForReviewDecision(
    reviewDirectory: URL,
    requestID: String,
    requestDigest: String
) -> ReviewDecision {
    let approvedURL = reviewDirectory
        .appendingPathComponent("approved", isDirectory: true)
        .appendingPathComponent("\(requestID).json")
    let deniedURL = reviewDirectory
        .appendingPathComponent("denied", isDirectory: true)
        .appendingPathComponent("\(requestID).json")
    let deadline = Date().addingTimeInterval(300)

    while Date() < deadline {
        if FileManager.default.fileExists(atPath: approvedURL.path) {
            guard decisionDigest(at: approvedURL) == requestDigest else {
                return .invalidDecision
            }
            return .approved
        }
        if FileManager.default.fileExists(atPath: deniedURL.path) {
            guard decisionDigest(at: deniedURL) == requestDigest else {
                return .invalidDecision
            }
            return .denied
        }
        Thread.sleep(forTimeInterval: 0.25)
    }

    return .timedOut
}

private func decisionDigest(at url: URL) -> String? {
    guard let data = try? Data(contentsOf: url),
          let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    return payload["requestDigest"] as? String
}

private func cleanupReviewRequest(reviewDirectory: URL, requestID: String) {
    let filenames = [
        reviewDirectory.appendingPathComponent("pending/\(requestID).json"),
        reviewDirectory.appendingPathComponent("approved/\(requestID).json"),
        reviewDirectory.appendingPathComponent("denied/\(requestID).json")
    ]
    for url in filenames {
        try? FileManager.default.removeItem(at: url)
    }
}

private func cleanupExpiredReviewFiles(in reviewDirectory: URL) {
    let now = Date()
    removeExpiredFiles(
        in: reviewDirectory.appendingPathComponent("pending", isDirectory: true),
        maxAge: 300,
        now: now
    )
    removeExpiredFiles(
        in: reviewDirectory.appendingPathComponent("approved", isDirectory: true),
        maxAge: 900,
        now: now
    )
    removeExpiredFiles(
        in: reviewDirectory.appendingPathComponent("denied", isDirectory: true),
        maxAge: 900,
        now: now
    )
}

private func createPrivateDirectory(_ directoryURL: URL) throws {
    try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
}

private func setPrivateFilePermissions(_ fileURL: URL) throws {
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
}

private func removeExpiredFiles(in directoryURL: URL, maxAge: TimeInterval, now: Date) {
    guard let fileURLs = try? FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
    ) else {
        return
    }

    for fileURL in fileURLs where fileURL.pathExtension == "json" {
        let modifiedAt = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
        if now.timeIntervalSince(modifiedAt) > maxAge {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}

private func freshObservationPreflight(
    toolName: String,
    arguments: Any,
    childWriter: FileHandle,
    childReader: ChildLineReader
) throws -> String? {
    guard let actionArguments = arguments as? [String: Any],
          let windowID = actionArguments["window"] as? String,
          windowID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
        return "\(toolName) cannot run in Clicky Review mode because its arguments do not include a target window for fresh observation."
    }

    let preflightID = "clicky-review-preflight-\(UUID().uuidString)"
    let preflightRequest: [String: Any] = [
        "jsonrpc": "2.0",
        "id": preflightID,
        "method": "tools/call",
        "params": [
            "name": "get_window_state",
            "arguments": [
                "window": windowID,
                "imageMode": "omit",
                "includeRawScreenshot": false,
                "maxNodes": 6500
            ]
        ]
    ]

    try writeLine(try jsonLine(from: preflightRequest), to: childWriter)

    guard let responseLine = childReader.readLine() else {
        throw ProxyError.childExited
    }

    guard let response = try? jsonObject(from: responseLine),
          let result = response["result"] as? [String: Any] else {
        return "Clicky Review mode could not parse the fresh observation response before running \(toolName)."
    }

    if result["isError"] as? Bool == true {
        return "Clicky Review mode blocked \(toolName) because fresh get_window_state failed for window \(windowID)."
    }

    guard let requestedStateToken = (actionArguments["stateToken"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
        requestedStateToken.isEmpty == false else {
        return nil
    }

    guard let freshStateToken = stateToken(in: result) else {
        return "Clicky Review mode blocked \(toolName) because fresh get_window_state did not return a stateToken."
    }

    if freshStateToken != requestedStateToken {
        return "Clicky Review mode blocked \(toolName) because the approved action used a stale stateToken. Re-observe and retry with the latest state."
    }

    return nil
}

private func stateToken(in value: Any) -> String? {
    if let dictionary = value as? [String: Any] {
        if let token = dictionary["stateToken"] as? String, !token.isEmpty {
            return token
        }

        if let content = dictionary["content"] as? [[String: Any]] {
            for item in content {
                guard item["type"] as? String == "text",
                      let text = item["text"] as? String,
                      let data = text.data(using: .utf8),
                      let textObject = try? JSONSerialization.jsonObject(with: data),
                      let token = stateToken(in: textObject) else {
                    continue
                }
                return token
            }
        }

        for nestedValue in dictionary.values {
            if let token = stateToken(in: nestedValue) {
                return token
            }
        }
    }

    if let array = value as? [Any] {
        for item in array {
            if let token = stateToken(in: item) {
                return token
            }
        }
    }

    return nil
}

private func runProxy() throws {
    let configuration = try parseLaunchConfiguration(arguments: Array(CommandLine.arguments.dropFirst()))

    let process = Process()
    process.executableURL = URL(fileURLWithPath: configuration.command)
    process.arguments = configuration.arguments
    if let workingDirectory = configuration.workingDirectory {
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
    }

    let childInput = Pipe()
    let childOutput = Pipe()
    process.standardInput = childInput
    process.standardOutput = childOutput
    process.standardError = FileHandle.standardError

    try process.run()

    let childReader = ChildLineReader(handle: childOutput.fileHandleForReading)
    let childWriter = childInput.fileHandleForWriting

    while let line = readLine() {
        guard line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            continue
        }

        let message = try jsonObject(from: line)
        let method = message["method"] as? String
        let id = message["id"]

        if method == "tools/call",
           let id,
           let params = message["params"] as? [String: Any],
           let toolName = params["name"] as? String,
           readOnlyToolNames.contains(toolName) == false {
            switch configuration.policy {
            case .observe:
                send(toolErrorResponse(
                    id: id,
                    text: "Clicky is in Observe mode. This MCP proxy only allows list_apps, list_windows, get_app_state, and get_window_state. Switch Clicky Computer Use to Direct before calling mutating desktop tools."
                ))
                continue
            case .review:
                guard let reviewDirectory = configuration.reviewDirectory else {
                    send(toolErrorResponse(id: id, text: "Clicky Review mode is missing its review directory."))
                    continue
                }
                let requestID = UUID().uuidString
                let arguments = params["arguments"] ?? [:]
                let requestDigest = stableDigest(line)
                try writeReviewRequest(
                    reviewDirectory: reviewDirectory,
                    requestID: requestID,
                    toolName: toolName,
                    arguments: arguments,
                    originalLine: line
                )

                let decision = waitForReviewDecision(
                    reviewDirectory: reviewDirectory,
                    requestID: requestID,
                    requestDigest: requestDigest
                )
                cleanupReviewRequest(reviewDirectory: reviewDirectory, requestID: requestID)

                if decision != .approved {
                    let text: String
                    switch decision {
                    case .approved:
                        text = ""
                    case .denied:
                        text = "The user denied this Clicky Review mode computer-use action."
                    case .invalidDecision:
                        text = "Clicky Review mode rejected a decision because it did not match the exact pending action."
                    case .timedOut:
                        text = "Timed out waiting for the user to approve this Clicky Review mode computer-use action."
                    }
                    send(toolErrorResponse(id: id, text: text))
                    continue
                }

                if let preflightError = try freshObservationPreflight(
                    toolName: toolName,
                    arguments: arguments,
                    childWriter: childWriter,
                    childReader: childReader
                ) {
                    send(toolErrorResponse(id: id, text: preflightError))
                    continue
                }
            }
        }

        try writeLine(line, to: childWriter)

        guard id != nil else {
            continue
        }

        guard let childLine = childReader.readLine() else {
            throw ProxyError.childExited
        }

        if let response = try? jsonObject(from: childLine) {
            switch method {
            case "tools/list":
                send(filterToolsListResponse(response, policy: configuration.policy))
            case "resources/list":
                send(filterResourcesListResponse(response, policy: configuration.policy))
            case "resources/read":
                send(filterResourceReadResponse(response, policy: configuration.policy))
            default:
                send(response)
            }
        } else {
            print(childLine)
            fflush(stdout)
        }
    }
}

do {
    try runProxy()
} catch {
    fputs("ClickyComputerUseMCPProxy: \(error)\n", stderr)
    exit(1)
}
