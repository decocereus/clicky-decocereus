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

    private static func logger(for category: ClickyLogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    static func debug(_ category: ClickyLogCategory, _ message: String) {
        log(category: category, level: .debug, message: message)
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

    private static func log(category: ClickyLogCategory, level: ClickyLogLevel, message: String) {
        logger(for: category).log(level: level.osLogType, "\(message, privacy: .public)")

        Task { @MainActor in
            ClickyDiagnosticsStore.shared.append(
                category: category,
                level: level,
                message: message
            )
        }
    }
}
