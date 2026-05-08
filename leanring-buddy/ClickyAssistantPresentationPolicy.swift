//
//  ClickyAssistantPresentationPolicy.swift
//  leanring-buddy
//
//  Pure helpers for turning structured assistant responses into presentation
//  decisions Clicky can render.
//

import CoreGraphics
import Foundation

struct ParsedPointingTarget {
    let coordinate: CGPoint
    let elementLabel: String?
    let screenNumber: Int?
    let bubbleText: String?
}

struct QueuedPointingTarget {
    let screenLocation: CGPoint
    let displayFrame: CGRect
    let elementLabel: String?
    let bubbleText: String?
}

struct ManagedPointNarrationStep {
    let spokenText: String
}

enum ClickyAssistantPresentationPolicy {
    static func transcriptRequiresVisiblePointing(_ transcript: String) -> Bool {
        let normalizedTranscript = transcript.lowercased()
        let requiredPointingSignals = [
            "point",
            "point out",
            "show me",
            "walk me through",
            "walkthrough",
            "walk through",
            "tour",
            "breakdown",
            "overview",
            "where is",
            "which button",
            "which buttons",
            "which control",
            "which controls",
            "button",
            "buttons",
            "control",
            "controls",
            "dashboard",
            "screen",
            "icon",
            "icons",
        ]

        return requiredPointingSignals.contains { normalizedTranscript.contains($0) }
    }

    static func transcriptWantsNarratedWalkthrough(_ transcript: String) -> Bool {
        let normalizedTranscript = transcript.lowercased()
        let walkthroughSignals = [
            "walk me through",
            "walk-through",
            "walkthrough",
            "walk through",
            "give me a walkthrough",
            "give me a walk-through",
            "talk about a few features",
            "point them out",
            "few features",
            "tour",
            "breakdown",
            "overview",
            "what do they do",
            "how to use them",
            "how to use",
            "what are these buttons",
        ]

        return walkthroughSignals.contains { normalizedTranscript.contains($0) }
    }

    static func parsedPointingTargets(
        from responsePoints: [ClickyAssistantResponsePoint]
    ) -> [ParsedPointingTarget] {
        responsePoints.map { responsePoint in
            ParsedPointingTarget(
                coordinate: CGPoint(x: responsePoint.x, y: responsePoint.y),
                elementLabel: responsePoint.label,
                screenNumber: responsePoint.screenNumber,
                bubbleText: bubbleText(for: responsePoint)
            )
        }
    }

    static func resolvedPointingTargets(
        from parsedTargets: [ParsedPointingTarget],
        screenCaptures: [CompanionScreenCapture]
    ) -> [QueuedPointingTarget] {
        parsedTargets.compactMap { parsedTarget in
            guard let targetScreenCapture = targetScreenCapture(
                for: parsedTarget.screenNumber,
                screenCaptures: screenCaptures
            ) else {
                return nil
            }

            return QueuedPointingTarget(
                screenLocation: globalLocation(
                    for: parsedTarget.coordinate,
                    in: targetScreenCapture
                ),
                displayFrame: targetScreenCapture.displayFrame,
                elementLabel: parsedTarget.elementLabel,
                bubbleText: parsedTarget.bubbleText
            )
        }
    }

    static func managedPointNarrationSteps(
        from responsePoints: [ClickyAssistantResponsePoint]
    ) -> [ManagedPointNarrationStep] {
        guard !responsePoints.isEmpty else { return [] }

        let explicitSteps: [ManagedPointNarrationStep] = responsePoints.compactMap { responsePoint in
            let trimmedExplanation = responsePoint.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedExplanation.isEmpty else { return nil }
            return ManagedPointNarrationStep(spokenText: trimmedExplanation)
        }

        guard explicitSteps.count == responsePoints.count else {
            return []
        }

        return explicitSteps
    }

    private static func bubbleText(for point: ClickyAssistantResponsePoint) -> String {
        let trimmedLabel = point.label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBubbleText = point.bubbleText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let genericBubbleTexts = Set([
            "screen",
            "display",
            "controls",
            "control",
            "panel",
            "button",
            "icon",
            "area",
        ])

        if trimmedBubbleText.isEmpty {
            return trimmedLabel
        }

        if genericBubbleTexts.contains(trimmedBubbleText.lowercased()),
           !trimmedLabel.isEmpty {
            return trimmedLabel
        }

        return trimmedBubbleText
    }

    private static func targetScreenCapture(
        for screenNumber: Int?,
        screenCaptures: [CompanionScreenCapture]
    ) -> CompanionScreenCapture? {
        if let screenNumber,
           screenNumber >= 1 && screenNumber <= screenCaptures.count {
            return screenCaptures[screenNumber - 1]
        }

        return screenCaptures.first(where: { $0.isCursorScreen })
    }

    private static func globalLocation(
        for pointCoordinate: CGPoint,
        in screenCapture: CompanionScreenCapture
    ) -> CGPoint {
        let screenshotWidth = CGFloat(screenCapture.screenshotWidthInPixels)
        let screenshotHeight = CGFloat(screenCapture.screenshotHeightInPixels)
        let displayWidth = CGFloat(screenCapture.displayWidthInPoints)
        let displayHeight = CGFloat(screenCapture.displayHeightInPoints)
        let displayFrame = screenCapture.displayFrame

        let clampedX = max(0, min(pointCoordinate.x, screenshotWidth))
        let clampedY = max(0, min(pointCoordinate.y, screenshotHeight))
        let displayLocalX = clampedX * (displayWidth / screenshotWidth)
        let displayLocalY = clampedY * (displayHeight / screenshotHeight)
        let appKitY = displayHeight - displayLocalY

        return CGPoint(
            x: displayLocalX + displayFrame.origin.x,
            y: appKitY + displayFrame.origin.y
        )
    }
}
