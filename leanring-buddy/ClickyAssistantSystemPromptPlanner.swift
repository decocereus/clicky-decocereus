//
//  ClickyAssistantSystemPromptPlanner.swift
//  leanring-buddy
//
//  Applies transport-neutral prompt policy to backend-specific base prompts.
//

import Foundation

enum ClickyAssistantLaunchPromptMode: Sendable {
    case standard
    case welcome
    case paywall
}

struct ClickyAssistantSystemPromptPlanner {
    func buildSystemPrompt(
        basePrompt: String,
        launchMode: ClickyAssistantLaunchPromptMode
    ) -> String {
        switch launchMode {
        case .standard:
            return basePrompt
        case .welcome:
            return """
            \(basePrompt)

            launch onboarding override:
            - this is the first real clicky turn after setup completed.
            - give a short, warm welcome that explains what clicky can help with on the user's screen and through voice.
            - mention that they are in a limited launch trial, but keep it light and helpful rather than salesy.
            - answer the user's request normally if they already asked for something concrete.
            - if their first request is vague, steer them toward one or two concrete things clicky can do right now.
            - keep the reply compact and natural.
            """
        case .paywall:
            return """
            \(basePrompt)

            launch commerce override:
            - the user's clicky launch trial is exhausted.
            - do not answer their request or partially complete the task.
            - instead, give a short spoken paywall message that says clicky now requires purchase to continue.
            - if it fits naturally, briefly acknowledge the kind of thing they were trying to do, but do not provide the actual help.
            - direct them to buy or restore access in clicky's studio window.
            - keep the reply warm and natural, not robotic.
            - return the structured response contract with an empty points array.
            """
        }
    }
}
