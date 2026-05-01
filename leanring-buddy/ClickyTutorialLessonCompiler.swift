//
//  ClickyTutorialLessonCompiler.swift
//  leanring-buddy
//
//  Turns extracted tutorial evidence into a guided Clicky lesson.
//

import Foundation

struct ClickyTutorialLessonCompiler {
    let assistantTurnExecutor: ClickyAssistantTurnExecutor
    let selectedBackendProvider: @MainActor () -> CompanionAgentBackend

    func compile(
        evidenceBundle: TutorialEvidenceBundle
    ) async throws -> TutorialLessonDraft {
        struct TutorialLessonDraftEnvelope: Decodable {
            let title: String
            let summary: String
            let steps: [TutorialLessonDraftStep]
        }

        struct TutorialLessonDraftStep: Decodable {
            let title: String
            let instruction: String
            let verificationHint: String?
            let sourceStartSeconds: Double?
            let sourceEndSeconds: Double?
            let sourceVideoPromptTimestamp: Int?
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let evidenceJSONData = try encoder.encode(evidenceBundle)
        let evidenceJSONString = String(decoding: evidenceJSONData, as: UTF8.self)

        let systemPrompt = """
        You are compiling a desktop software tutorial for Clicky.

        Return JSON only. No markdown. No prose outside JSON.

        Produce:
        {
          "title": string,
          "summary": string,
          "steps": [
            {
              "title": string,
              "instruction": string,
              "verificationHint": string | null,
              "sourceStartSeconds": number | null,
              "sourceEndSeconds": number | null,
              "sourceVideoPromptTimestamp": number | null
            }
          ]
        }

        Rules:
        - write for a learner following along on their own desktop
        - make each step concrete and actionable
        - prefer six to ten meaningful steps
        - keep titles short
        - keep instructions conversational but clear
        - use the evidence bundle only
        - if structure markers exist, use them to shape the lesson
        - sourceVideoPromptTimestamp should usually point to the most relevant moment for that step
        """

        let userPrompt = """
        Turn this extracted YouTube tutorial evidence into a guided desktop lesson for Clicky.

        Evidence bundle:
        \(evidenceJSONString)
        """

        let request = ClickyAssistantTurnRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            conversationHistory: [],
            imageAttachments: [],
            focusContext: nil,
            mcpServers: []
        )

        let response = try await assistantTurnExecutor.execute(
            ClickyAssistantTurnPlan(
                backend: await selectedBackendProvider(),
                systemPrompt: systemPrompt,
                request: request
            ),
            onTextChunk: { _ in }
        )

        let normalizedJSONText = Self.extractJSONObject(from: response.text)
        let envelope = try JSONDecoder().decode(
            TutorialLessonDraftEnvelope.self,
            from: Data(normalizedJSONText.utf8)
        )

        return TutorialLessonDraft(
            title: envelope.title,
            summary: envelope.summary,
            steps: envelope.steps.map { step in
                TutorialLessonStep(
                    title: step.title,
                    instruction: step.instruction,
                    verificationHint: step.verificationHint,
                    sourceTimeRange: {
                        guard let start = step.sourceStartSeconds,
                              let end = step.sourceEndSeconds else { return nil }
                        return TutorialLessonTimeRange(startSeconds: start, endSeconds: end)
                    }(),
                    sourceVideoPromptTimestamp: step.sourceVideoPromptTimestamp
                )
            },
            createdAt: Date()
        )
    }

    static func extractJSONObject(from responseText: String) -> String {
        guard let startIndex = responseText.firstIndex(of: "{"),
              let endIndex = responseText.lastIndex(of: "}") else {
            return responseText
        }

        return String(responseText[startIndex...endIndex])
    }
}
