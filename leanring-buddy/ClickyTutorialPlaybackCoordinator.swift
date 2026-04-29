//
//  ClickyTutorialPlaybackCoordinator.swift
//  leanring-buddy
//
//  Owns tutorial lesson playback state and keyboard command routing.
//

import Foundation

@MainActor
final class ClickyTutorialPlaybackCoordinator {
    private let tutorialController: ClickyTutorialController

    init(tutorialController: ClickyTutorialController) {
        self.tutorialController = tutorialController
    }

    func startLessonFromReadyState() {
        guard var sessionState = tutorialController.tutorialSessionState else { return }
        guard let lessonDraft = tutorialController.currentTutorialImportDraft?.compiledLessonDraft else { return }
        guard lessonDraft.steps.indices.contains(sessionState.currentStepIndex) else { return }

        sessionState.isActive = true
        tutorialController.tutorialSessionState = sessionState

        let currentStep = lessonDraft.steps[sessionState.currentStepIndex]
        let promptTimestamp = currentStep.sourceVideoPromptTimestamp
            ?? sessionState.evidenceBundle.structureMarkers.first?.visualAnchorTimestamps.first

        startPlayback(
            sourceURL: sessionState.evidenceBundle.source.url,
            embedURL: sessionState.evidenceBundle.source.embedURL,
            step: currentStep,
            bubbleText: "\(currentStep.title). \(currentStep.instruction)",
            promptTimestampSeconds: promptTimestamp,
            autoPlay: true
        )
    }

    func advanceLessonFromPanel() {
        guard var sessionState = tutorialController.tutorialSessionState else { return }
        let lessonDraft = sessionState.lessonDraft
        guard sessionState.currentStepIndex + 1 < lessonDraft.steps.count else { return }

        sessionState.currentStepIndex += 1
        sessionState.isActive = true
        tutorialController.tutorialSessionState = sessionState

        let nextStep = lessonDraft.steps[sessionState.currentStepIndex]
        updatePlaybackState(step: nextStep, isPlaying: true)
    }

    func rewindLessonFromPanel() {
        guard var sessionState = tutorialController.tutorialSessionState else { return }
        let lessonDraft = sessionState.lessonDraft
        guard sessionState.currentStepIndex > 0 else { return }

        sessionState.currentStepIndex -= 1
        sessionState.isActive = true
        tutorialController.tutorialSessionState = sessionState

        let currentStep = lessonDraft.steps[sessionState.currentStepIndex]
        updatePlaybackState(step: currentStep, isPlaying: true)
    }

    func repeatLessonStepFromPanel() {
        guard let sessionState = tutorialController.tutorialSessionState else { return }
        let lessonDraft = sessionState.lessonDraft
        guard lessonDraft.steps.indices.contains(sessionState.currentStepIndex) else { return }

        let currentStep = lessonDraft.steps[sessionState.currentStepIndex]
        updatePlaybackState(step: currentStep, isPlaying: true)
    }

    func startPlayback(
        sourceURL: String,
        embedURL: String,
        step: TutorialLessonStep? = nil,
        bubbleText: String? = nil,
        promptTimestampSeconds: Int? = nil,
        autoPlay: Bool = true
    ) {
        tutorialController.tutorialPlaybackState = TutorialPlaybackBindingState(
            sourceURL: sourceURL,
            embedURL: embedURL,
            currentStepID: step?.id,
            currentStepTitle: step?.title,
            bubbleText: bubbleText ?? "Space play/pause  Left back 10s  Right forward 10s  Esc close",
            isPlaying: autoPlay,
            isVisible: true,
            surfaceMode: .inlineVideoWithBubble,
            resumeBehavior: .resumeInlineVideoAfterPointing,
            preferredInlinePlayerWidth: 330,
            preferredInlinePlayerHeight: 186,
            lastPromptTimestampSeconds: promptTimestampSeconds,
            showsKeyboardShortcutsHint: true
        )
        tutorialController.tutorialPlaybackBubbleOpacity = 1.0
        if autoPlay {
            sendPlaybackCommand(.play)
        }
    }

