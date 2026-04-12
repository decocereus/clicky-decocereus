//
//  ClickyAssistantFocusContextProvider.swift
//  leanring-buddy
//
//  Best-effort macOS focus context capture for assistant turns.
//

import AppKit
import Foundation

@MainActor
final class ClickyAssistantFocusContextProvider {
    private let maximumTrailSampleCount = 5
    private let trailRetentionInterval: TimeInterval = 2.0

    private var recentCursorTrail: [ClickyAssistantCursorSample] = []

    func captureCurrentFocusContext() -> ClickyAssistantFocusContext {
        let now = Date()
        let mouseLocation = NSEvent.mouseLocation
        recordCursorSample(at: mouseLocation, timestamp: now)

        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let frontmostWindowTitle: String?
        if let frontmostApplication {
            frontmostWindowTitle = resolveFrontmostWindowTitle(for: frontmostApplication)
        } else {
            frontmostWindowTitle = nil
        }

        let activeDisplayLabel = activeDisplayLabel(for: mouseLocation)
        let focusedElementContext = resolveFocusedElementContext(for: frontmostApplication)

        return ClickyAssistantFocusContext(
            activeDisplayLabel: activeDisplayLabel,
            cursorX: mouseLocation.x,
            cursorY: mouseLocation.y,
            capturedAt: now,
            frontmostApplicationName: frontmostApplication?.localizedName,
            frontmostWindowTitle: frontmostWindowTitle,
            recentCursorTrail: recentCursorTrail,
            screenshotContext: nil,
            focusedElementContext: focusedElementContext
        )
    }

    func enrich(
        _ focusContext: ClickyAssistantFocusContext,
        with screenCaptures: [CompanionScreenCapture]
    ) -> ClickyAssistantFocusContext {
        guard let activeScreenCapture = resolveActiveScreenCapture(
            for: CGPoint(x: focusContext.cursorX, y: focusContext.cursorY),
            in: screenCaptures
        ) else {
            return focusContext
        }

        let displayFrame = activeScreenCapture.displayFrame
        let displayLocalX = max(0, min(CGFloat(focusContext.cursorX) - displayFrame.origin.x, displayFrame.width))
        let displayLocalYFromBottom = max(0, min(CGFloat(focusContext.cursorY) - displayFrame.origin.y, displayFrame.height))
        let displayLocalYFromTop = displayFrame.height - displayLocalYFromBottom

        let pixelX = Int(
            max(
                0,
                min(
                    round(displayLocalX * CGFloat(activeScreenCapture.screenshotWidthInPixels) / max(displayFrame.width, 1)),
                    CGFloat(activeScreenCapture.screenshotWidthInPixels)
                )
            )
        )
        let pixelY = Int(
            max(
                0,
                min(
                    round(displayLocalYFromTop * CGFloat(activeScreenCapture.screenshotHeightInPixels) / max(displayFrame.height, 1)),
                    CGFloat(activeScreenCapture.screenshotHeightInPixels)
                )
            )
        )

        let normalizedCursorX = activeScreenCapture.screenshotWidthInPixels > 0
            ? Double(pixelX) / Double(activeScreenCapture.screenshotWidthInPixels)
            : 0
        let normalizedCursorY = activeScreenCapture.screenshotHeightInPixels > 0
            ? Double(pixelY) / Double(activeScreenCapture.screenshotHeightInPixels)
            : 0
        let cursorToScreenshotDeltaMilliseconds = max(
            0,
            Int(activeScreenCapture.capturedAt.timeIntervalSince(focusContext.capturedAt) * 1000)
        )

        return ClickyAssistantFocusContext(
            activeDisplayLabel: focusContext.activeDisplayLabel,
            cursorX: focusContext.cursorX,
            cursorY: focusContext.cursorY,
            capturedAt: focusContext.capturedAt,
            frontmostApplicationName: focusContext.frontmostApplicationName,
            frontmostWindowTitle: focusContext.frontmostWindowTitle,
            recentCursorTrail: focusContext.recentCursorTrail,
            screenshotContext: ClickyAssistantScreenshotFocusContext(
                screenshotLabel: activeScreenCapture.label,
                cursorPixelX: pixelX,
                cursorPixelY: pixelY,
                screenshotWidthInPixels: activeScreenCapture.screenshotWidthInPixels,
                screenshotHeightInPixels: activeScreenCapture.screenshotHeightInPixels,
                normalizedCursorX: normalizedCursorX,
                normalizedCursorY: normalizedCursorY,
                cursorToScreenshotDeltaMilliseconds: cursorToScreenshotDeltaMilliseconds
            ),
            focusedElementContext: focusContext.focusedElementContext
        )
    }

