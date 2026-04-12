//
//  ClickyAssistantFocusContext.swift
//  leanring-buddy
//
//  Canonical focus context shared across assistant backends.
//

import Foundation

struct ClickyAssistantCursorSample: Sendable {
    let x: Double
    let y: Double
    let timestamp: Date
}

struct ClickyAssistantScreenshotFocusContext: Sendable {
    let screenshotLabel: String
    let cursorPixelX: Int
    let cursorPixelY: Int
    let screenshotWidthInPixels: Int
    let screenshotHeightInPixels: Int
    let normalizedCursorX: Double
    let normalizedCursorY: Double
    let cursorToScreenshotDeltaMilliseconds: Int
}

struct ClickyAssistantFocusedElementContext: Sendable {
    let role: String?
    let subrole: String?
    let title: String?
    let label: String?
    let valueDescription: String?
    let isEnabled: Bool?
    let isSelected: Bool?
}

struct ClickyAssistantFocusContext: Sendable {
    let activeDisplayLabel: String
    let cursorX: Double
    let cursorY: Double
    let capturedAt: Date
    let frontmostApplicationName: String?
    let frontmostWindowTitle: String?
    let recentCursorTrail: [ClickyAssistantCursorSample]
    let screenshotContext: ClickyAssistantScreenshotFocusContext?
    let focusedElementContext: ClickyAssistantFocusedElementContext?
}
