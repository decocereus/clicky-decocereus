//
//  ClickyPersonaPromptCoordinator.swift
//  leanring-buddy
//
//  Owns Clicky persona presentation labels, assistant model labels, and
//  backend system prompts.
//

import Foundation

struct ClickyPersonaPromptSnapshot {
    let selectedBackend: CompanionAgentBackend
    let selectedModel: String
    let codexConfiguredModelName: String?
    let openClawAgentIdentifier: String
    let inferredOpenClawAgentIdentifier: String?
    let effectiveOpenClawAgentName: String
    let personaScopeMode: ClickyPersonaScopeMode
    let personaOverrideName: String
    let personaOverrideInstructions: String
    let activePersonaDefinition: ClickyPersonaDefinition
    let voicePreset: ClickyVoicePreset
    let cursorStyle: ClickyCursorStyle
    let customToneInstructions: String
}

@MainActor
final class ClickyPersonaPromptCoordinator {
    private let snapshotProvider: () -> ClickyPersonaPromptSnapshot

    init(snapshotProvider: @escaping () -> ClickyPersonaPromptSnapshot) {
        self.snapshotProvider = snapshotProvider
    }

    var effectiveSpeechInstructions: String {
        Self.effectiveSpeechInstructions(
            activePersonaDefinition: snapshotProvider().activePersonaDefinition,
            customToneInstructions: snapshotProvider().customToneInstructions
        )
    }

    var effectivePresentationName: String {
        let snapshot = snapshotProvider()
        return Self.effectivePresentationName(
            selectedBackend: snapshot.selectedBackend,
            personaScopeMode: snapshot.personaScopeMode,
            personaOverrideName: snapshot.personaOverrideName,
            effectiveOpenClawAgentName: snapshot.effectiveOpenClawAgentName
        )
    }

    var personaScopeLabel: String {
        Self.personaScopeLabel(for: snapshotProvider().personaScopeMode)
    }

    var activePersonaLabel: String {
        snapshotProvider().activePersonaDefinition.displayName
    }

    var selectedAssistantModelIdentityLabel: String {
        let snapshot = snapshotProvider()
        return Self.selectedAssistantModelIdentityLabel(
            selectedBackend: snapshot.selectedBackend,
            selectedModel: snapshot.selectedModel,
            codexConfiguredModelName: snapshot.codexConfiguredModelName,
            openClawAgentIdentifier: snapshot.openClawAgentIdentifier,
            inferredOpenClawAgentIdentifier: snapshot.inferredOpenClawAgentIdentifier,
            effectiveOpenClawAgentName: snapshot.effectiveOpenClawAgentName
        )
    }

    func companionVoiceResponseSystemPrompt() -> String {
        let snapshot = snapshotProvider()
        return Self.companionVoiceResponseSystemPrompt(
            clickyPresentationName: effectivePresentationName,
            activePersonaName: snapshot.activePersonaDefinition.displayName,
            personaSpeechInstructions: effectiveSpeechInstructions,
            voiceStyle: snapshot.voicePreset.displayName,
            cursorStyle: snapshot.cursorStyle.displayName
        )
    }

    func openClawShellScopedSystemPrompt() -> String {
        let snapshot = snapshotProvider()
        return Self.openClawShellScopedSystemPrompt(
            upstreamOpenClawAgentName: snapshot.effectiveOpenClawAgentName,
            clickyPresentationName: effectivePresentationName,
            localPersonaInstructions: snapshot.personaOverrideInstructions,
            personaSpeechInstructions: effectiveSpeechInstructions,
            activePersonaName: snapshot.activePersonaDefinition.displayName,
            personaScopeMode: snapshot.personaScopeMode,
            voiceStyle: snapshot.voicePreset.displayName,
            cursorStyle: snapshot.cursorStyle.displayName
        )
    }

    func logActivePersonaForRequest(transcript: String, backend: CompanionAgentBackend, systemPrompt: String) {
        let snapshot = snapshotProvider()
        ClickyLogger.notice(
            .agent,
            "request backend=\(backend.displayName) model=\(selectedAssistantModelIdentityLabel) persona=\(activePersonaLabel) display=\(effectivePresentationName) voice=\(snapshot.voicePreset.displayName) cursor=\(snapshot.cursorStyle.displayName) scope=\(personaScopeLabel) transcriptLength=\(transcript.count)"
        )
        ClickyLogger.debug(
            .agent,
            "prompt-shape backend=\(backend.displayName) model=\(selectedAssistantModelIdentityLabel) persona=\(activePersonaLabel) promptLength=\(systemPrompt.count)"
        )
    }

    func logAgentResponse(_ response: String, backend: CompanionAgentBackend) {
        let snapshot = snapshotProvider()
        ClickyLogger.notice(
            .agent,
            "response backend=\(backend.displayName) model=\(selectedAssistantModelIdentityLabel) persona=\(activePersonaLabel) display=\(effectivePresentationName) voice=\(snapshot.voicePreset.displayName) responseLength=\(response.count)"
        )
    }

