//
//  ClickyVoiceSessionCoordinator.swift
//  leanring-buddy
//
//  Coordinates push-to-talk session events, voice-state observation, and
//  transient cursor hiding.
//

import AppKit
import Combine
import Foundation

@MainActor
final class ClickyVoiceSessionCoordinator {
    private let dictationManager: BuddyDictationManager
    private let shortcutMonitor: GlobalPushToTalkShortcutMonitor
    private let surfaceController: ClickySurfaceController
    private let overlayWindowManager: OverlayWindowManager
    private let ttsClient: ElevenLabsTTSClient
    private let isClickyCursorEnabled: () -> Bool
    private let canBeginPushToTalk: () -> Bool
    private let isResponseTaskActive: () -> Bool
    private let cancelActiveResponse: () -> Void
    private let cancelActiveAssistantRequest: () -> Void
    private let clearDetectedElementLocation: () -> Void
    private let detectedElementScreenLocation: () -> CGPoint?
    private let showTransientOverlay: () -> Void
    private let isTutorialPlaybackVisible: () -> Bool
    private let handleTutorialPlaybackKeyboardCommand: (TutorialPlaybackCommand) -> Void
    private let dismissOnboardingPrompt: () -> Void
    private let submitTranscript: (String) -> Void

    private var shortcutTransitionCancellable: AnyCancellable?
    private var voiceStateCancellable: AnyCancellable?
    private var audioPowerCancellable: AnyCancellable?
    private var tutorialPlaybackShortcutCancellable: AnyCancellable?
    private var pendingKeyboardShortcutStartTask: Task<Void, Never>?
    private var transientHideTask: Task<Void, Never>?

    init(
        dictationManager: BuddyDictationManager,
        shortcutMonitor: GlobalPushToTalkShortcutMonitor,
        surfaceController: ClickySurfaceController,
        overlayWindowManager: OverlayWindowManager,
        ttsClient: ElevenLabsTTSClient,
        isClickyCursorEnabled: @escaping () -> Bool,
        canBeginPushToTalk: @escaping () -> Bool,
        isResponseTaskActive: @escaping () -> Bool,
        cancelActiveResponse: @escaping () -> Void,
        cancelActiveAssistantRequest: @escaping () -> Void,
        clearDetectedElementLocation: @escaping () -> Void,
        detectedElementScreenLocation: @escaping () -> CGPoint?,
        showTransientOverlay: @escaping () -> Void,
        isTutorialPlaybackVisible: @escaping () -> Bool,
        handleTutorialPlaybackKeyboardCommand: @escaping (TutorialPlaybackCommand) -> Void,
        dismissOnboardingPrompt: @escaping () -> Void,
        submitTranscript: @escaping (String) -> Void
    ) {
        self.dictationManager = dictationManager
        self.shortcutMonitor = shortcutMonitor
        self.surfaceController = surfaceController
        self.overlayWindowManager = overlayWindowManager
        self.ttsClient = ttsClient
        self.isClickyCursorEnabled = isClickyCursorEnabled
        self.canBeginPushToTalk = canBeginPushToTalk
        self.isResponseTaskActive = isResponseTaskActive
        self.cancelActiveResponse = cancelActiveResponse
        self.cancelActiveAssistantRequest = cancelActiveAssistantRequest
        self.clearDetectedElementLocation = clearDetectedElementLocation
        self.detectedElementScreenLocation = detectedElementScreenLocation
        self.showTransientOverlay = showTransientOverlay
        self.isTutorialPlaybackVisible = isTutorialPlaybackVisible
        self.handleTutorialPlaybackKeyboardCommand = handleTutorialPlaybackKeyboardCommand
        self.dismissOnboardingPrompt = dismissOnboardingPrompt
        self.submitTranscript = submitTranscript
    }

    func start() {
        bindVoiceStateObservation()
        bindAudioPowerLevel()
        bindShortcutTransitions()
        bindTutorialPlaybackShortcutTransitions()
    }

    func stop() {
        cancelTransientHide()
        pendingKeyboardShortcutStartTask?.cancel()
        pendingKeyboardShortcutStartTask = nil
        shortcutTransitionCancellable?.cancel()
        voiceStateCancellable?.cancel()
        audioPowerCancellable?.cancel()
        tutorialPlaybackShortcutCancellable?.cancel()
        shortcutTransitionCancellable = nil
        voiceStateCancellable = nil
        audioPowerCancellable = nil
        tutorialPlaybackShortcutCancellable = nil
    }

