//
//  ClickyAssistantFocusContextFormatter.swift
//  leanring-buddy
//
//  Compact text formatter for canonical focus context.
//

import Foundation

struct ClickyAssistantFocusContextFormatter {
    func formattedText(for focusContext: ClickyAssistantFocusContext) -> String {
        let timestamp = ISO8601DateFormatter().string(from: focusContext.capturedAt)
        let trailText: String

        if focusContext.recentCursorTrail.isEmpty {
            trailText = "none"
        } else {
            trailText = focusContext.recentCursorTrail.map { sample in
                let sampleTimestamp = ISO8601DateFormatter().string(from: sample.timestamp)
                return "(\(Int(sample.x)), \(Int(sample.y)) @ \(sampleTimestamp))"
            }.joined(separator: ", ")
        }

        let screenshotContextText: String
        if let screenshotContext = focusContext.screenshotContext {
            screenshotContextText = """
            - screenshot-aligned cursor: (\(screenshotContext.cursorPixelX), \(screenshotContext.cursorPixelY)) in \(screenshotContext.screenshotWidthInPixels)x\(screenshotContext.screenshotHeightInPixels) pixels for \(screenshotContext.screenshotLabel)
            - screenshot-aligned normalized cursor: (\(String(format: "%.3f", screenshotContext.normalizedCursorX)), \(String(format: "%.3f", screenshotContext.normalizedCursorY)))
            - cursor to screenshot delta: \(screenshotContext.cursorToScreenshotDeltaMilliseconds) ms
            """
        } else {
            screenshotContextText = "- screenshot-aligned cursor: unavailable"
        }

        let focusedElementText: String
        if let focusedElement = focusContext.focusedElementContext {
            focusedElementText = """
            - focused element role: \(focusedElement.role ?? "unknown")
            - focused element subrole: \(focusedElement.subrole ?? "unknown")
            - focused element title: \(focusedElement.title ?? "unknown")
            - focused element label: \(focusedElement.label ?? "unknown")
            - focused element value: \(focusedElement.valueDescription ?? "unknown")
            - focused element enabled: \(focusedElement.isEnabled.map(String.init(describing:)) ?? "unknown")
            - focused element selected: \(focusedElement.isSelected.map(String.init(describing:)) ?? "unknown")
            """
        } else {
            focusedElementText = "- focused element metadata: unavailable"
        }

        return """
        Focus context for this turn:
        - active display: \(focusContext.activeDisplayLabel)
        - cursor position: (\(Int(focusContext.cursorX)), \(Int(focusContext.cursorY))) in global AppKit screen coordinates
        - captured at: \(timestamp)
        - frontmost application: \(focusContext.frontmostApplicationName ?? "unknown")
        - frontmost window title: \(focusContext.frontmostWindowTitle ?? "unknown")
        - recent cursor trail: \(trailText)
        \(screenshotContextText)
        \(focusedElementText)
        """
    }
}