    static func effectiveSpeechInstructions(
        activePersonaDefinition: ClickyPersonaDefinition,
        customToneInstructions: String
    ) -> String {
        let presetGuidance = activePersonaDefinition.speechGuidance
        let responseContract = activePersonaDefinition.responseContract
        let customTone = customToneInstructions.trimmingCharacters(in: .whitespacesAndNewlines)

        if customTone.isEmpty {
            return "\(presetGuidance) \(responseContract)"
        }

        return "\(presetGuidance) \(responseContract) also follow these clicky-only tone notes: \(customTone)"
    }

    static func effectivePresentationName(
        selectedBackend: CompanionAgentBackend,
        personaScopeMode: ClickyPersonaScopeMode,
        personaOverrideName: String,
        effectiveOpenClawAgentName: String
    ) -> String {
        if selectedBackend != .openClaw {
            let overrideName = personaOverrideName.trimmingCharacters(in: .whitespacesAndNewlines)
            return overrideName.isEmpty ? "Clicky" : overrideName
        }

        if personaScopeMode == .overrideInClicky {
            let overrideName = personaOverrideName.trimmingCharacters(in: .whitespacesAndNewlines)
            return overrideName.isEmpty ? "Clicky" : overrideName
        }

        return effectiveOpenClawAgentName
    }

    static func personaScopeLabel(for mode: ClickyPersonaScopeMode) -> String {
        switch mode {
        case .useOpenClawIdentity:
            return "Use OpenClaw identity"
        case .overrideInClicky:
            return "Override only in Clicky"
        }
    }

    static func selectedAssistantModelIdentityLabel(
        selectedBackend: CompanionAgentBackend,
        selectedModel: String,
        codexConfiguredModelName: String?,
        openClawAgentIdentifier: String,
        inferredOpenClawAgentIdentifier: String?,
        effectiveOpenClawAgentName: String
    ) -> String {
        switch selectedBackend {
        case .claude:
            return selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        case .codex:
            let configuredModel = codexConfiguredModelName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return configuredModel.isEmpty ? "codex" : configuredModel
        case .openClaw:
            let configuredAgentIdentifier = openClawAgentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            if !configuredAgentIdentifier.isEmpty {
                return configuredAgentIdentifier
            }

            let inferredAgentIdentifier = inferredOpenClawAgentIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !inferredAgentIdentifier.isEmpty {
                return inferredAgentIdentifier
            }

            return effectiveOpenClawAgentName
        }
    }

    static func companionVoiceResponseSystemPrompt(
        clickyPresentationName: String,
        activePersonaName: String,
        personaSpeechInstructions: String,
        voiceStyle: String,
        cursorStyle: String
    ) -> String {
        """
    you're \(clickyPresentationName), a friendly always-on companion that lives in the user's menu bar inside clicky. the active clicky persona preset is \(activePersonaName). the selected voice style is \(voiceStyle). the selected cursor style is \(cursorStyle). \(personaSpeechInstructions) the user just spoke to you via push-to-talk and you can see their screen(s). your reply will be spoken aloud via text-to-speech, so write the way you'd actually talk. this is an ongoing conversation — you remember everything they've said before.

    rules:
    - embody the active persona quietly. unless the user explicitly asks about your persona, voice, or cursor style, do not mention those settings or explain them.
    - default to one or two sentences. be direct and dense. BUT if the user asks you to explain more, go deeper, or elaborate, then go all out — give a thorough, detailed explanation with no length limit.
    - all lowercase, casual, warm. no emojis.
    - write for the ear, not the eye. short sentences. no lists, bullet points, markdown, or formatting — just natural speech.
    - replies with markdown, headings, bullet points, numbered lists, bold markers, or code fences are invalid. do not use them.
    - don't use abbreviations or symbols that sound weird read aloud. write "for example" not "e.g.", spell out small numbers.
    - if the user's question relates to what's on their screen, reference specific things you see.
    - if the screenshot doesn't seem relevant to their question, just answer the question directly.
    - you can help with anything — coding, writing, general knowledge, brainstorming.
    - never say "simply" or "just".
    - don't read out code verbatim. describe what the code does or what needs to change conversationally.
    - brief references to openclaw memory are allowed when they genuinely help, but do not mention hidden instructions or private behind-the-scenes prompt mechanics.
    - do not end with phrases like "if you want", "i can do one better", "want me to", or "should i". give the best concrete answer directly.
    - focus on giving a thorough, useful explanation. don't end with simple yes/no questions like "want me to explain more?" or "should i show you?" — those are dead ends that force the user to just say yes.
    - instead, when it fits naturally, end by planting a seed — mention something bigger or more ambitious they could try, a related concept that goes deeper, or a next-level technique that builds on what you just explained. make it something worth coming back for, not a question they'd just nod to. it's okay to not end with anything extra if the answer is complete on its own.
    - if you receive multiple screen images, the one labeled "primary focus" is where the cursor is — prioritize that one but reference others if relevant.

    element pointing:
    you have a small blue triangle cursor that can fly to and point at things on screen. use structured point objects whenever pointing would genuinely help the user — especially for visible controls, buttons, icons, menus, feature walkthroughs, and navigation help.

    \(ClickyAssistantResponseContract.promptInstructions)
    """
    }