    private func recordCursorSample(at point: CGPoint, timestamp: Date) {
        recentCursorTrail.append(
            ClickyAssistantCursorSample(
                x: point.x,
                y: point.y,
                timestamp: timestamp
            )
        )

        recentCursorTrail = recentCursorTrail.filter {
            timestamp.timeIntervalSince($0.timestamp) <= trailRetentionInterval
        }

        if recentCursorTrail.count > maximumTrailSampleCount {
            recentCursorTrail.removeFirst(recentCursorTrail.count - maximumTrailSampleCount)
        }
    }

    private func activeDisplayLabel(for point: CGPoint) -> String {
        if let screenIndex = NSScreen.screens.firstIndex(where: { $0.frame.contains(point) }) {
            if NSScreen.screens.count == 1 {
                return "user's screen"
            }
            return "screen \(screenIndex + 1) of \(NSScreen.screens.count)"
        }

        return "unknown display"
    }

    private func resolveActiveScreenCapture(
        for point: CGPoint,
        in screenCaptures: [CompanionScreenCapture]
    ) -> CompanionScreenCapture? {
        if let matchingCapture = screenCaptures.first(where: { $0.displayFrame.contains(point) }) {
            return matchingCapture
        }

        return screenCaptures.first(where: { $0.isCursorScreen })
    }

    private func resolveFrontmostWindowTitle(for application: NSRunningApplication) -> String? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windowList {
            let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t
            guard ownerPID == application.processIdentifier else { continue }

            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }

            let title = (window[kCGWindowName as String] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let title, !title.isEmpty {
                return title
            }
        }

        return nil
    }

    private func resolveFocusedElementContext(
        for application: NSRunningApplication?
    ) -> ClickyAssistantFocusedElementContext? {
        guard WindowPositionManager.hasAccessibilityPermission(),
              let application else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let focusedElement = copyAXElementAttribute(
            from: appElement,
            attribute: kAXFocusedUIElementAttribute as CFString
        ) else {
            return nil
        }

        let role = copyAXStringAttribute(from: focusedElement, attribute: kAXRoleAttribute as CFString)
        let subrole = copyAXStringAttribute(from: focusedElement, attribute: kAXSubroleAttribute as CFString)
        let title = copyAXStringAttribute(from: focusedElement, attribute: kAXTitleAttribute as CFString)
        let label = copyAXStringAttribute(from: focusedElement, attribute: kAXDescriptionAttribute as CFString)
        let valueDescription = copyAXValueDescription(from: focusedElement)
        let isEnabled = copyAXBoolAttribute(from: focusedElement, attribute: kAXEnabledAttribute as CFString)
        let isSelected = copyAXBoolAttribute(from: focusedElement, attribute: kAXSelectedAttribute as CFString)

        if role == nil,
           subrole == nil,
           title == nil,
           label == nil,
           valueDescription == nil,
           isEnabled == nil,
           isSelected == nil {
            return nil
        }

        return ClickyAssistantFocusedElementContext(
            role: role,
            subrole: subrole,
            title: title,
            label: label,
            valueDescription: valueDescription,
            isEnabled: isEnabled,
            isSelected: isSelected
        )
    }

    private func copyAXElementAttribute(
        from element: AXUIElement,
        attribute: CFString
    ) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func copyAXStringAttribute(
        from element: AXUIElement,
        attribute: CFString
    ) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        if let stringValue = value as? String {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }

    private func copyAXBoolAttribute(
        from element: AXUIElement,
        attribute: CFString
    ) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        return nil
    }

    private func copyAXValueDescription(from element: AXUIElement) -> String? {
        if let value = copyAXStringAttribute(from: element, attribute: kAXValueAttribute as CFString) {
            return value
        }

        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &rawValue) == .success,
              let rawValue else {
            return nil
        }

        if let number = rawValue as? NSNumber {
            return number.stringValue
        }

        return nil
    }
}
