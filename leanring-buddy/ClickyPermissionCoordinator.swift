//
//  ClickyPermissionCoordinator.swift
//  leanring-buddy
//
//  Owns live macOS permission polling and screen-content approval.
//

import AppKit
import AVFoundation
import Foundation
import ScreenCaptureKit

@MainActor
final class ClickyPermissionCoordinator {
    private let surfaceController: ClickySurfaceController
    private let shortcutMonitor: GlobalPushToTalkShortcutMonitor
    private let userDefaults: UserDefaults
    private let onRequestingScreenContentChanged: (Bool) -> Void
    private let onScreenContentGranted: () -> Void

    private var permissionPollingTimer: Timer?
    private var isRequestingScreenContent = false

    init(
        surfaceController: ClickySurfaceController,
        shortcutMonitor: GlobalPushToTalkShortcutMonitor,
        userDefaults: UserDefaults = .standard,
        onRequestingScreenContentChanged: @escaping (Bool) -> Void,
        onScreenContentGranted: @escaping () -> Void
    ) {
        self.surfaceController = surfaceController
        self.shortcutMonitor = shortcutMonitor
        self.userDefaults = userDefaults
        self.onRequestingScreenContentChanged = onRequestingScreenContentChanged
        self.onScreenContentGranted = onScreenContentGranted
    }

    var allPermissionsGranted: Bool {
        Self.allPermissionsGranted(
            hasAccessibilityPermission: surfaceController.hasAccessibilityPermission,
            hasScreenRecordingPermission: surfaceController.hasScreenRecordingPermission,
            hasMicrophonePermission: surfaceController.hasMicrophonePermission,
            hasScreenContentPermission: surfaceController.hasScreenContentPermission
        )
    }

    var isScreenContentRequestInFlight: Bool {
        isRequestingScreenContent
    }

    func refreshAllPermissions() {
        let previouslyHadAccessibility = surfaceController.hasAccessibilityPermission
        let previouslyHadScreenRecording = surfaceController.hasScreenRecordingPermission
        let previouslyHadMicrophone = surfaceController.hasMicrophonePermission
        let previouslyHadAll = allPermissionsGranted

        let currentlyHasAccessibility = WindowPositionManager.hasAccessibilityPermission()
        surfaceController.hasAccessibilityPermission = currentlyHasAccessibility

        if currentlyHasAccessibility {
            shortcutMonitor.start()
        } else {
            shortcutMonitor.stop()
        }

        surfaceController.hasScreenRecordingPermission = WindowPositionManager.hasScreenRecordingPermission()

        let micAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        surfaceController.hasMicrophonePermission = micAuthStatus == .authorized

        if previouslyHadAccessibility != surfaceController.hasAccessibilityPermission
            || previouslyHadScreenRecording != surfaceController.hasScreenRecordingPermission
            || previouslyHadMicrophone != surfaceController.hasMicrophonePermission {
            ClickyLogger.info(
                .app,
                "Permissions changed accessibility=\(surfaceController.hasAccessibilityPermission) screenRecording=\(surfaceController.hasScreenRecordingPermission) microphone=\(surfaceController.hasMicrophonePermission) screenContent=\(surfaceController.hasScreenContentPermission)"
            )
        }

        if !previouslyHadAccessibility && surfaceController.hasAccessibilityPermission {
            ClickyAnalytics.trackPermissionGranted(permission: "accessibility")
        }
        if !previouslyHadScreenRecording && surfaceController.hasScreenRecordingPermission {
            ClickyAnalytics.trackPermissionGranted(permission: "screen_recording")
        }
        if !previouslyHadMicrophone && surfaceController.hasMicrophonePermission {
            ClickyAnalytics.trackPermissionGranted(permission: "microphone")
        }

        if !surfaceController.hasScreenContentPermission {
            surfaceController.hasScreenContentPermission = userDefaults.bool(forKey: "hasScreenContentPermission")
        }

        if !previouslyHadAll && allPermissionsGranted {
            ClickyAnalytics.trackAllPermissionsGranted()
        }
    }

    func requestScreenContentPermission() {
        guard !isRequestingScreenContent else { return }
        setRequestingScreenContent(true)

        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    await MainActor.run { self.setRequestingScreenContent(false) }
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = 320
                config.height = 240
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let didCapture = image.width > 0 && image.height > 0
                ClickyLogger.info(.app, "Screen content capture result width=\(image.width) height=\(image.height) didCapture=\(didCapture)")

                await MainActor.run {
                    self.setRequestingScreenContent(false)
                    guard didCapture else { return }
                    self.surfaceController.hasScreenContentPermission = true
                    self.userDefaults.set(true, forKey: "hasScreenContentPermission")
                    ClickyAnalytics.trackPermissionGranted(permission: "screen_content")
                    self.onScreenContentGranted()
                }
            } catch {
                ClickyLogger.error(.app, "Screen content permission request failed error=\(error.localizedDescription)")
                await MainActor.run { self.setRequestingScreenContent(false) }
            }
        }
    }

    func promptForMicrophoneIfNotDetermined() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor [weak self] in
                self?.surfaceController.hasMicrophonePermission = granted
            }
        }
    }

    func startPolling() {
        permissionPollingTimer?.invalidate()
        permissionPollingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllPermissions()
            }
        }
    }

    func stopPolling() {
        permissionPollingTimer?.invalidate()
        permissionPollingTimer = nil
    }

    static func allPermissionsGranted(
        hasAccessibilityPermission: Bool,
        hasScreenRecordingPermission: Bool,
        hasMicrophonePermission: Bool,
        hasScreenContentPermission: Bool
    ) -> Bool {
        hasAccessibilityPermission
            && hasScreenRecordingPermission
            && hasMicrophonePermission
            && hasScreenContentPermission
    }

    private func setRequestingScreenContent(_ isRequesting: Bool) {
        isRequestingScreenContent = isRequesting
        onRequestingScreenContentChanged(isRequesting)
    }
}
