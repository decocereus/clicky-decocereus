//
//  ClickyLaunchBlockedTurnPresenter.swift
//  leanring-buddy
//
//  Presents launch-access blocks without coupling the launch gate to TTS or
//  overlay implementation details.
//

import AppKit
import Foundation

@MainActor
final class ClickyLaunchBlockedTurnPresenter {
    private let cancelActiveAssistantRequest: @MainActor () -> Void
    private let stopSpeechPlayback: @MainActor () -> Void
    private let setVoiceState: @MainActor (CompanionVoiceState) -> Void
    private let playSpeech: @MainActor (String, ClickySpeechPlaybackPurpose) async -> Void
    private let scheduleTransientHideIfNeeded: @MainActor () -> Void

    init(
        cancelActiveAssistantRequest: @escaping @MainActor () -> Void,
        stopSpeechPlayback: @escaping @MainActor () -> Void,
        setVoiceState: @escaping @MainActor (CompanionVoiceState) -> Void,
        playSpeech: @escaping @MainActor (String, ClickySpeechPlaybackPurpose) async -> Void,
        scheduleTransientHideIfNeeded: @escaping @MainActor () -> Void
    ) {
        self.cancelActiveAssistantRequest = cancelActiveAssistantRequest
        self.stopSpeechPlayback = stopSpeechPlayback
        self.setVoiceState = setVoiceState
        self.playSpeech = playSpeech
        self.scheduleTransientHideIfNeeded = scheduleTransientHideIfNeeded
    }

    func presentSignInRequired(
        authState: ClickyLaunchAuthState,
        openStudio: Bool
    ) {
        present(
            message: signInRequiredMessage(for: authState),
            openStudio: openStudio,
            studioRoute: .studio,
            logMessage: "Blocked assistant turn because launch sign-in is required"
        )
    }

    func presentAccessRecovery(
        openStudio: Bool,
        message: String,
        logReason: String
    ) {
        present(
            message: message,
            openStudio: openStudio,
            studioRoute: .settings,
            logMessage: "Blocked assistant turn because \(logReason)"
        )
    }

    func presentPaywallLocked(openStudio: Bool) {
        present(
            message: ClickyLaunchTurnGate.paywallLockedMessage,
            openStudio: openStudio,
            studioRoute: .studio,
            logMessage: "Blocked assistant turn because launch paywall is active"
        )
    }

    private func present(
        message: String,
        openStudio: Bool,
        studioRoute: StudioRoute,
        logMessage: String
    ) {
        cancelActiveAssistantRequest()
        stopSpeechPlayback()

        if openStudio {
            studioRoute.open()
        }

        setVoiceState(.responding)
        ClickyLogger.notice(.app, logMessage)

        Task { @MainActor in
            await playSpeech(message, .systemMessage)

            if !Task.isCancelled {
                setVoiceState(.idle)
                scheduleTransientHideIfNeeded()
            }
        }
    }

    private func signInRequiredMessage(for authState: ClickyLaunchAuthState) -> String {
        switch authState {
        case .failed(let message):
            return message
        default:
            return "clicky couldn't continue because this mac is signed out. open studio and sign in once, then you can keep going."
        }
    }

    private enum StudioRoute {
        case studio
        case settings

        @MainActor
        func open() {
            switch self {
            case .studio:
                NotificationCenter.default.post(name: .clickyOpenStudio, object: nil)
            case .settings:
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}
