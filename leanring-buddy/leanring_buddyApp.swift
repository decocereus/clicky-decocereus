//
//  leanring_buddyApp.swift
//  leanring-buddy
//
//  Menu bar-only companion app. No dock icon, no main window — just an
//  always-available status item in the macOS menu bar. Clicking the icon
//  opens a floating panel with companion voice controls.
//

import AppKit
import OSLog
import ServiceManagement
import SwiftUI
#if canImport(Sparkle)
import Sparkle
#endif

@main
struct leanring_buddyApp: App {
    @NSApplicationDelegateAdaptor(CompanionAppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Open Studio") {
                    ClickyUnifiedTelemetry.windowing.info(
                        "Studio command invoked source=app-settings"
                    )
                    appDelegate.showStudioWindow(source: "app-settings")
                }
                .keyboardShortcut(",", modifiers: [.command])

                Divider()

                Button("Check for Updates…") {
                    appDelegate.checkForUpdates()
                }
            }

            CommandMenu("Clicky") {
                Button("Open Companion Panel") {
                    ClickyUnifiedTelemetry.windowing.info(
                        "Companion panel command invoked source=clicky-command-menu"
                    )
                    NotificationCenter.default.post(name: .clickyShowPanel, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Open Studio") {
                    ClickyUnifiedTelemetry.windowing.info(
                        "Studio command invoked source=clicky-command-menu"
                    )
                    appDelegate.showStudioWindow(source: "clicky-command-menu")
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
    private var checkForUpdatesObserver: NSObjectProtocol?
    let companionManager = CompanionManager()
    private var sparkleUpdaterController: SPUStandardUpdaterController?
    private lazy var studioWindowController = StudioWindowController(companionManager: companionManager)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ClickyUnifiedTelemetry.lifecycle.info(
            "App launch began version=\(version, privacy: .public)"
        )
        ClickyLogger.notice(.app, "Launching Clicky version=\(version)")

        terminateOtherRunningClickyInstances()

        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 0])

        ClickyFontRegistrar.registerBundledFonts()
        ClickyAnalytics.configure()
        ClickyAnalytics.trackAppOpened()

        #if DEBUG
        NSApp.setActivationPolicy(.regular)
        #endif

        menuBarPanelManager = MenuBarPanelManager(
            companionManager: companionManager,
            studioWindowPresenter: self
        )
        checkForUpdatesObserver = NotificationCenter.default.addObserver(
            forName: .clickyCheckForUpdates,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForUpdates()
            }
        }
        companionManager.start()
        // Auto-open the panel if the user still needs to do something:
        // either they haven't onboarded yet, or permissions were revoked.
        if !companionManager.hasCompletedOnboarding || !companionManager.allPermissionsGranted {
            menuBarPanelManager?.showPanelOnLaunch()
        }
        registerAsLoginItemIfNeeded()
        startSparkleUpdater()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClickyUnifiedTelemetry.lifecycle.info("App termination began")
        ClickyLogger.notice(.app, "Terminating Clicky")
        companionManager.stop()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            companionManager.handleClickyLaunchCallback(url: url)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        companionManager.handleApplicationDidBecomeActive()
    }

    func checkForUpdates() {
        if sparkleUpdaterController == nil {
            startSparkleUpdater()
        }

        ClickyUnifiedTelemetry.lifecycle.info("Manual Sparkle update check requested")
        sparkleUpdaterController?.checkForUpdates(nil)
    }

    func showStudioWindow(source: String = "app") {
        ClickyUnifiedTelemetry.windowing.info(
            "Studio handoff began source=\(source, privacy: .public)"
        )
        #if !DEBUG
        NSApp.setActivationPolicy(.regular)
        #endif
        studioWindowController.showWindow(source: source)
    }

    /// Registers the app as a login item so it launches automatically on
    /// startup. Uses SMAppService which shows the app in System Settings >
    /// General > Login Items, letting the user toggle it off if they want.
    private func registerAsLoginItemIfNeeded() {
        let loginItemService = SMAppService.mainApp
        if loginItemService.status != .enabled {
            do {
                try loginItemService.register()
                ClickyUnifiedTelemetry.lifecycle.info("Login item registered")
            } catch {
                ClickyUnifiedTelemetry.lifecycle.error(
                    "Login item registration failed error=\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func startSparkleUpdater() {
        guard sparkleUpdaterController == nil else { return }

        let updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.sparkleUpdaterController = updaterController

        updaterController.startUpdater()
        ClickyUnifiedTelemetry.lifecycle.info("Sparkle updater started")
        ClickyLogger.notice(.app, "Sparkle updater started")
    }

    private func terminateOtherRunningClickyInstances() {
        guard let currentBundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let otherRunningClickyApplications = NSWorkspace.shared.runningApplications.filter { runningApplication in
            runningApplication.bundleIdentifier == currentBundleIdentifier
                && runningApplication.processIdentifier != currentProcessIdentifier
        }

        for runningApplication in otherRunningClickyApplications {
            ClickyUnifiedTelemetry.lifecycle.info(
                "Duplicate instance termination requested pid=\(String(runningApplication.processIdentifier), privacy: .public)"
            )
            ClickyLogger.notice(.app, "Terminating duplicate instance pid=\(runningApplication.processIdentifier)")
            _ = runningApplication.terminate()
        }
    }
}

private final class StudioWindowController: NSWindowController, NSWindowDelegate {
    init(companionManager: CompanionManager) {
        let studioRootView = CompanionStudioNextView(companionManager: companionManager)
        let hostingController = NSHostingController(rootView: studioRootView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = "Clicky Studio"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 980, height: 680)
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }

        super.init(window: window)

        window.delegate = self
        window.center()
        window.setFrameAutosaveName("ClickyStudioWindow")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow(source: String) {
        guard let window else {
            ClickyUnifiedTelemetry.windowing.error(
                "Studio window presentation failed source=\(source, privacy: .public) reason=missing-window"
            )
            return
        }

        ClickyUnifiedTelemetry.windowing.info(
            "Studio window presentation began source=\(source, privacy: .public)"
        )
        let wasVisible = window.isVisible
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        super.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        window.orderFrontRegardless()
        ClickyUnifiedTelemetry.windowing.info(
            "Studio window presented source=\(source, privacy: .public) reused=\(wasVisible ? "true" : "false", privacy: .public)"
        )
    }

    func windowWillClose(_ notification: Notification) {
        ClickyUnifiedTelemetry.windowing.info("Studio window will close")
        #if !DEBUG
        NSApp.setActivationPolicy(.accessory)
        #endif
    }
}
