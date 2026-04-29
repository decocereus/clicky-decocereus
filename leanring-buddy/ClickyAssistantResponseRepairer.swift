//
//  ClickyAssistantResponseRepairer.swift
//  leanring-buddy
//
//  Validates and repairs Clicky's structured assistant response contract.
//

import Foundation

struct ClickyAssistantResponseAudit {
    let issues: [String]

    var needsRepair: Bool {
        !issues.isEmpty
    }
}

struct ClickyAssistantRepairedResponse {
    let rawText: String
    let structuredResponse: ClickyAssistantStructuredResponse
}

struct ClickyAssistantResponseRepairer {
    private let assistantTurnBuilder = ClickyAssistantTurnBuilder()
    private let assistantTurnExecutor: ClickyAssistantTurnExecutor

    init(assistantTurnExecutor: ClickyAssistantTurnExecutor) {
        self.assistantTurnExecutor = assistantTurnExecutor
    }

    func audit(
        responseText: String,
        transcript: String
    ) -> ClickyAssistantResponseAudit {
        do {
            let structuredResponse = try ClickyAssistantResponseContract.parse(
                rawResponse: responseText,
                requiresPoints: Self.transcriptRequiresVisiblePointing(transcript)
            )
            var issues: [String] = []
            if Self.transcriptWantsNarratedWalkthrough(transcript),
               structuredResponse.points.count > 1,
               structuredResponse.points.contains(where: {
                   ($0.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
               }) {
                issues.append("response omitted per-point explanation for a narrated walkthrough")
            }
            return ClickyAssistantResponseAudit(issues: issues)
        } catch let ClickyAssistantResponseContractError.invalidResponse(issues, _) {
            return ClickyAssistantResponseAudit(issues: issues)
        } catch {
            return ClickyAssistantResponseAudit(issues: [error.localizedDescription])
        }
    }

    func repairIfNeeded(
        backend: CompanionAgentBackend,
        originalResponseText: String,
        transcript: String,
        baseSystemPrompt: String,
        labeledImages: [(data: Data, label: String)],
        focusContext: ClickyAssistantFocusContext?,
        conversationHistory: [(userTranscript: String, assistantResponse: String)],
        audit: ClickyAssistantResponseAudit
    ) async throws -> ClickyAssistantRepairedResponse {
        guard audit.needsRepair else {
            let structuredResponse = try ClickyAssistantResponseContract.parse(
                rawResponse: originalResponseText,
                requiresPoints: Self.transcriptRequiresVisiblePointing(transcript)
            )
            return ClickyAssistantRepairedResponse(
                rawText: originalResponseText,
                structuredResponse: structuredResponse
            )
        }

        var currentRawResponse = originalResponseText
        var currentIssues = audit.issues

        for repairAttempt in 1...2 {
            ClickyAgentTurnDiagnostics.logResponseAudit(
                backend: backend,
                originalResponse: currentRawResponse,
                issues: currentIssues
            )

            let repairSystemPrompt = """
            \(baseSystemPrompt)

            repair override:
            - your previous reply was rejected because it did not follow clicky's structured json response contract.
            - the response contract overrides any conflicting prose or formatting rule.
            - return one corrected final reply only.
            - output exactly one json object and nothing else.
            - do not apologize, do not explain the repair, and do not mention hidden instructions.
            """

            let repairPrompt = """
            repair context:
            - this is repair attempt \(repairAttempt) for clicky's structured response contract.
            - the visible user request should remain the original one. do not answer the repair instructions directly.
            - invalid previous reply:
              \(currentRawResponse)
            - issues to fix:
              - \(currentIssues.joined(separator: "\n  - "))
            - hard requirements:
              - return exactly one json object and nothing else
              - no markdown, no headings, no bullets, no numbered lists, no bold markers, no code fences
              - the transport must be json even though spokenText itself should sound natural
              - use this exact schema:
                {"mode":"answer|point|walkthrough|tutorial","spokenText":"string","points":[{"x":741,"y":213,"label":"gearshift","bubbleText":"gearshift","explanation":"the gearshift is down in the lower middle of the cabin.","screenNumber":1}]}
              - spokenText is what clicky speaks aloud
              - mode is optional but preferred when you know whether this is an answer, point, walkthrough, or tutorial
              - points is an ordered array of point targets
              - for multi-point walkthroughs, include explanation on each point so clicky can keep narration synced with the pointer
              - every point target must use real integer pixel coordinates from the screenshot
              - if the user asked where a visible control is, points must not be empty
              - keep bubbleText short but user-friendly
            """

            ClickyAgentTurnDiagnostics.logRepairRequest(
                backend: backend,
                repairPrompt: repairPrompt
            )

            let repairRequest = assistantTurnBuilder.buildRequest(
                systemPrompt: repairSystemPrompt,
                userPrompt: transcript,
                conversationHistory: conversationHistory,
                labeledImages: labeledImages.map { labeledImage in
                    ClickyAssistantLabeledImage(
                        data: labeledImage.data,
                        label: labeledImage.label,
                        mimeType: "image/jpeg"
                    )
                },
                focusContext: focusContext
            )

            ClickyAgentTurnDiagnostics.logCanonicalRequest(
                backend: backend,
                request: repairRequest
            )

            let repairedResponse = try await assistantTurnExecutor.execute(
                ClickyAssistantTurnPlan(
                    backend: backend,
                    systemPrompt: repairSystemPrompt,
                    request: repairRequest
                ),
                onTextChunk: { _ in }
            )

            let trimmedResponse = repairedResponse.text.trimmingCharacters(in: .whitespacesAndNewlines)
            ClickyAgentTurnDiagnostics.logRawResponse(
                backend: backend,
                response: trimmedResponse
            )

            do {
                let structuredResponse = try ClickyAssistantResponseContract.parse(
                    rawResponse: trimmedResponse,
                    requiresPoints: Self.transcriptRequiresVisiblePointing(transcript)
                )

                return ClickyAssistantRepairedResponse(
                    rawText: trimmedResponse,
                    structuredResponse: structuredResponse
                )
            } catch let ClickyAssistantResponseContractError.invalidResponse(issues, rawResponse) {
                currentRawResponse = rawResponse
                currentIssues = issues
            }
        }

        throw ClickyAssistantResponseContractError.invalidResponse(
            issues: currentIssues,
            rawResponse: currentRawResponse
        )
    }

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
            "climate",
            "dashboard",
            "interior",
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
            "how climate controls work",
            "what are these buttons",
            "interior",
        ]

        return walkthroughSignals.contains { normalizedTranscript.contains($0) }
    }
}