    func cancelTransientHide() {
        transientHideTask?.cancel()
        transientHideTask = nil
    }

    func scheduleTransientHideIfNeeded() {
        guard !isClickyCursorEnabled(),
              surfaceController.isOverlayVisible else {
            return
        }

        cancelTransientHide()
        transientHideTask = Task {
            await ttsClient.waitUntilPlaybackFinishes()
            guard !Task.isCancelled else { return }

            while detectedElementScreenLocation() != nil {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            overlayWindowManager.fadeOutAndHideOverlay()
            surfaceController.isOverlayVisible = false
        }
    }

    private func bindAudioPowerLevel() {
        audioPowerCancellable?.cancel()
        audioPowerCancellable = dictationManager.$currentAudioPowerLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] powerLevel in
                self?.surfaceController.currentAudioPowerLevel = powerLevel
            }
    }

    private func bindVoiceStateObservation() {
        voiceStateCancellable?.cancel()
        voiceStateCancellable = dictationManager.$isRecordingFromKeyboardShortcut
            .combineLatest(
                dictationManager.$isFinalizingTranscript,
                dictationManager.$isPreparingToRecord
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, isFinalizing, isPreparing in
                guard let self else { return }
                if isRecording {
                    self.surfaceController.voiceState = .listening
                } else if isFinalizing || isPreparing {
                    self.surfaceController.voiceState = .transcribing
                } else if self.surfaceController.voiceState == .thinking || self.surfaceController.voiceState == .responding {
                    return
                } else {
                    self.surfaceController.voiceState = .idle
                    if !self.isResponseTaskActive() {
                        self.scheduleTransientHideIfNeeded()
                    }
                }
            }
    }

    private func bindShortcutTransitions() {
        shortcutTransitionCancellable?.cancel()
        shortcutTransitionCancellable = shortcutMonitor
            .shortcutTransitionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transition in
                self?.handleShortcutTransition(transition)
            }
    }

    private func bindTutorialPlaybackShortcutTransitions() {
        tutorialPlaybackShortcutCancellable?.cancel()
        tutorialPlaybackShortcutCancellable = shortcutMonitor
            .tutorialPlaybackCommandPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                guard let self else { return }
                guard isTutorialPlaybackVisible() else { return }
                handleTutorialPlaybackKeyboardCommand(command)
            }
    }

    private func handleShortcutTransition(_ transition: BuddyPushToTalkShortcut.ShortcutTransition) {
        switch transition {
        case .pressed:
            handlePushToTalkPressed()
        case .released:
            ClickyAnalytics.trackPushToTalkReleased()
            pendingKeyboardShortcutStartTask?.cancel()
            pendingKeyboardShortcutStartTask = nil
            dictationManager.stopPushToTalkFromKeyboardShortcut()
        case .none:
            break
        }
    }

    private func handlePushToTalkPressed() {
        guard !dictationManager.isDictationInProgress else { return }
        guard canBeginPushToTalk() else { return }

        cancelTransientHide()

        if !isClickyCursorEnabled() && !surfaceController.isOverlayVisible {
            showTransientOverlay()
        }

        NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)

        cancelActiveResponse()
        cancelActiveAssistantRequest()
        ttsClient.stopPlayback()
        clearDetectedElementLocation()
        dismissOnboardingPrompt()

        ClickyAnalytics.trackPushToTalkStarted()

        pendingKeyboardShortcutStartTask?.cancel()
        pendingKeyboardShortcutStartTask = Task {
            await dictationManager.startPushToTalkFromKeyboardShortcut(
                currentDraftText: "",
                updateDraftText: { _ in },
                submitDraftText: { [weak self] finalTranscript in
                    ClickyLogger.notice(.agent, "Received companion transcript transcriptLength=\(finalTranscript.count)")
                    ClickyAgentTurnDiagnostics.logTranscriptCapture(finalTranscript)
                    ClickyAnalytics.trackUserMessageSent(transcript: finalTranscript)
                    self?.submitTranscript(finalTranscript)
                }
            )
        }
    }
}
