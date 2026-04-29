//
//  ClickyComputerUseDebugTrace.swift
//  leanring-buddy
//
//  Developer-only trace artifacts for OpenClaw computer-use debugging.
//

import Foundation
import CoreGraphics

@MainActor
final class ClickyComputerUseDebugTrace {
    static let shared = ClickyComputerUseDebugTrace()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private var activeRunDirectory: URL?
    private var activeStepCounter = 0

    private init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder
    }

    var isEnabled: Bool {
        if ProcessInfo.processInfo.environment["CLICKY_COMPUTER_USE_TRACE"] == "0" {
            return false
        }
        if ProcessInfo.processInfo.environment["CLICKY_COMPUTER_USE_TRACE"] == "1" {
            return true
        }
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: "clickyComputerUseTraceEnabled")
        #endif
    }

    func startRun(
        backend: CompanionAgentBackend,
        transcript: String,
        systemPrompt: String,
        userPrompt: String,
        focusContext: ClickyAssistantFocusContext?,
        initialScreens: [CompanionScreenCapture]
    ) {
        guard isEnabled, backend == .openClaw else { return }

        activeStepCounter = 0
        let runID = Self.safeTimestamp() + "-" + String(UUID().uuidString.prefix(8))
        let runDirectory = tracesRootDirectory().appendingPathComponent(runID, isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: runDirectory.appendingPathComponent("screenshots", isDirectory: true),
                withIntermediateDirectories: true
            )
            activeRunDirectory = runDirectory

            let screenshots = saveScreens(initialScreens, prefix: "initial")
            writeJSON(
                [
                    "backend": backend.displayName,
                    "createdAt": ISO8601DateFormatter().string(from: Date()),
                    "focusContext": focusContextSummary(focusContext),
                    "runID": runID,
                    "screenshots": screenshots,
                    "systemPrompt": systemPrompt,
                    "transcript": transcript,
                    "userPrompt": userPrompt,
                ],
                to: runDirectory.appendingPathComponent("initial-turn.json")
            )
            appendEvent("run_started", [
                "backend": backend.displayName,
                "runDirectory": runDirectory.path,
                "screenshotCount": screenshots.count,
                "transcriptLength": transcript.count,
            ])
            ClickyLogger.notice(.computerUse, "trace_started path=\(runDirectory.path)")
        } catch {
            activeRunDirectory = nil
            ClickyLogger.error(.computerUse, "trace_start_failed error=\"\(error.localizedDescription)\"")
        }
    }

    func recordOpenClawDispatch(
        sessionKey: String,
        shellIdentifier: String?,
        agentIdentifier: String?,
        systemPrompt: String,
        userPrompt: String,
        imageLabels: [String],
        messageBody: String
    ) {
        guard let runDirectory = activeRunDirectory else { return }
        writeJSON(
            [
                "agentIdentifier": agentIdentifier ?? "",
                "imageLabels": imageLabels,
                "messageBody": messageBody,
                "sessionKey": sessionKey,
                "shellIdentifier": shellIdentifier ?? "",
                "systemPrompt": systemPrompt,
                "userPrompt": userPrompt,
            ],
            to: runDirectory.appendingPathComponent("openclaw-dispatch.json")
        )
        appendEvent("openclaw_dispatch", [
            "agentIdentifier": agentIdentifier ?? "",
            "imageCount": imageLabels.count,
            "messageBodyLength": messageBody.count,
            "sessionKey": sessionKey,
            "shellIdentifier": shellIdentifier ?? "",
            "systemPromptLength": systemPrompt.count,
        ])
    }

    func recordOpenClawFrame(direction: String, frame: [String: Any]) {
        guard activeRunDirectory != nil else { return }
        appendEvent("openclaw_frame", [
            "direction": direction,
            "frame": Self.sanitize(frame),
        ])
    }

    func beginToolStep(
        route: String,
        requestIdentifier: String,
        actionID: String,
        payload: [String: Any]
    ) async -> Int? {
        guard activeRunDirectory != nil else { return nil }
        activeStepCounter += 1
        let step = activeStepCounter
        appendEvent("tool_request", [
            "actionID": actionID,
            "payload": Self.sanitize(payload),
            "requestId": requestIdentifier,
            "route": route,
            "step": step,
        ])
        _ = await captureAndSaveScreens(prefix: Self.stepPrefix(step, route: route, phase: "before"))
        return step
    }

    func finishToolStep(
        step: Int?,
        route: String,
        requestIdentifier: String,
        actionID: String,
        result: [String: Any]
    ) async {
        guard activeRunDirectory != nil else { return }
        let screenshots = await captureAndSaveScreens(prefix: Self.stepPrefix(step ?? activeStepCounter, route: route, phase: "after"))
        appendEvent("tool_result", [
            "actionID": actionID,
            "requestId": requestIdentifier,
            "result": Self.sanitize(result),
            "route": route,
            "screenshots": screenshots,
            "step": step as Any,
        ])
    }

    func recordToolTerminalResult(
        route: String,
        requestIdentifier: String,
        actionID: String,
        result: [String: Any]
    ) {
        guard activeRunDirectory != nil else { return }
        appendEvent("tool_terminal_result", [
            "actionID": actionID,
            "requestId": requestIdentifier,
            "result": Self.sanitize(result),
            "route": route,
        ])
    }

    func recordAssistantResponse(_ response: String) {
        guard let runDirectory = activeRunDirectory else { return }
        do {
            try response.write(
                to: runDirectory.appendingPathComponent("assistant-response.txt"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            ClickyLogger.error(.computerUse, "trace_response_write_failed error=\"\(error.localizedDescription)\"")
        }
        appendEvent("assistant_response", [
            "responseLength": response.count,
            "responsePreview": String(response.prefix(1200)),
        ])
    }

    private func captureAndSaveScreens(prefix: String) async -> [[String: Any]] {
        do {
            let captures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()
            return saveScreens(captures, prefix: prefix)
        } catch {
            appendEvent("screenshot_capture_failed", [
                "error": error.localizedDescription,
                "prefix": prefix,
            ])
            return []
        }
    }

    private func saveScreens(_ captures: [CompanionScreenCapture], prefix: String) -> [[String: Any]] {
        guard let runDirectory = activeRunDirectory else { return [] }
        let screenshotsDirectory = runDirectory.appendingPathComponent("screenshots", isDirectory: true)

        return captures.enumerated().compactMap { index, capture in
            let filename = "\(prefix)-screen-\(index + 1).jpg"
            let url = screenshotsDirectory.appendingPathComponent(filename)
            do {
                try capture.imageData.write(to: url, options: [.atomic])
                return [
                    "capturedAt": ISO8601DateFormatter().string(from: capture.capturedAt),
                    "displayFrame": [
                        "height": capture.displayFrame.height,
                        "width": capture.displayFrame.width,
                        "x": capture.displayFrame.origin.x,
                        "y": capture.displayFrame.origin.y,
                    ],
                    "isCursorScreen": capture.isCursorScreen,
                    "label": capture.label,
                    "path": url.path,
                    "screenshotHeightInPixels": capture.screenshotHeightInPixels,
                    "screenshotWidthInPixels": capture.screenshotWidthInPixels,
                ]
            } catch {
                appendEvent("screenshot_write_failed", [
                    "error": error.localizedDescription,
                    "path": url.path,
                ])
                return nil
            }
        }
    }

    private func appendEvent(_ event: String, _ fields: [String: Any]) {
        guard let runDirectory = activeRunDirectory else { return }
        var payload = fields
        payload["event"] = event
        payload["timestamp"] = ISO8601DateFormatter().string(from: Date())

        guard let data = try? JSONSerialization.data(withJSONObject: Self.jsonSafe(payload), options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8) else {
            return
        }

        let url = runDirectory.appendingPathComponent("trace.jsonl")
        do {
            if fileManager.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                if let lineData = (line + "\n").data(using: .utf8) {
                    try handle.write(contentsOf: lineData)
                }
                try handle.close()
            } else {
                try (line + "\n").write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            ClickyLogger.error(.computerUse, "trace_event_write_failed event=\(event) error=\"\(error.localizedDescription)\"")
        }
    }

    private func writeJSON(_ object: [String: Any], to url: URL) {
        do {
            let data = try JSONSerialization.data(withJSONObject: Self.jsonSafe(object), options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: [.atomic])
        } catch {
            ClickyLogger.error(.computerUse, "trace_json_write_failed path=\(url.path) error=\"\(error.localizedDescription)\"")
        }
    }

    private func tracesRootDirectory() -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return applicationSupport
            .appendingPathComponent("Clicky", isDirectory: true)
            .appendingPathComponent("ComputerUseTraces", isDirectory: true)
    }

    private func focusContextSummary(_ focusContext: ClickyAssistantFocusContext?) -> [String: Any] {
        guard let focusContext else { return [:] }
        return [
            "activeDisplayLabel": focusContext.activeDisplayLabel,
            "capturedAt": ISO8601DateFormatter().string(from: focusContext.capturedAt),
            "cursorX": focusContext.cursorX,
            "cursorY": focusContext.cursorY,
            "frontmostApplicationName": focusContext.frontmostApplicationName ?? "",
            "frontmostWindowTitle": focusContext.frontmostWindowTitle ?? "",
            "screenshot": focusContext.screenshotContext.map { screenshot in
                [
                    "cursorPixelX": screenshot.cursorPixelX,
                    "cursorPixelY": screenshot.cursorPixelY,
                    "height": screenshot.screenshotHeightInPixels,
                    "label": screenshot.screenshotLabel,
                    "width": screenshot.screenshotWidthInPixels,
                ]
            } ?? [:],
        ]
    }

    private static func sanitize(_ value: Any, depth: Int = 0) -> Any {
        if depth > 8 { return "[truncated-depth]" }
        if let string = value as? String {
            if isLikelyInlineImage(string) {
                return "[omitted inline image \(string.count) chars]"
            }
            if string.count > 24_000 {
                return String(string.prefix(24_000)) + "[truncated \(string.count - 24_000) chars]"
            }
            return string
        }
        if let array = value as? [Any] {
            return array.prefix(500).map { sanitize($0, depth: depth + 1) }
        }
        if let dictionary = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, item) in dictionary {
                if ["content", "data", "imageBase64", "base64"].contains(key),
                   let string = item as? String,
                   isLikelyInlineImage(string) {
                    result[key] = "[omitted inline image \(string.count) chars]"
                } else {
                    result[key] = sanitize(item, depth: depth + 1)
                }
            }
            return result
        }
        return value
    }

    private static func jsonSafe(_ value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            return dictionary.mapValues { jsonSafe($0) }
        case let array as [Any]:
            return array.map { jsonSafe($0) }
        case let number as NSNumber:
            return number
        case let string as String:
            return string
        case let bool as Bool:
            return bool
        case Optional<Any>.none:
            return NSNull()
        default:
            return String(describing: value)
        }
    }

    private static func isLikelyInlineImage(_ string: String) -> Bool {
        string.hasPrefix("data:image/") || (string.count > 80_000 && string.range(of: #"^[A-Za-z0-9+/=]+$"#, options: .regularExpression) != nil)
    }

    private static func stepPrefix(_ step: Int, route: String, phase: String) -> String {
        String(format: "step-%03d-%@-%@", step, route.replacingOccurrences(of: "_", with: "-"), phase)
    }

    private static func safeTimestamp() -> String {
        ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
    }
}