    func updatePlaybackState(step: TutorialLessonStep, isPlaying: Bool) {
        if tutorialController.tutorialPlaybackState == nil {
            guard let sessionState = tutorialController.tutorialSessionState else { return }
            startPlayback(
                sourceURL: sessionState.evidenceBundle.source.url,
                embedURL: sessionState.evidenceBundle.source.embedURL,
                step: step,
                bubbleText: "\(step.title). \(step.instruction)",
                promptTimestampSeconds: step.sourceVideoPromptTimestamp,
                autoPlay: isPlaying
            )
            return
        }

        tutorialController.tutorialPlaybackState?.currentStepID = step.id
        tutorialController.tutorialPlaybackState?.currentStepTitle = step.title
        tutorialController.tutorialPlaybackState?.bubbleText = "\(step.title). \(step.instruction)"
        tutorialController.tutorialPlaybackState?.surfaceMode = .inlineVideoWithBubble
        tutorialController.tutorialPlaybackState?.lastPromptTimestampSeconds = step.sourceVideoPromptTimestamp
        tutorialController.tutorialPlaybackState?.isPlaying = isPlaying
        tutorialController.tutorialPlaybackBubbleOpacity = 1.0

        if isPlaying {
            sendPlaybackCommand(.play)
        }
    }

    func updateBubble(_ text: String?) {
        guard var state = tutorialController.tutorialPlaybackState else { return }
        state.showsKeyboardShortcutsHint = false
        state.bubbleText = text
        state.surfaceMode = text == nil ? .inlineVideo : .inlineVideoWithBubble
        tutorialController.tutorialPlaybackState = state
        tutorialController.tutorialPlaybackBubbleOpacity = text == nil ? 0.0 : 1.0
    }

    func pauseForPointing() {
        guard var state = tutorialController.tutorialPlaybackState else { return }
        state.surfaceMode = .pointerGuidance
        tutorialController.tutorialPlaybackState = state
        tutorialController.tutorialPlaybackBubbleOpacity = 0.0
        sendPlaybackCommand(.pause)
    }

    func resumeAfterPointingIfNeeded() {
        guard var state = tutorialController.tutorialPlaybackState else { return }
        guard state.resumeBehavior == .resumeInlineVideoAfterPointing else { return }

        state.surfaceMode = state.bubbleText == nil ? .inlineVideo : .inlineVideoWithBubble
        tutorialController.tutorialPlaybackState = state
        tutorialController.tutorialPlaybackBubbleOpacity = state.bubbleText == nil ? 0.0 : 1.0
        if state.isPlaying {
            sendPlaybackCommand(.play)
        }
    }

    func stopPlayback() {
        tutorialController.tutorialPlaybackBubbleOpacity = 0.0
        tutorialController.tutorialPlaybackState = nil
        sendPlaybackCommand(.dismiss)
    }

    func handleKeyboardCommand(_ command: TutorialPlaybackCommand) {
        guard var state = tutorialController.tutorialPlaybackState, state.isVisible else { return }

        switch command {
        case .play:
            state.isPlaying = true
        case .pause:
            state.isPlaying = false
        case .togglePlayPause:
            state.isPlaying.toggle()
        case .seekBackward, .seekForward:
            break
        case .dismiss:
            tutorialController.tutorialPlaybackState = nil
            tutorialController.tutorialPlaybackBubbleOpacity = 0.0
        }

        if command != .dismiss {
            if state.showsKeyboardShortcutsHint {
                state.showsKeyboardShortcutsHint = false
                if let currentStepTitle = state.currentStepTitle,
                   !currentStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.bubbleText = currentStepTitle
                    state.surfaceMode = .inlineVideoWithBubble
                } else if state.bubbleText?.contains("Space play/pause") == true {
                    state.bubbleText = nil
                    state.surfaceMode = .inlineVideo
                }
            }
            tutorialController.tutorialPlaybackState = state
        }

        sendPlaybackCommand(command)
    }

    private func sendPlaybackCommand(_ command: TutorialPlaybackCommand) {
        tutorialController.tutorialPlaybackLastCommand = command
        tutorialController.tutorialPlaybackCommandNonce += 1
    }
}