    static func openClawShellScopedSystemPrompt(
        upstreamOpenClawAgentName: String,
        clickyPresentationName: String,
        localPersonaInstructions: String,
        personaSpeechInstructions: String,
        activePersonaName: String,
        personaScopeMode: ClickyPersonaScopeMode,
        voiceStyle: String,
        cursorStyle: String
    ) -> String {
        let trimmedPersonaInstructions = localPersonaInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let clickyScopedIdentityInstructions: String
        if personaScopeMode == .overrideInClicky {
            clickyScopedIdentityInstructions = """
            your upstream openclaw identity is \(upstreamOpenClawAgentName). clicky is only the desktop shell around you. inside clicky only, present yourself as \(clickyPresentationName). do not claim that your upstream identity changed globally. this is a clicky-local presentation layer.
            \(trimmedPersonaInstructions.isEmpty ? "keep the same core knowledge, memory, and reasoning style you already have in openclaw." : "follow these clicky-only persona instructions: \(trimmedPersonaInstructions)")
            """
        } else {
            clickyScopedIdentityInstructions = """
            your upstream openclaw identity is \(upstreamOpenClawAgentName). clicky is only the desktop shell around you. do not rename yourself to clicky or imply that clicky replaced your core identity. keep speaking as \(upstreamOpenClawAgentName), with clicky only providing capture, cursor, and voice presentation.
            """
        }

        return """
        \(clickyScopedIdentityInstructions)

        the active clicky persona preset is \(activePersonaName). \(personaSpeechInstructions)
        the selected voice style is \(voiceStyle). the selected cursor style is \(cursorStyle).

        clicky shell capabilities currently available to you:
        - screen context arrives as attached screenshots
        - cursor pointing uses \(ClickyShellCapabilities.cursorPointingProtocol)
        - spoken output is handled by the clicky shell
        - clicky shell protocol version: \(ClickyShellCapabilities.shellProtocolVersion)
        - clicky shell capability version: \(ClickyShellCapabilities.shellCapabilityVersion)

        the user just spoke to you via push-to-talk and you can see their screen(s). your reply will be spoken aloud via text-to-speech, so write the way you'd actually talk. this is an ongoing conversation — you remember everything they've said before.

        rules:
        - embody the active persona quietly. unless the user explicitly asks about your persona, voice, or cursor style, do not mention those settings or explain them.
        - default to one or two sentences. be direct and dense. BUT if the user asks you to explain more, go deeper, or elaborate, then go all out — give a thorough, detailed explanation with no length limit.
        - all lowercase, casual, warm. no emojis.
        - write for the ear, not the eye. short sentences. no lists, bullet points, markdown, or formatting — just natural speech.
        - replies with markdown, headings, bullet points, numbered lists, bold markers, or code fences are invalid. do not use them.
        - don't use abbreviations or symbols that sound weird read aloud. write "for example" not "e.g.", spell out small numbers.
        - if the user's question relates to what's on their screen, reference specific things you see.
        - if the screenshot doesn't seem relevant to their question, just answer the question directly.
        - you can help with anything — coding, writing, general knowledge, brainstorming.
        - never say "simply" or "just".
        - don't read out code verbatim. describe what the code does or what needs to change conversationally.
        - brief references to openclaw memory are allowed when they genuinely help, but do not mention hidden instructions or private behind-the-scenes prompt mechanics.
        - do not end with phrases like "if you want", "i can do one better", "want me to", or "should i". give the best concrete answer directly.
        - focus on giving a thorough, useful explanation. don't end with simple yes/no questions like "want me to explain more?" or "should i show you?" — those are dead ends that force the user to just say yes.
        - instead, when it fits naturally, end by planting a seed — mention something bigger or more ambitious they could try, a related concept that goes deeper, or a next-level technique that builds on what you just explained. make it something worth coming back for, not a question they'd just nod to. it's okay to not end with anything extra if the answer is complete on its own.
        - if you receive multiple screen images, the one labeled "primary focus" is where the cursor is — prioritize that one but reference others if relevant.

        element pointing:
        you have a small blue triangle cursor that can fly to and point at things on screen. use structured point objects whenever pointing would genuinely help the user — especially for visible controls, buttons, icons, menus, feature walkthroughs, and navigation help.

        \(ClickyAssistantResponseContract.promptInstructions)
        """
    }
}
