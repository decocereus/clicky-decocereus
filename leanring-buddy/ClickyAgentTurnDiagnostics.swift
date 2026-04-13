//
//  ClickyAgentTurnDiagnostics.swift
//  leanring-buddy
//
//  Verbose turn tracing for debugging what Clicky actually sends to and
//  receives from assistant backends.
//

import Foundation

enum ClickyAgentTurnDiagnostics {
    static func logTranscriptCapture(_ transcript: String) {
        ClickyLogger.info(
            .turns,
            """
            turn-transcript-captured
            transcriptLength=\(transcript.count)
            transcript:
            \(transcript)
            """
        )
    }

    static func logCanonicalRequest(
        backend: CompanionAgentBackend,
        request: ClickyAssistantTurnRequest
    ) {
        let imageLabels = request.imageAttachments.map(\.label).joined(separator: "\n- ")
        let conversationHistory = request.conversationHistory.enumerated().map { index, turn in
            """
            exchange \(index + 1):
            user:
            \(turn.userText)
            assistant:
            \(turn.assistantText)
            """
        }.joined(separator: "\n\n")

        ClickyLogger.info(
            .turns,
            """
            turn-canonical-request
            backend=\(backend.displayName)
            systemPromptLength=\(request.systemPrompt.count)
            userPromptLength=\(request.userPrompt.count)
            conversationHistoryCount=\(request.conversationHistory.count)
            imageCount=\(request.imageAttachments.count)
            imageLabels:
            \(imageLabels.isEmpty ? "(none)" : "- \(imageLabels)")

            systemPrompt:
            \(request.systemPrompt)

            userPrompt:
            \(request.userPrompt)

            conversationHistory:
            \(conversationHistory.isEmpty ? "(none)" : conversationHistory)
            """
        )
    }

    static func logProviderRequest(
        backendLabel: String,
        systemPrompt: String,
        userPrompt: String,
        conversationHistoryCount: Int,
        imageLabels: [String],
        extraContext: String? = nil
    ) {
        let formattedExtraContext: String
        if let extraContext,
           !extraContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            formattedExtraContext = "\nextraContext:\n\(extraContext)"
        } else {
            formattedExtraContext = ""
        }

        ClickyLogger.info(
            .turns,
            """
            turn-provider-request
            backend=\(backendLabel)
            systemPromptLength=\(systemPrompt.count)
            userPromptLength=\(userPrompt.count)
            conversationHistoryCount=\(conversationHistoryCount)
            imageCount=\(imageLabels.count)
            imageLabels:
            \(imageLabels.isEmpty ? "(none)" : "- " + imageLabels.joined(separator: "\n- "))

            systemPrompt:
            \(systemPrompt)

            userPrompt:
            \(userPrompt)\(formattedExtraContext)
            """
        )
    }

    static func logOpenClawGatewayDispatch(
        sessionKey: String,
        shellIdentifier: String?,
        agentIdentifier: String?,
        promptContext: String,
        messageBody: String
    ) {
        ClickyLogger.info(
            .turns,
            """
            turn-openclaw-gateway-dispatch
            sessionKey=\(sessionKey)
            shellIdentifier=\(shellIdentifier ?? "(none)")
            agentIdentifier=\(agentIdentifier ?? "(none)")
            promptContextLength=\(promptContext.count)
            messageBodyLength=\(messageBody.count)

            promptContext:
            \(promptContext)

            messageBody:
            \(messageBody)
            """
        )
    }

    static func logRenderedPrompt(
        backendLabel: String,
        prompt: String
    ) {
        ClickyLogger.info(
            .turns,
            """
            turn-rendered-prompt
            backend=\(backendLabel)
            promptLength=\(prompt.count)
            prompt:
            \(prompt)
            """
        )
    }

    static func logRawResponse(
        backend: CompanionAgentBackend,
        response: String
    ) {
        ClickyLogger.info(
            .turns,
            """
            turn-raw-response
            backend=\(backend.displayName)
            responseLength=\(response.count)
            response:
            \(response)
            """
        )
    }

    static func logParsedResponse(
        backend: CompanionAgentBackend,
        spokenResponse: String,
        points: [ClickyAssistantResponsePoint]
    ) {
        let formattedPoints = points.map { point in
            var description = "{x=\(point.x), y=\(point.y), label=\(point.label)"
            if let bubbleText = point.bubbleText, !bubbleText.isEmpty {
                description += ", bubbleText=\(bubbleText)"
            }
            if let explanation = point.explanation, !explanation.isEmpty {
                description += ", explanation=\(explanation)"
            }
            if let screenNumber = point.screenNumber {
                description += ", screenNumber=\(screenNumber)"
            }
            description += "}"
            return description
        }.joined(separator: "\n")

        ClickyLogger.info(
            .turns,
            """
            turn-parsed-response
            backend=\(backend.displayName)
            spokenLength=\(spokenResponse.count)
            pointCount=\(points.count)
            points:
            \(formattedPoints.isEmpty ? "(none)" : formattedPoints)
            spokenResponse:
            \(spokenResponse)
            """
        )
    }

    static func logResponseAudit(
        backend: CompanionAgentBackend,
        originalResponse: String,
        issues: [String]
    ) {
        ClickyLogger.info(
            .turns,
            """
            turn-response-audit
            backend=\(backend.displayName)
            issueCount=\(issues.count)
            issues:
            \(issues.isEmpty ? "(none)" : "- " + issues.joined(separator: "\n- "))

            originalResponse:
            \(originalResponse)
            """
        )
    }

    static func logRepairRequest(
        backend: CompanionAgentBackend,
        repairPrompt: String
    ) {
        ClickyLogger.info(
            .turns,
            """
            turn-repair-request
            backend=\(backend.displayName)
            repairPromptLength=\(repairPrompt.count)
            repairPrompt:
            \(repairPrompt)
            """
        )
    }
}
