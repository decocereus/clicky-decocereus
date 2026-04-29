//
//  ClickySurfaceLifecycleCoordinator.swift
//  leanring-buddy
//
//  Owns cursor overlay visibility and onboarding overlay lifecycle.
//

import AppKit
import Foundation

@MainActor
final class ClickySurfaceLifecycleCoordinator {
    private let preferences: ClickyPreferencesStore
    private let surfaceController: ClickySurfaceController
    private let overlayWindowManager: OverlayWindowManager
    private let onboardingMusicController: ClickyOnboardingMusicController
    private let allPermissionsGrantedProvider: () -> Bool
    private let cancelTransientHide: () -> Void
    private let showOverlay: () -> Void

    init(
        preferences: ClickyPreferencesStore,
        surfaceController: ClickySurfaceController,
        overlayWindowManager: OverlayWindowManager,
        onboardingMusicController: ClickyOnboardingMusicController,
        allPermissionsGrantedProvider: @escaping () -> Bool,
        cancelTransientHide: @escaping () -> Void,
        showOverlay: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.surfaceController = surfaceController
        self.overlayWindowManager = overlayWindowManager
        self.onboardingMusicController = onboardingMusicController
        self.allPermissionsGrantedProvider = allPermissionsGrantedProvider
        self.cancelTransientHide = cancelTransientHide
        self.showOverlay = showOverlay
    }

    func setCursorEnabled(_ enabled: Bool) {
        guard preferences.isClickyCursorEnabled != enabled else { return }
        preferences.isClickyCursorEnabled = enabled
        cancelTransientHide()

        if enabled {
            overlayWindowManager.hasShownOverlayBefore = true
            showOverlay()
            surfaceController.isOverlayVisible = true
        } else {
            overlayWindowManager.hideOverlay()
            surfaceController.isOverlayVisible = false
        }
    }

    func showOverlayIfReady() {
        guard preferences.hasCompletedOnboarding,
              allPermissionsGrantedProvider(),
              preferences.isClickyCursorEnabled,
              !surfaceController.isOverlayVisible else {
            return
        }

        overlayWindowManager.hasShownOverlayBefore = true
        showOverlay()
        surfaceController.isOverlayVisible = true
    }

    func triggerOnboarding() {
        NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)
        preferences.hasCompletedOnboarding = true
        ClickyAnalytics.trackOnboardingStarted()
        onboardingMusicController.start()
        showOverlay()
        surfaceController.isOverlayVisible = true
    }

    func replayOnboarding() {
        NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)
        ClickyAnalytics.trackOnboardingReplayed()
        onboardingMusicController.start()
        overlayWindowManager.hasShownOverlayBefore = false
        showOverlay()
        surfaceController.isOverlayVisible = true
    }
}
