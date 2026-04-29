//
//  ClickyPointingSequenceController.swift
//  leanring-buddy
//
//  Owns active pointing queue state for the companion overlay.
//

import Foundation

@MainActor
final class ClickyPointingSequenceController {
    private let surfaceController: ClickySurfaceController
    private var pendingTargets: [QueuedPointingTarget] = []
    private var targetArrivalContinuation: CheckedContinuation<Void, Never>?

    private(set) var isManagedSequenceActive = false

    var hasPendingTargets: Bool {
        !pendingTargets.isEmpty
    }

    init(surfaceController: ClickySurfaceController) {
        self.surfaceController = surfaceController
    }

    func clear() {
        pendingTargets.removeAll()
        targetArrivalContinuation?.resume()
        targetArrivalContinuation = nil
        isManagedSequenceActive = false
        surfaceController.detectedElementScreenLocation = nil
        surfaceController.detectedElementDisplayFrame = nil
        surfaceController.detectedElementBubbleText = nil
    }

    func advance() {
        guard !pendingTargets.isEmpty else {
            clear()
            return
        }

        show(pendingTargets.removeFirst())
    }

    func queue(_ targets: [QueuedPointingTarget]) {
        pendingTargets = Array(targets.dropFirst())

        guard let firstTarget = targets.first else {
            clear()
            return
        }

        show(firstTarget)
    }

    func beginManagedSequence() {
        isManagedSequenceActive = true
    }

    func notifyTargetArrived() {
        targetArrivalContinuation?.resume()
        targetArrivalContinuation = nil
    }

    func waitForTargetArrival() async {
        await withCheckedContinuation { continuation in
            targetArrivalContinuation = continuation
        }
    }

    func requestManagedSequenceReturn() {
        isManagedSequenceActive = false
        surfaceController.managedPointSequenceReturnToken += 1
    }

    private func show(_ target: QueuedPointingTarget) {
        surfaceController.detectedElementBubbleText = target.bubbleText
        surfaceController.detectedElementDisplayFrame = target.displayFrame
        surfaceController.detectedElementScreenLocation = target.screenLocation
        ClickyAnalytics.trackElementPointed(elementLabel: target.elementLabel)
    }
}
