//
//  BlueCursorNavigation.swift
//  leanring-buddy
//
//  Navigation mode and flight-path math for the cursor overlay.
//

import CoreGraphics
import Foundation

enum BuddyNavigationMode: Equatable {
    case followingCursor
    case navigatingToTarget
    case pointingAtTarget

    nonisolated static func == (lhs: BuddyNavigationMode, rhs: BuddyNavigationMode) -> Bool {
        switch (lhs, rhs) {
        case (.followingCursor, .followingCursor),
             (.navigatingToTarget, .navigatingToTarget),
             (.pointingAtTarget, .pointingAtTarget):
            return true
        default:
            return false
        }
    }
}

struct BlueCursorFlightFrame {
    let position: CGPoint
    let rotationDegrees: Double
    let scale: CGFloat
}

struct BlueCursorFlightPlan {
    static let frameInterval: Double = 1.0 / 60.0

    let startPosition: CGPoint
    let endPosition: CGPoint
    let controlPoint: CGPoint
    let durationSeconds: Double
    let totalFrames: Int

    init(startPosition: CGPoint, endPosition: CGPoint) {
        self.startPosition = startPosition
        self.endPosition = endPosition

        let deltaX = endPosition.x - startPosition.x
        let deltaY = endPosition.y - startPosition.y
        let distance = hypot(deltaX, deltaY)
        durationSeconds = min(max(distance / 800.0, 0.6), 1.4)
        totalFrames = Int(durationSeconds / Self.frameInterval)

        let midPoint = CGPoint(
            x: (startPosition.x + endPosition.x) / 2.0,
            y: (startPosition.y + endPosition.y) / 2.0
        )
        let arcHeight = min(distance * 0.2, 80.0)
        controlPoint = CGPoint(x: midPoint.x, y: midPoint.y - arcHeight)
    }

    func frame(at frameIndex: Int) -> BlueCursorFlightFrame? {
        guard frameIndex <= totalFrames else {
            return nil
        }

        let linearProgress = Double(frameIndex) / Double(totalFrames)
        let t = linearProgress * linearProgress * (3.0 - 2.0 * linearProgress)
        let oneMinusT = 1.0 - t

        let bezierX = oneMinusT * oneMinusT * startPosition.x
                    + 2.0 * oneMinusT * t * controlPoint.x
                    + t * t * endPosition.x
        let bezierY = oneMinusT * oneMinusT * startPosition.y
                    + 2.0 * oneMinusT * t * controlPoint.y
                    + t * t * endPosition.y

        let tangentX = 2.0 * oneMinusT * (controlPoint.x - startPosition.x)
                     + 2.0 * t * (endPosition.x - controlPoint.x)
        let tangentY = 2.0 * oneMinusT * (controlPoint.y - startPosition.y)
                     + 2.0 * t * (endPosition.y - controlPoint.y)
        let rotationDegrees = atan2(tangentY, tangentX) * (180.0 / .pi) + 90.0

        let scalePulse = sin(linearProgress * .pi)
        let scale = 1.0 + scalePulse * 0.3

        return BlueCursorFlightFrame(
            position: CGPoint(x: bezierX, y: bezierY),
            rotationDegrees: rotationDegrees,
            scale: scale
        )
    }
}
