//
//  ClickyCompanionLifecycleCoordinator.swift
//  leanring-buddy
//
//  Owns app-level companion startup and shutdown sequencing.
//

import Foundation

@MainActor
final class ClickyCompanionLifecycleCoordinator {
    private let preferences: ClickyPreferencesStore
    private let settingsMutationCoordinator: ClickySettingsMutationCoordinator
    private let launchRuntimeCoordinator: ClickyLaunchRuntimeCoordinator
    private let permissionCoordinator: ClickyPermissionCoordinator
    private let voiceSessionCoordinator: ClickyVoiceSessionCoordinator
    private let dictationManager: BuddyDictationManager
    private let shortcutMonitor: GlobalPushToTalkShortcutMonitor
    private let overlayWindowManager: OverlayWindowManager
    private let surfaceLifecycleCoordinator: ClickySurfaceLifecycleCoordinator
    private let openClawShellLifecycleController: ClickyOpenClawShellLifecycleController
    private let openClawStudioCoordinator: ClickyOpenClawStudioCoordinator
    private let codexRuntimeCoordinator: ClickyCodexRuntimeCoordinator
    private let onboardingMusicController: ClickyOnboardingMusicController
    private let assistantTurnTaskController: ClickyAssistantTurnTaskController
    private let stopTutorialPlayback: () -> Void
    private let warmClaudeAPI: () -> Void
    private let allPermissionsGranted: () -> Bool
    private let hasCompletedOnboarding: () -> Bool
    private let isOverlayVisible: () -> Bool

    init(
        preferences: ClickyPreferencesStore,
        settingsMutationCoordinator: ClickySettingsMutationCoordinator,
        launchRuntimeCoordinator: ClickyLaunchRuntimeCoordinator,
        permissionCoordinator: ClickyPermissionCoordinator,
        voiceSessionCoordinator: ClickyVoiceSessionCoordinator,
        dictationManager: BuddyDictationManager,
        shortcutMonitor: GlobalPushToTalkShortcutMonitor,
        overlayWindowManager: OverlayWindowManager,
        surfaceLifecycleCoordinator: ClickySurfaceLifecycleCoordinator,
        openClawShellLifecycleController: ClickyOpenClawShellLifecycleController,
        openClawStudioCoordinator: ClickyOpenClawStudioCoordinator,
        codexRuntimeCoordinator: ClickyCodexRuntimeCoordinator,
        onboardingMusicController: ClickyOnboardingMusicController,
        assistantTurnTaskController: ClickyAssistantTurnTaskController,
        stopTutorialPlayback: @escaping () -> Void,
        warmClaudeAPI: @escaping () -> Void,
        allPermissionsGranted: @escaping () -> Bool,
        hasCompletedOnboarding: @escaping () -> Bool,
        isOverlayVisible: @escaping () -> Bool
    ) {
        self.preferences = preferences
        self.settingsMutationCoordinator = settingsMutationCoordinator
        self.launchRuntimeCoordinator = launchRuntimeCoordinator
        self.permissionCoordinator = permissionCoordinator
        self.voiceSessionCoordinator = voiceSessionCoordinator
        self.dictationManager = dictationManager
        self.shortcutMonitor = shortcutMonitor
        self.overlayWindowManager = overlayWindowManager
        self.surfaceLifecycleCoordinator = surfaceLifecycleCoordinator
        self.openClawShellLifecycleController = openClawShellLifecycleController
        self.openClawStudioCoordinator = openClawStudioCoordinator
        self.codexRuntimeCoordinator = codexRuntimeCoordinator
        self.onboardingMusicController = onboardingMusicController
        self.assistantTurnTaskController = assistantTurnTaskController
        self.stopTutorialPlayback = stopTutorialPlayback
        self.warmClaudeAPI = warmClaudeAPI
        self.allPermissionsGranted = allPermissionsGranted
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.isOverlayVisible = isOverlayVisible
    }

    func start() {
        ClickyUnifiedTelemetry.lifecycle.info("Companion start began")

        if !CompanionRuntimeConfiguration.isWorkerConfigured && preferences.selectedAgentBackend == .claude {
            settingsMutationCoordinator.setSelectedBackend(.openClaw)
            ClickyUnifiedTelemetry.lifecycle.info(
                "Agent backend fallback applied from=Claude to=OpenClaw reason=worker-unconfigured"
            )
        }

        launchRuntimeCoordinator.restoreSessionIfPossible()
        permissionCoordinator.refreshAllPermissions()
        permissionCoordinator.startPolling()
        voiceSessionCoordinator.start()

        if preferences.selectedAgentBackend == .claude {
            warmClaudeAPI()
        }

        if dictationManager.needsInitialPermissionPrompt {
            Task { @MainActor in
                await self.dictationManager.requestInitialPushToTalkPermissionsIfNeeded()
            }
        }

        openClawShellLifecycleController.refreshLifecycle()
        openClawStudioCoordinator.refreshAgentIdentity()
        codexRuntimeCoordinator.refreshRuntimeStatus()
        surfaceLifecycleCoordinator.showOverlayIfReady()

        ClickyUnifiedTelemetry.lifecycle.info(
            "Companion start completed backend=\(self.preferences.selectedAgentBackend.displayName, privacy: .public) permissions=\(self.allPermissionsGranted() ? "ready" : "needs-attention", privacy: .public) onboarding=\(self.hasCompletedOnboarding() ? "complete" : "pending", privacy: .public) overlay=\(self.isOverlayVisible() ? "shown" : "hidden", privacy: .public)"
        )
    }

    func stop() {
        shortcutMonitor.stop()
        dictationManager.cancelCurrentDictation()
        overlayWindowManager.hideOverlay()
        stopTutorialPlayback()
        voiceSessionCoordinator.cancelTransientHide()
        launchRuntimeCoordinator.stop()
        openClawShellLifecycleController.stop()
        onboardingMusicController.stop()

        assistantTurnTaskController.stop()
        voiceSessionCoordinator.stop()
        permissionCoordinator.stopPolling()
    }
}
