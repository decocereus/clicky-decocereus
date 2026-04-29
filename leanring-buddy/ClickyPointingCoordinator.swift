//
//  ClickyPointingCoordinator.swift
//  leanring-buddy
//
//  Pure helpers for turning assistant point responses into overlay targets.
//

import Foundation
import SwiftUI

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

struct PointingParseResult {
    let spokenText: String
    let targets: [ParsedPointingTarget]
}

struct ManagedPointNarrationStep {
    let spokenText: String
}

enum ClickyPointingCoordinator {
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
        let explicitSteps: [ManagedPointNarrationStep] = responsePoints.compactMap { responsePoint -> ManagedPointNarrationStep? in
            let trimmedExplanation = responsePoint.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedExplanation.isEmpty else { return nil }
            return ManagedPointNarrationStep(spokenText: trimmedExplanation)
        }

        if explicitSteps.count == responsePoints.count {
            return explicitSteps
        }

        return responsePoints.map { responsePoint in
            ManagedPointNarrationStep(
                spokenText: fallbackNarrationText(for: responsePoint)
            )
        }
    }

    static func parsePointingCoordinates(from responseText: String) -> PointingParseResult {
        let pattern = #"\[POINT:[^\]]+\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return PointingParseResult(spokenText: responseText, targets: [])
        }

        let matches = regex.matches(in: responseText, range: NSRange(responseText.startIndex..., in: responseText))
        guard !matches.isEmpty else {
            return PointingParseResult(spokenText: responseText, targets: [])
        }

        let strippedText = regex.stringByReplacingMatches(
            in: responseText,
            range: NSRange(responseText.startIndex..., in: responseText),
            withTemplate: ""
        )
        let spokenText = strippedText
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parsedTargets = matches.compactMap { match -> ParsedPointingTarget? in
            guard let matchRange = Range(match.range, in: responseText) else {
                return nil
            }

            let fullTag = String(responseText[matchRange])
            let body = fullTag
                .replacingOccurrences(of: "[POINT:", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard body.lowercased() != "none" else {
                return nil
            }

            return parsePointingTargetBody(body)
        }

        return PointingParseResult(
            spokenText: spokenText,
            targets: parsedTargets
        )
    }

    private static func bubbleText(for point: ClickyAssistantResponsePoint) -> String {
        let trimmedLabel = point.label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBubbleText = point.bubbleText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let genericBubbleTexts = Set([
            "screen",
            "display",
            "controls",
            "control",
            "wheel",
            "panel",
            "seat",
            "seats",
            "light",
        ])

        if trimmedBubbleText.isEmpty {
            return trimmedLabel
        }

        if genericBubbleTexts.contains(trimmedBubbleText.lowercased()),
           !trimmedLabel.isEmpty {
            return friendlyBubbleDisplayText(from: trimmedLabel)
        }

        return friendlyBubbleDisplayText(from: trimmedBubbleText)
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

    private static func fallbackNarrationText(for point: ClickyAssistantResponsePoint) -> String {
        let label = point.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch label {
        case let value where value.contains("climate control"):
            return "this whole panel is the climate control section."
        case let value where value.contains("driver temperature"):
            return "this adjusts the driver temperature."
        case let value where value.contains("passenger temperature"):
            return "this adjusts the passenger temperature."
        case let value where value.contains("fan speed"):
            return "these controls change the fan speed."
        case let value where value.contains("hazard"):
            return "this is the hazard light button."
        case let value where value.contains("front defogger"):
            return "this clears the front windshield."
        case let value where value.contains("rear defogger"):
            return "this clears the rear window."
        case let value where value.contains("air recirculation"):
            return "this recirculates the air inside the cabin."
        case let value where value.contains("airflow"):
            return "this changes where the air blows."
        case let value where value == "sync":
            return "this syncs both sides together."
        case let value where value == "ac":
            return "this turns the cooling on or off."
        case let value where value.contains("auto mode"):
            return "this lets the car manage the climate automatically."
        case let value where value.contains("panoramic sunroof"):
            return "this is the panoramic sunroof."
        case let value where value.contains("infotainment screen"):
            return "this is the infotainment screen."
        case let value where value.contains("center air vents"):
            return "these are the center air vents."
        case let value where value.contains("steering wheel"):
            return "this is the steering wheel."
        case let value where value.contains("driver display"):
            return "this is the driver display."
        case let value where value.contains("horn"):
            return "this center pad is the horn."
        case let value where value.contains("phone button"):
            return "this button handles calls."
        case let value where value.contains("voice assistant button"):
            return "this button triggers the voice assistant."
        case let value where value.contains("left steering buttons"):
            return "this cluster handles media and phone controls."
        case let value where value.contains("call and voice controls"):
            return "these buttons handle calls and voice assistant."
        case let value where value.contains("volume and track controls"):
            return "these buttons adjust volume and tracks."
        case let value where value.contains("mode button"):
            return "this usually switches mode or source."
        case let value where value.contains("back or hangup"):
            return "this is usually back or hang up."
        case let value where value.contains("right steering buttons"):
            return "this cluster handles driving and display controls."
        case let value where value.contains("cruise control"):
            return "these are the cruise control buttons."
        case let value where value.contains("speed set resume"):
            return "this is usually for set and resume."
        case let value where value.contains("display navigation"):
            return "this moves through the driver display."
        case let value where value.contains("driver instrument display"):
            return "this is the driver instrument display."
        case let value where value.contains("gearshift"):
            return "this is the gearshift."
        case let value where value.contains("ambient lighting"):
            return "this is the ambient lighting strip."
        case let value where value.contains("front seats"):
            return "these are the front seats."
        default:
            return "this is the \(label)."
        }
    }

    private static func friendlyBubbleDisplayText(from sourceText: String) -> String {
        let trimmedSourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSourceText.isEmpty else { return sourceText }

        let replacements: [String: String] = [
            "ac": "A/C",
            "recirc": "Recirculation",
            "driver temp": "Driver Temp",
            "passenger temp": "Passenger Temp",
            "auto": "Auto Mode",
            "climate": "Climate Panel",
            "fan": "Fan Speed",
            "screen": "Center Screen",
            "wheel": "Steering Wheel",
            "light": "Ambient Light",
            "voice": "Voice Assist",
            "calls": "Call Control",
            "display": "Driver Display",
            "cruise": "Cruise Control",
            "back": "Back / End",
            "mode": "Source Mode",
            "media": "Media Control",
            "set resume": "Set / Resume",
            "hazard": "Hazard Lights",
            "front defog": "Front Defog",
            "rear defog": "Rear Defog",
            "airflow": "Airflow Mode",
        ]

        let loweredSourceText = trimmedSourceText.lowercased()
        if let replacement = replacements[loweredSourceText] {
            return replacement
        }

        return trimmedSourceText
            .split(separator: " ")
            .map { word in
                let loweredWord = word.lowercased()
                if loweredWord == "ac" {
                    return "A/C"
                }
                return loweredWord.prefix(1).uppercased() + loweredWord.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func parsePointingTargetBody(_ body: String) -> ParsedPointingTarget? {
        let parts = body.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let coordinateAndMetadata = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitBubbleText = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        let coordinateSegments = coordinateAndMetadata.split(separator: ":", omittingEmptySubsequences: false)
        guard let coordinateSegment = coordinateSegments.first else { return nil }

        let coordinateParts = coordinateSegment.split(separator: ",", omittingEmptySubsequences: false)
        guard coordinateParts.count == 2,
              let x = Double(String(coordinateParts[0]).trimmingCharacters(in: .whitespacesAndNewlines)),
              let y = Double(String(coordinateParts[1]).trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        var screenNumber: Int?
        var labelComponents: [String] = []

        for segment in coordinateSegments.dropFirst() {
            let trimmedSegment = String(segment).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSegment.isEmpty else { continue }

            if trimmedSegment.lowercased().hasPrefix("screen"),
               let parsedScreenNumber = Int(trimmedSegment.dropFirst("screen".count)),
               parsedScreenNumber >= 1 {
                screenNumber = parsedScreenNumber
            } else {
                labelComponents.append(String(trimmedSegment))
            }
        }

        let elementLabel = labelComponents.isEmpty ? nil : labelComponents.joined(separator: ":")
        let bubbleText = explicitBubbleText.isEmpty ? elementLabel : explicitBubbleText

        return ParsedPointingTarget(
            coordinate: CGPoint(x: x, y: y),
            elementLabel: elementLabel,
            screenNumber: screenNumber,
            bubbleText: bubbleText
        )
    }
}
