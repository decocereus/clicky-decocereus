//
//  ClickyTutorialModeSupport.swift
//  leanring-buddy
//
//  Prompt and intent helpers for active tutorial mode.
//

import Foundation

enum ClickyTutorialModeIntentMatcher {
    static func shouldAdvanceStep(_ normalizedTranscript: String) -> Bool {
        ["done", "i'm done", "im done", "next", "go next", "finished", "move on", "continue"]
            .contains(where: { normalizedTranscript.contains($0) })
    }

    static func shouldRepeatCurrentStep(_ normalizedTranscript: String) -> Bool {
        ["repeat", "say that again", "what was step", "what do i do now", "what now", "current step"]
            .contains(where: { normalizedTranscript.contains($0) })
    }

    static func shouldListSteps(_ normalizedTranscript: String) -> Bool {
        ["what are the steps", "list the steps", "show steps", "all steps"]
            .contains(where: { normalizedTranscript.contains($0) })
    }

    static func shouldStopTutorialMode(_ normalizedTranscript: String) -> Bool {
        ["done with this tutorial", "stop tutorial", "exit tutorial", "leave tutorial mode"]
            .contains(where: { normalizedTranscript.contains($0) })
    }

    static func isImportIntent(_ normalizedTranscript: String) -> Bool {
        let mentionsTutorial = normalizedTranscript.contains("tutorial")
            || normalizedTranscript.contains("youtube")
            || normalizedTranscript.contains("video")
            || normalizedTranscript.contains("learn this")
            || normalizedTranscript.contains("learn from this")

        let asksForHelp = normalizedTranscript.contains("help me")
            || normalizedTranscript.contains("walk me through")
            || normalizedTranscript.contains("guide me")
            || normalizedTranscript.contains("work on this")
            || normalizedTranscript.contains("teach me")

        let directImportRequest = normalizedTranscript.contains("i want to work on this tutorial")
            || normalizedTranscript.contains("help with this tutorial")
            || normalizedTranscript.contains("help me with this tutorial")
            || normalizedTranscript.contains("help me with a youtube tutorial")
            || normalizedTranscript.contains("learn this youtube video")

        return directImportRequest || (mentionsTutorial && asksForHelp)
    }
}

enum ClickyTutorialModePromptBuilder {
    static func systemPrompt() -> String {
        """
        You are Clicky in tutorial mode.

        The user is actively following a software tutorial. Treat tutorial mode as a persistent guided session, not a normal detached chat.

        Rules:
        - stay grounded in the current tutorial, current step, lesson draft, and extracted evidence
        - answer the user in the context of completing this tutorial
        - use the associated YouTube video only as a reference, not the main product surface
        - prefer helping the user complete the current step before jumping elsewhere
        - when helpful, point at the relevant UI element using the shared Clicky response contract
        - if the user sounds stuck, explain clearly and practically
        - if the user asks what the tutorial is doing, summarize it using the lesson and evidence
        - if the user asks unrelated questions, answer briefly but remain in tutorial mode unless they explicitly end the tutorial

        \(ClickyAssistantResponseContract.promptInstructions)
        """
    }

    static func userPrompt(
        transcript: String,
        tutorialSessionState: TutorialSessionState,
        currentStep: TutorialLessonStep,
        conversationHistory: [(userTranscript: String, assistantResponse: String)]
    ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let lessonJSONString = (try? String(
            decoding: encoder.encode(tutorialSessionState.lessonDraft),
            as: UTF8.self
        )) ?? "{}"
        let evidenceJSONString = (try? String(
            decoding: encoder.encode(tutorialSessionState.evidenceBundle),
            as: UTF8.self
        )) ?? "{}"

        let historyText = conversationHistory
            .suffix(6)
            .map { turn in
                "user: \(turn.userTranscript)\nassistant: \(turn.assistantResponse)"
            }
            .joined(separator: "\n\n")

        return """
        Tutorial mode is active.

        User utterance:
        \(transcript)

        Current step index: \(tutorialSessionState.currentStepIndex + 1)
        Current step title: \(currentStep.title)
        Current step instruction: \(currentStep.instruction)
        Current step verification hint: \(currentStep.verificationHint ?? "none")
        Associated tutorial video: \(tutorialSessionState.evidenceBundle.source.url)

        Lesson draft JSON:
        \(lessonJSONString)

        Evidence bundle JSON:
        \(evidenceJSONString)

        Recent tutorial conversation:
        \(historyText.isEmpty ? "none" : historyText)
        """
    }
}
