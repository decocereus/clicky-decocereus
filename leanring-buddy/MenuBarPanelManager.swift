//
//  MenuBarPanelManager.swift
//  leanring-buddy
//
//  Manages the NSStatusItem (menu bar icon) and a custom borderless NSPanel
//  that drops down below it when clicked. The panel hosts a SwiftUI view
//  (CompanionPanelView) via NSHostingView. Uses the same NSPanel pattern as
//  FloatingSessionButton and GlobalPushToTalkOverlay for consistency.
//
//  The panel is non-activating so it does not steal focus from the user's
//  current app, and auto-dismisses when the user clicks outside.
//

import AppKit
import OSLog
import SwiftUI

extension Notification.Name {
    static let clickyDismissPanel = Notification.Name("clickyDismissPanel")
    static let clickyOpenStudio = Notification.Name("clickyOpenStudio")
    static let clickyShowPanel = Notification.Name("clickyShowPanel")
    static let clickyStudioDidAppear = Notification.Name("clickyStudioDidAppear")
    static let clickyStudioDidDisappear = Notification.Name("clickyStudioDidDisappear")
}

/// Custom NSPanel subclass that can become the key window even with
/// .nonactivatingPanel style, allowing text fields to receive focus.
private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class MenuBarPanelManager: NSObject {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var clickOutsideMonitor: Any?
    private var dismissPanelObserver: NSObjectProtocol?
    private var openStudioObserver: NSObjectProtocol?
    private var showPanelObserver: NSObjectProtocol?

    private let companionManager: CompanionManager
    private weak var studioWindowPresenter: CompanionAppDelegate?
    private let panelWidth: CGFloat = 360
    private let panelHeight: CGFloat = 380

    init(companionManager: CompanionManager, studioWindowPresenter: CompanionAppDelegate) {
        self.companionManager = companionManager
        self.studioWindowPresenter = studioWindowPresenter
        super.init()
        createStatusItem()

        dismissPanelObserver = NotificationCenter.default.addObserver(
            forName: .clickyDismissPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hidePanel(reason: "notification")
        }

        openStudioObserver = NotificationCenter.default.addObserver(
            forName: .clickyOpenStudio,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hidePanel(reason: "opening-studio")
            self?.openStudioWindow(source: "companion-panel")
        }

        showPanelObserver = NotificationCenter.default.addObserver(
            forName: .clickyShowPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showPanel(source: "notification")
        }
    }

    deinit {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = dismissPanelObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = openStudioObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = showPanelObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Status Item

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.isVisible = true

        guard let button = statusItem?.button else { return }

        button.image = makeClickyMenuBarIcon()
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = "Clicky"
        button.action = #selector(statusItemClicked)
        button.target = self
    }

    /// Draws the clicky triangle as a menu bar icon. Uses the same shape
    /// and rotation as the in-app cursor so the menu bar icon matches.
    private func makeClickyMenuBarIcon() -> NSImage {
        let iconSize: CGFloat = 18
        let image = NSImage(size: NSSize(width: iconSize, height: iconSize))
        image.lockFocus()

        let triangleSize = iconSize * 0.7
        let cx = iconSize * 0.50
        let cy = iconSize * 0.50
        let height = triangleSize * sqrt(3.0) / 2.0

        let top = CGPoint(x: cx, y: cy + height / 1.5)
        let bottomLeft = CGPoint(x: cx - triangleSize / 2, y: cy - height / 3)
        let bottomRight = CGPoint(x: cx + triangleSize / 2, y: cy - height / 3)

        let angle = 35.0 * .pi / 180.0
        func rotate(_ point: CGPoint) -> CGPoint {
            let dx = point.x - cx, dy = point.y - cy
            let cosA = CGFloat(cos(angle)), sinA = CGFloat(sin(angle))
            return CGPoint(x: cx + cosA * dx - sinA * dy, y: cy + sinA * dx + cosA * dy)
        }

        let path = NSBezierPath()
        path.move(to: rotate(top))
        path.line(to: rotate(bottomLeft))
        path.line(to: rotate(bottomRight))
        path.close()

        NSColor.black.setFill()
        path.fill()

        image.unlockFocus()
        return image
    }

    /// Opens the panel automatically on app launch so the user sees
    /// permissions and the start button right away.
    func showPanelOnLaunch() {
        // Small delay so the status item has time to appear in the menu bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showPanel(source: "launch-required-action")
        }
    }

    func showStudioOnLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.openStudioWindow(source: "debug-launch")
        }
    }

    private func openStudioWindow(source: String) {
        ClickyUnifiedTelemetry.windowing.info(
            "Studio open requested source=\(source, privacy: .public)"
        )
        NSApp.activate(ignoringOtherApps: true)
        guard let studioWindowPresenter else {
            ClickyUnifiedTelemetry.windowing.error(
                "Studio open dropped source=\(source, privacy: .public) reason=missing-studio-presenter"
            )
            return
        }

        studioWindowPresenter.showStudioWindow(source: source)
    }

    @objc private func statusItemClicked() {
        if let panel, panel.isVisible {
            hidePanel(reason: "status-item-toggle")
        } else {
            showPanel(source: "status-item-toggle")
        }
    }

    // MARK: - Panel Lifecycle

    private func showPanel(source: String) {
        if panel == nil {
            createPanel()
        }

        NSApp.activate(ignoringOtherApps: true)
        positionPanelBelowStatusItem()

        panel?.makeKeyAndOrderFront(nil)
        panel?.orderFrontRegardless()
        installClickOutsideMonitor()
        ClickyUnifiedTelemetry.windowing.info(
            "Companion panel presented source=\(source, privacy: .public)"
        )
    }

    private func hidePanel(reason: String) {
        guard let panel else {
            removeClickOutsideMonitor()
            return
        }

        let wasVisible = panel.isVisible
        panel.orderOut(nil)
        removeClickOutsideMonitor()

        guard wasVisible else { return }

        ClickyUnifiedTelemetry.windowing.info(
            "Companion panel dismissed reason=\(reason, privacy: .public)"
        )
    }

    private func createPanel() {
        let companionPanelView = CompanionPanelView(companionManager: companionManager)
            .frame(width: panelWidth)

        let hostingView = NSHostingView(rootView: companionPanelView)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        let menuBarPanel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        menuBarPanel.isFloatingPanel = true
        menuBarPanel.level = .floating
        menuBarPanel.isOpaque = false
        menuBarPanel.backgroundColor = .clear
        menuBarPanel.hasShadow = false
        menuBarPanel.hidesOnDeactivate = false
        menuBarPanel.isExcludedFromWindowsMenu = true
        menuBarPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        menuBarPanel.isMovableByWindowBackground = false
        menuBarPanel.titleVisibility = .hidden
        menuBarPanel.titlebarAppearsTransparent = true

        menuBarPanel.contentView = hostingView
        panel = menuBarPanel
    }

    private func positionPanelBelowStatusItem() {
        guard let panel else { return }
        guard let buttonWindow = statusItem?.button?.window else { return }

        let statusItemFrame = buttonWindow.frame
        let gapBelowMenuBar: CGFloat = 4

        // Calculate the panel's content height from the hosting view's fitting size
        // so the panel snugly wraps the SwiftUI content instead of using a fixed height.
        let fittingSize = panel.contentView?.fittingSize ?? CGSize(width: panelWidth, height: panelHeight)

        // Status item window coordinates can occasionally be stale or far offscreen
        // during first launch on menu bar-only apps. Clamp the final panel frame to
        // a visible display so onboarding never opens outside the user's desktop.
        let fallbackScreen = buttonWindow.screen
            ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
        let fallbackVisibleFrame = fallbackScreen?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: panelWidth, height: fittingSize.height)
        let maxPanelHeight = max(220, fallbackVisibleFrame.height - 12)
        let actualPanelHeight = min(fittingSize.height, maxPanelHeight)

        // Horizontally center the panel beneath the status item icon, then clamp.
        let unclampedPanelOriginX = statusItemFrame.midX - (panelWidth / 2)
        let unclampedPanelOriginY = statusItemFrame.minY - actualPanelHeight - gapBelowMenuBar
        let minimumPanelOriginX = fallbackVisibleFrame.minX
        let maximumPanelOriginX = max(fallbackVisibleFrame.maxX - panelWidth, minimumPanelOriginX)
        let minimumPanelOriginY = fallbackVisibleFrame.minY
        let maximumPanelOriginY = max(fallbackVisibleFrame.maxY - actualPanelHeight, minimumPanelOriginY)

        let panelOriginX = min(max(unclampedPanelOriginX, minimumPanelOriginX), maximumPanelOriginX)
        let panelOriginY = min(max(unclampedPanelOriginY, minimumPanelOriginY), maximumPanelOriginY)

        panel.setFrame(
            NSRect(x: panelOriginX, y: panelOriginY, width: panelWidth, height: actualPanelHeight),
            display: true
        )
    }

    // MARK: - Click Outside Dismissal

    /// Installs a global event monitor that hides the panel when the user clicks
    /// anywhere outside it — the same transient dismissal behavior as NSPopover.
    /// Uses a short delay so that system permission dialogs (triggered by Grant
    /// buttons in the panel) don't immediately dismiss the panel when they appear.
    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, let panel = self.panel else { return }

            // Check if the click is inside the status item button — if so, the
            // statusItemClicked handler will toggle the panel, so don't also hide.
            let clickLocation = NSEvent.mouseLocation
            if panel.frame.contains(clickLocation) {
                return
            }

            // Delay dismissal slightly to avoid closing the panel when
            // a system permission dialog appears (e.g. microphone access).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard panel.isVisible else { return }

                // If permissions aren't all granted yet, a system dialog
                // may have focus — don't dismiss during onboarding.
                if !self.companionManager.allPermissionsGranted && !NSApp.isActive {
                    return
                }

                self.hidePanel(reason: "outside-click")
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }
}
