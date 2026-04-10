//
//  leanring_buddyApp.swift
//  leanring-buddy
//
//  Menu bar-only companion app. No dock icon, no main window — just an
//  always-available status item in the macOS menu bar. Clicking the icon
//  opens a floating panel with companion voice controls.
//

import ServiceManagement
import SwiftUI

@main
struct leanring_buddyApp: App {
    @NSApplicationDelegateAdaptor(CompanionAppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            CompanionStudioView(companionManager: appDelegate.companionManager)
                .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            CommandMenu("Clicky") {
                Button("Open Companion Panel") {
                    NotificationCenter.default.post(name: .clickyShowPanel, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                SettingsLink {
                    Text("Open Studio")
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])
            }
        }
    }
}

/// Manages the companion lifecycle: creates the menu bar panel and starts
/// the companion voice pipeline on launch.
@MainActor
final class CompanionAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarPanelManager: MenuBarPanelManager?
    let companionManager = CompanionManager()
    private var sparkleUpdaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🎯 Clicky: Starting...")
        print("🎯 Clicky: Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
        ClickyLogger.notice(.app, "Launching Clicky version=\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")

        terminateOtherRunningClickyInstances()

        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 0])

        ClickyFontRegistrar.registerBundledFonts()
        ClickyAnalytics.configure()
        ClickyAnalytics.trackAppOpened()

        #if DEBUG
        NSApp.setActivationPolicy(.regular)
        #endif

        menuBarPanelManager = MenuBarPanelManager(companionManager: companionManager)
        companionManager.start()
        // Auto-open the panel if the user still needs to do something:
        // either they haven't onboarded yet, or permissions were revoked.
        if !companionManager.hasCompletedOnboarding || !companionManager.allPermissionsGranted {
            menuBarPanelManager?.showPanelOnLaunch()
        }
        #if DEBUG
        menuBarPanelManager?.showStudioOnLaunch()
        #endif
        registerAsLoginItemIfNeeded()
        // startSparkleUpdater()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClickyLogger.notice(.app, "Terminating Clicky")
        companionManager.stop()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            companionManager.handleClickyLaunchCallback(url: url)
        }
    }

    /// Registers the app as a login item so it launches automatically on
    /// startup. Uses SMAppService which shows the app in System Settings >
    /// General > Login Items, letting the user toggle it off if they want.
    private func registerAsLoginItemIfNeeded() {
        let loginItemService = SMAppService.mainApp
        if loginItemService.status != .enabled {
            do {
                try loginItemService.register()
                print("🎯 Clicky: Registered as login item")
            } catch {
                print("⚠️ Clicky: Failed to register as login item: \(error)")
            }
        }
    }

    private func startSparkleUpdater() {
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.sparkleUpdaterController = updaterController

        do {
            try updaterController.updater.start()
        } catch {
            print("⚠️ Clicky: Sparkle updater failed to start: \(error)")
        }
    }

    private func terminateOtherRunningClickyInstances() {
        guard let currentBundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let otherRunningClickyApplications = NSWorkspace.shared.runningApplications.filter { runningApplication in
            runningApplication.bundleIdentifier == currentBundleIdentifier
                && runningApplication.processIdentifier != currentProcessIdentifier
        }

        for runningApplication in otherRunningClickyApplications {
            print("🎯 Clicky: Terminating duplicate instance pid=\(runningApplication.processIdentifier)")
            ClickyLogger.notice(.app, "Terminating duplicate instance pid=\(runningApplication.processIdentifier)")
            _ = runningApplication.terminate()
        }
    }
}
