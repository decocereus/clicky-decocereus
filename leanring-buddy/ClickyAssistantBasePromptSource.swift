//
//  ClickyAssistantBasePromptSource.swift
//  leanring-buddy
//
//  Backend-specific base prompt lookup for Clicky's assistant turn planning.
//

import Foundation

struct ClickyAssistantBasePromptSource {
    let promptForBackend: @MainActor @Sendable (CompanionAgentBackend) -> String

    @MainActor
    func basePrompt(for backend: CompanionAgentBackend) -> String {
        promptForBackend(backend)
    }
}
