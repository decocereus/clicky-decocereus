//
//  ClickyUnifiedTelemetry.swift
//  leanring-buddy
//
//  Focused unified logging categories for stable runtime observability.
//

import Foundation
import OSLog

enum ClickyUnifiedTelemetry {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.yourcompany.leanring-buddy"

    static let lifecycle = Logger(subsystem: subsystem, category: "Lifecycle")
    static let windowing = Logger(subsystem: subsystem, category: "Windowing")
    static let navigation = Logger(subsystem: subsystem, category: "Navigation")
    static let voiceRouting = Logger(subsystem: subsystem, category: "VoiceRouting")
}
