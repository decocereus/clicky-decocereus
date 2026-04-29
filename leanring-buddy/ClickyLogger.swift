//
//  ClickyLogger.swift
//  leanring-buddy
//
//  Unified logging + lightweight in-app diagnostics store.
//

import Combine
import Foundation
import OSLog

enum ClickyLogCategory: String {
    case app
    case audio
    case agent
    case computerUse = "ComputerUse"
    case turns
    case gateway
    case plugin
    case ui
}

enum ClickyLogLevel {
    case debug
    case info
    case notice
    case error

    var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .notice:
            return .default
        case .error:
            return .error
        }
    }

    var label: String {
        switch self {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .notice:
            return "NOTICE"
        case .error:
            return "ERROR"
        }
    }
}

struct ClickyLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: ClickyLogCategory
    let level: ClickyLogLevel
    let message: String
}

@MainActor
final class ClickyDiagnosticsStore: ObservableObject {
    static let shared = ClickyDiagnosticsStore()

    @Published private(set) var entries: [ClickyLogEntry] = []

    private let maximumEntryCount = 400

    private init() {}

    func append(category: ClickyLogCategory, level: ClickyLogLevel, message: String) {
        entries.append(
            ClickyLogEntry(
                timestamp: Date(),
                category: category,
                level: level,
                message: message
            )
        )

        if entries.count > maximumEntryCount {
            entries.removeFirst(entries.count - maximumEntryCount)
        }
    }

    func clear() {
        entries.removeAll()
    }

    func formattedRecentLogText(limit: Int = 100) -> String {
        let formatter = ISO8601DateFormatter()
        return entries.suffix(limit).map { entry in
            "\(formatter.string(from: entry.timestamp)) [\(entry.level.label)] [\(entry.category.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}

enum ClickyLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "so.clicky.app"
    private static let verboseTurnDiagnosticsKey = "clickyVerboseTurnDiagnostics"

    private static func logger(for category: ClickyLogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    static func debug(_ category: ClickyLogCategory, _ message: String) {
        log(category: category, level: .debug, message: message)
    }

    static func verboseTurn(_ message: String) {
        guard verboseTurnDiagnosticsEnabled else { return }
        log(category: .turns, level: .debug, message: message)
    }

    static func info(_ category: ClickyLogCategory, _ message: String) {
        log(category: category, level: .info, message: message)
    }

    static func notice(_ category: ClickyLogCategory, _ message: String) {
        log(category: category, level: .notice, message: message)
    }

    static func error(_ category: ClickyLogCategory, _ message: String) {
        log(category: category, level: .error, message: message)
    }

    static func redactForDiagnostics(_ text: String) -> String {
        ClickyLogRedactor.redact(text)
    }

    static var verboseTurnDiagnosticsEnabled: Bool {
        if ProcessInfo.processInfo.environment["CLICKY_VERBOSE_TURN_LOGS"] == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: verboseTurnDiagnosticsKey)
    }

    private static func log(category: ClickyLogCategory, level: ClickyLogLevel, message: String) {
        if category == .turns, !verboseTurnDiagnosticsEnabled, level != .error {
            return
        }

        let redactedMessage = ClickyLogRedactor.redact(message)
        logger(for: category).log(level: level.osLogType, "\(redactedMessage, privacy: .public)")

        Task { @MainActor in
            ClickyDiagnosticsStore.shared.append(
                category: category,
                level: level,
                message: redactedMessage
            )
        }
    }
}

private enum ClickyLogRedactor {
    private static let knownSecretAccounts = [
        "elevenlabs_api_key",
    ]

    private static let userDefaultSecretKeys = [
        "openClawGatewayAuthToken",
    ]

    static func redact(_ message: String) -> String {
        var redactedMessage = message

        let patternReplacements: [(String, String)] = [
            (#"(?i)(authorization\s*[:=]\s*bearer\s+)[^\s,]+"#, "$1[REDACTED]"),
            (#"(?i)(\"api[_-]?key\"\s*:\s*\")[^\"]+(\")"#, "$1[REDACTED]$2"),
            (#"(?i)(\"access[_-]?token\"\s*:\s*\")[^\"]+(\")"#, "$1[REDACTED]$2"),
            (#"(?i)(\"refresh[_-]?token\"\s*:\s*\")[^\"]+(\")"#, "$1[REDACTED]$2"),
            (#"(?i)(\"session[_-]?token\"\s*:\s*\")[^\"]+(\")"#, "$1[REDACTED]$2"),
            (#"(?i)(\"id[_-]?token\"\s*:\s*\")[^\"]+(\")"#, "$1[REDACTED]$2"),
            (#"(?i)(\"auth[_-]?token\"\s*:\s*\")[^\"]+(\")"#, "$1[REDACTED]$2"),
            (#"(?i)(\"client[_-]?secret\"\s*:\s*\")[^\"]+(\")"#, "$1[REDACTED]$2"),
            (#"(?i)(\"exchange[_-]?code\"\s*:\s*\")[^\"]+(\")"#, "$1[REDACTED]$2"),
            (#"(?i)(\"state\"\s*:\s*\")[^\"]+(\")"#, "$1[REDACTED]$2"),
            (#"(?i)(api[_ -]?key\s*[:=]\s*)[^\s,]+"#, "$1[REDACTED]"),
            (#"(?i)(token\s*[:=]\s*)[^\s,]+"#, "$1[REDACTED]"),
            (#"(?i)(secret\s*[:=]\s*)[^\s,]+"#, "$1[REDACTED]"),
            (#"(?i)(code=)[^&\s]+"#, "$1[REDACTED]"),
            (#"(?i)(state=)[^&\s]+"#, "$1[REDACTED]"),
            (#"(?i)(authToken=)[^&\s]+"#, "$1[REDACTED]"),
            (#"(?i)(token=)[^&\s]+"#, "$1[REDACTED]"),
            (#"(?i)(secret=)[^&\s]+"#, "$1[REDACTED]"),
        ]

        for (pattern, template) in patternReplacements {
            redactedMessage = replacing(pattern: pattern, in: redactedMessage, with: template)
        }

        for secretValue in sensitiveValues() where !secretValue.isEmpty {
            redactedMessage = redactedMessage.replacingOccurrences(of: secretValue, with: "[REDACTED]")
        }

        return redactedMessage
    }

    private static func sensitiveValues() -> [String] {
        var values: [String] = []

        for account in knownSecretAccounts {
            if let value = ClickySecrets.load(account: account)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                values.append(value)
            }
        }

        for key in userDefaultSecretKeys {
            if let value = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                values.append(value)
            }
        }

        if let storedSession = ClickyAuthSessionStore.load() {
            let trimmedSessionToken = storedSession.sessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSessionToken.isEmpty {
                values.append(trimmedSessionToken)
            }
        }

        return values
    }

    private static func replacing(pattern: String, in source: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return source
        }

        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.stringByReplacingMatches(in: source, range: range, withTemplate: template)
    }
}
