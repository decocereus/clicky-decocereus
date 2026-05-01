//
//  ClickyAssistantTurnContextBuilder.swift
//  leanring-buddy
//
//  Captures screen/focus context and builds canonical assistant turn plans.
//

import Foundation

struct ClickyAssistantTurnContext {
    let screenCaptures: [CompanionScreenCapture]
    let labeledImages: [(data: Data, label: String)]
    let focusContext: ClickyAssistantFocusContext
}

@MainActor
final class ClickyAssistantTurnContextBuilder {
    private let focusContextProvider: ClickyAssistantFocusContextProvider
    private let basePromptSource: ClickyAssistantBasePromptSource
    private let systemPromptPlanner: ClickyAssistantSystemPromptPlanner
    private let mcpServerConfigurationProvider: @MainActor () -> [ClickyAssistantMCPServerConfiguration]
    private let turnBuilder = ClickyAssistantTurnBuilder()

    init(
        focusContextProvider: ClickyAssistantFocusContextProvider,
        basePromptSource: ClickyAssistantBasePromptSource,
        systemPromptPlanner: ClickyAssistantSystemPromptPlanner,
        mcpServerConfigurationProvider: @escaping @MainActor () -> [ClickyAssistantMCPServerConfiguration] = { [] }
    ) {
        self.focusContextProvider = focusContextProvider
        self.basePromptSource = basePromptSource
        self.systemPromptPlanner = systemPromptPlanner
        self.mcpServerConfigurationProvider = mcpServerConfigurationProvider
    }

    func captureContext(backend: CompanionAgentBackend) async throws -> ClickyAssistantTurnContext {
        let initialFocusContext = focusContextProvider.captureCurrentFocusContext()
        let screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG(
            cursorLocationOverride: CGPoint(
                x: initialFocusContext.cursorX,
                y: initialFocusContext.cursorY
            )
        )

        let labeledImages = screenCaptures.map { capture in
            let dimensionInfo = " (image dimensions: \(capture.screenshotWidthInPixels)x\(capture.screenshotHeightInPixels) pixels)"
            return (data: capture.imageData, label: capture.label + dimensionInfo)
        }

        let focusContext = focusContextProvider.enrich(
            initialFocusContext,
            with: screenCaptures
        )
        ClickyLogger.debug(
            .agent,
            "focus-context backend=\(backend.displayName) display=\(focusContext.activeDisplayLabel) app=\(focusContext.frontmostApplicationName ?? "unknown") window=\(focusContext.frontmostWindowTitle ?? "unknown") cursor=(\(Int(focusContext.cursorX)),\(Int(focusContext.cursorY))) screenshotCursor=(\(focusContext.screenshotContext?.cursorPixelX ?? -1),\(focusContext.screenshotContext?.cursorPixelY ?? -1)) deltaMs=\(focusContext.screenshotContext?.cursorToScreenshotDeltaMilliseconds ?? -1) trailCount=\(focusContext.recentCursorTrail.count)"
        )

        return ClickyAssistantTurnContext(
            screenCaptures: screenCaptures,
            labeledImages: labeledImages,
            focusContext: focusContext
        )
    }

    func makePlan(
        backend: CompanionAgentBackend,
        authorization: LaunchAssistantTurnAuthorization,
        transcript: String,
        context: ClickyAssistantTurnContext,
        conversationHistory: [(userTranscript: String, assistantResponse: String)]
    ) -> ClickyAssistantTurnPlan {
        let mcpServers = backend.supportsMCPServerConfiguration ? mcpServerConfigurationProvider() : []
        let systemPrompt = systemPromptPlanner.buildSystemPrompt(
            basePrompt: basePromptSource.basePrompt(for: backend),
            launchMode: authorization.promptMode,
            mcpServers: mcpServers
        )

        let request = turnBuilder.buildRequest(
            systemPrompt: systemPrompt,
            userPrompt: transcript,
            conversationHistory: conversationHistory,
            labeledImages: context.labeledImages.map { labeledImage in
                ClickyAssistantLabeledImage(
                    data: labeledImage.data,
                    label: labeledImage.label,
                    mimeType: "image/jpeg"
                )
            },
            focusContext: context.focusContext,
            mcpServers: mcpServers
        )

        ClickyAgentTurnDiagnostics.logCanonicalRequest(
            backend: backend,
            request: request
        )

        return ClickyAssistantTurnPlan(
            backend: backend,
            systemPrompt: systemPrompt,
            request: request
        )
    }
}
