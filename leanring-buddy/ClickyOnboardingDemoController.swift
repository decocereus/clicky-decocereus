//
//  ClickyOnboardingDemoController.swift
//  leanring-buddy
//
//  Runs the first-launch pointing demo without making CompanionManager own the
//  prompt and screenshot-analysis details.
//

import Foundation

@MainActor
final class ClickyOnboardingDemoController {
    private let claudeAPI: ClaudeAPI
    private let shouldRun: @MainActor () -> Bool
    private let queueTargets: @MainActor ([QueuedPointingTarget]) -> Void

    init(
        claudeAPI: ClaudeAPI,
        shouldRun: @escaping @MainActor () -> Bool,
        queueTargets: @escaping @MainActor ([QueuedPointingTarget]) -> Void
    ) {
        self.claudeAPI = claudeAPI
        self.shouldRun = shouldRun
        self.queueTargets = queueTargets
    }

    func perform() {
        guard shouldRun() else { return }

        Task {
            do {
                let screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()

                guard let cursorScreenCapture = screenCaptures.first(where: { $0.isCursorScreen }) else {
                    ClickyLogger.error(.ui, "Onboarding demo could not find cursor screen")
                    return
                }

                let dimensionInfo = " (image dimensions: \(cursorScreenCapture.screenshotWidthInPixels)x\(cursorScreenCapture.screenshotHeightInPixels) pixels)"
                let labeledImages = [(data: cursorScreenCapture.imageData, label: cursorScreenCapture.label + dimensionInfo)]

                let (fullResponseText, _) = try await claudeAPI.analyzeImageStreaming(
                    images: labeledImages,
                    systemPrompt: Self.systemPrompt,
                    userPrompt: "look around my screen and find something interesting to point at",
                    onTextChunk: { _ in }
                )

                let parseResult = ClickyPointingCoordinator.parsePointingCoordinates(from: fullResponseText)
                let resolvedTargets = ClickyPointingCoordinator.resolvedPointingTargets(
                    from: parseResult.targets,
                    screenCaptures: [cursorScreenCapture]
                )

                guard let firstTarget = resolvedTargets.first else {
                    ClickyLogger.info(.ui, "Onboarding demo did not receive a usable point target")
                    return
                }

                queueTargets([
                    QueuedPointingTarget(
                        screenLocation: firstTarget.screenLocation,
                        displayFrame: firstTarget.displayFrame,
                        elementLabel: firstTarget.elementLabel,
                        bubbleText: parseResult.spokenText
                    )
                ])
                ClickyLogger.info(.ui, "Onboarding demo pointing label=\(firstTarget.elementLabel ?? "element") spokenText=\(parseResult.spokenText)")
            } catch {
                ClickyLogger.error(.ui, "Onboarding demo failed error=\(error.localizedDescription)")
            }
        }
    }

    private static let systemPrompt = """
    you're clicky, a small blue cursor buddy living on the user's screen. you're showing off during onboarding — look at their screen and find ONE specific, concrete thing to point at. pick something with a clear name or identity: a specific app icon (say its name), a specific word or phrase of text you can read, a specific filename, a specific button label, a specific tab title, a specific image you can describe. do NOT point at vague things like "a window" or "some text" — be specific about exactly what you see.

    make a short quirky 3-6 word observation about the specific thing you picked — something fun, playful, or curious that shows you actually read/recognized it. no emojis ever. NEVER quote or repeat text you see on screen — just react to it. keep it to 6 words max, no exceptions.

    CRITICAL COORDINATE RULE: you MUST only pick elements near the CENTER of the screen. your x coordinate must be between 20%-80% of the image width. your y coordinate must be between 20%-80% of the image height. do NOT pick anything in the top 20%, bottom 20%, left 20%, or right 20% of the screen. no menu bar items, no dock icons, no sidebar items, no items near any edge. only things clearly in the middle area of the screen. if the only interesting things are near the edges, pick something boring in the center instead.

    respond with ONLY your short comment followed by the coordinate tag. nothing else. all lowercase.

    format: your comment [POINT:x,y:label|same short comment]

    the screenshot images are labeled with their pixel dimensions. use those dimensions as the coordinate space. origin (0,0) is top-left. x increases rightward, y increases downward.
    """
}
