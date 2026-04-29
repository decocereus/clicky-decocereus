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
import Combine
import OSLog
import QuartzCore
import SwiftUI

extension Notification.Name {
    static let clickyDismissPanel = Notification.Name("clickyDismissPanel")
    static let clickyOpenStudio = Notification.Name("clickyOpenStudio")
    static let clickyCheckForUpdates = Notification.Name("clickyCheckForUpdates")
    static let clickyShowPanel = Notification.Name("clickyShowPanel")
    static let clickyPanelNeedsLayout = Notification.Name("clickyPanelNeedsLayout")
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
    private var panelNeedsLayoutObserver: NSObjectProtocol?
    private var isPanelRelayoutScheduled = false
    private var scheduledPanelRelayoutIsAnimated = false
    private var stateCancellables: Set<AnyCancellable> = []
    private var iconAnimationTimer: Timer?
    private var iconAnimationPhase: CGFloat = 0
    private var currentIconState: ClickyMenuBarIconState = .idle

    private let companionManager: CompanionManager
    private let preferences: ClickyPreferencesStore
    private let surfaceController: ClickySurfaceController
    private let launchAccessController: ClickyLaunchAccessController
    private let backendRoutingController: ClickyBackendRoutingController
    private weak var studioWindowPresenter: CompanionAppDelegate?
    private let panelWidth: CGFloat = 360
    private let panelHeight: CGFloat = 380

    init(companionManager: CompanionManager, studioWindowPresenter: CompanionAppDelegate) {
        self.companionManager = companionManager
        self.preferences = companionManager.preferences
        self.surfaceController = companionManager.surfaceController
        self.launchAccessController = companionManager.launchAccessController
        self.backendRoutingController = companionManager.backendRoutingController
        self.studioWindowPresenter = studioWindowPresenter
        super.init()
        createStatusItem()
        bindMenuBarIconState()
        updateMenuBarIconState()

        dismissPanelObserver = NotificationCenter.default.addObserver(
            forName: .clickyDismissPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hidePanel(reason: "notification")
            }
        }

        openStudioObserver = NotificationCenter.default.addObserver(
            forName: .clickyOpenStudio,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hidePanel(reason: "opening-studio")
                self?.openStudioWindow(source: "companion-panel")
            }
        }

        showPanelObserver = NotificationCenter.default.addObserver(
            forName: .clickyShowPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showPanel(source: "notification")
            }
        }

        panelNeedsLayoutObserver = NotificationCenter.default.addObserver(
            forName: .clickyPanelNeedsLayout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleVisiblePanelRelayout(animated: true)
            }
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
        if let observer = panelNeedsLayoutObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        iconAnimationTimer?.invalidate()
    }

    // MARK: - Status Item

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.isVisible = true

        guard let button = statusItem?.button else { return }

        button.image = makeClickyMenuBarIcon(state: currentIconState, phase: iconAnimationPhase)
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = "Clicky"
        button.action = #selector(statusItemClicked)
        button.target = self
        button.imageScaling = .scaleNone
    }

    /// Draws the clicky triangle as a menu bar icon. Uses the same shape
    /// and rotation as the in-app cursor so the menu bar icon matches.
    private func makeClickyMenuBarIcon(state: ClickyMenuBarIconState, phase: CGFloat) -> NSImage {
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

        let fillAlpha: CGFloat
        switch state {
        case .idle:
            fillAlpha = 0.92
        case .listening:
            fillAlpha = 0.70 + (0.20 * listeningPulse(phase: phase))
        case .thinking:
            fillAlpha = 0.80
        case .responding:
            fillAlpha = 0.84
        case .onboarding:
            fillAlpha = 0.76
        case .signInRequired:
            fillAlpha = 0.82
        case .locked:
            fillAlpha = 0.66
        case .backendIssue:
            fillAlpha = 0.74
        }

        NSColor.black.withAlphaComponent(fillAlpha).setFill()
        path.fill()

        switch state {
        case .thinking, .responding:
            drawSweepHighlight(in: path, iconSize: iconSize, phase: phase, intensity: state == .responding ? 0.22 : 0.16)
        case .listening:
            drawListeningHalo(around: path, phase: phase)
        case .onboarding:
            drawStatusBadge(iconSize: iconSize, style: .dot)
        case .signInRequired:
            drawStatusBadge(iconSize: iconSize, style: .ring)
        case .locked:
            drawStatusBadge(iconSize: iconSize, style: .bar)
        case .backendIssue:
            drawStatusBadge(iconSize: iconSize, style: .dot)
        case .idle:
            break
        }

        image.unlockFocus()
        return image
    }

    private func bindMenuBarIconState() {
        preferences.$selectedAgentBackend
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
        preferences.$hasCompletedOnboarding
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
        surfaceController.$voiceState
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
        surfaceController.$hasAccessibilityPermission
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
        surfaceController.$hasScreenRecordingPermission
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
        surfaceController.$hasMicrophonePermission
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
        surfaceController.$hasScreenContentPermission
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
        launchAccessController.$clickyLaunchAuthState
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
        launchAccessController.$clickyLaunchTrialState
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
        backendRoutingController.$openClawConnectionStatus
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
        backendRoutingController.$codexRuntimeStatus
            .sink { [weak self] _ in self?.updateMenuBarIconState() }
            .store(in: &stateCancellables)
    }

    private func updateMenuBarIconState() {
        let input = ClickyMenuBarIconStateInput(
            hasCompletedOnboarding: preferences.hasCompletedOnboarding,
            hasAccessibilityPermission: surfaceController.hasAccessibilityPermission,
            hasScreenRecordingPermission: surfaceController.hasScreenRecordingPermission,
            hasMicrophonePermission: surfaceController.hasMicrophonePermission,
            hasScreenContentPermission: surfaceController.hasScreenContentPermission,
            voiceState: surfaceController.voiceState,
            selectedBackend: preferences.selectedAgentBackend,
            launchAuthState: launchAccessController.clickyLaunchAuthState,
            launchTrialState: launchAccessController.clickyLaunchTrialState,
            openClawConnectionStatus: backendRoutingController.openClawConnectionStatus,
            codexRuntimeStatus: backendRoutingController.codexRuntimeStatus
        )

        let resolvedState = ClickyMenuBarIconStateResolver.resolve(input)
        currentIconState = resolvedState
        syncMenuBarIconAnimationDriver()
        applyMenuBarIcon()
    }

    private func syncMenuBarIconAnimationDriver() {
        if currentIconState.isAnimated {
            guard iconAnimationTimer == nil else { return }
            iconAnimationPhase = 0
            iconAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tickMenuBarIconAnimation()
                }
            }
        } else {
            iconAnimationTimer?.invalidate()
            iconAnimationTimer = nil
            iconAnimationPhase = 0
        }
    }

    private func tickMenuBarIconAnimation() {
        let phaseStep: CGFloat
        switch currentIconState {
        case .listening:
            phaseStep = 0.06
        case .thinking:
            phaseStep = 0.08
        case .responding:
            phaseStep = 0.10
        case .idle, .onboarding, .signInRequired, .locked, .backendIssue:
            phaseStep = 0
        }

        iconAnimationPhase += phaseStep
        applyMenuBarIcon()
    }

    private func applyMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        button.image = makeClickyMenuBarIcon(state: currentIconState, phase: iconAnimationPhase)
        button.image?.isTemplate = true
    }

    private func listeningPulse(phase: CGFloat) -> CGFloat {
        (sin(phase * .pi * 2) + 1) / 2
    }

    private func drawListeningHalo(around path: NSBezierPath, phase: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let haloPath = path.copy() as? NSBezierPath ?? path
        haloPath.lineWidth = 1.8
        NSColor.black.withAlphaComponent(0.10 + (0.10 * listeningPulse(phase: phase))).setStroke()
        haloPath.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawSweepHighlight(in path: NSBezierPath, iconSize: CGFloat, phase: CGFloat, intensity: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()

        let normalizedPhase = phase.truncatingRemainder(dividingBy: 1)
        let sweepWidth = iconSize * 0.42
        let sweepTravel = iconSize * 1.6
        let startX = -iconSize * 0.3
        let currentX = startX + (sweepTravel * normalizedPhase)

        let transform = NSAffineTransform()
        transform.rotate(byRadians: -.pi / 6)
        transform.concat()

        NSColor.white.withAlphaComponent(intensity).setFill()
        let sweepRect = NSRect(x: currentX, y: -iconSize * 0.2, width: sweepWidth, height: iconSize * 1.8)
        NSBezierPath(rect: sweepRect).fill()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawStatusBadge(iconSize: CGFloat, style: MenuBarStatusBadgeStyle) {
        let strokeColor = NSColor.black.withAlphaComponent(0.55)
        let fillColor = NSColor.black.withAlphaComponent(0.35)

        switch style {
        case .dot:
            let rect = NSRect(x: iconSize * 0.62, y: iconSize * 0.14, width: iconSize * 0.18, height: iconSize * 0.18)
            let path = NSBezierPath(ovalIn: rect)
            fillColor.setFill()
            path.fill()
        case .ring:
            let rect = NSRect(x: iconSize * 0.60, y: iconSize * 0.12, width: iconSize * 0.22, height: iconSize * 0.22)
            let path = NSBezierPath(ovalIn: rect)
            path.lineWidth = 1.1
            strokeColor.setStroke()
            path.stroke()
        case .bar:
            let width = iconSize * 0.28
            let height = iconSize * 0.08
            let rect = NSRect(x: iconSize * 0.56, y: iconSize * 0.18, width: width, height: height)
            let path = NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2)
            fillColor.setFill()
            path.fill()
        }
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
        ClickyUnifiedTelemetry.windowing.debug(
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

        guard let panel else { return }
        NSApp.activate(ignoringOtherApps: true)
        positionPanelBelowStatusItem()
        preparePanelForOpenAnimation(panel)

        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        animatePanelOpen(panel)
        relayoutVisiblePanel(animated: false)
        installClickOutsideMonitor()
        ClickyUnifiedTelemetry.windowing.debug(
            "Companion panel presented source=\(source, privacy: .public)"
        )
    }

    private func hidePanel(reason: String) {
        guard let panel else {
            removeClickOutsideMonitor()
            return
        }

        let wasVisible = panel.isVisible
        removeClickOutsideMonitor()

        guard wasVisible else { return }

        animatePanelClose(panel)

        ClickyUnifiedTelemetry.windowing.debug(
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

    private func preparePanelForOpenAnimation(_ panel: NSPanel) {
        panel.alphaValue = 0
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.transform = CATransform3DMakeScale(0.985, 0.985, 1)
    }

    private func animatePanelOpen(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1
        }

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.985
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = 0.22
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        panel.contentView?.layer?.add(scaleAnimation, forKey: "clicky-panel-open-scale")
        panel.contentView?.layer?.transform = CATransform3DIdentity
    }

    private func animatePanelClose(_ panel: NSPanel) {
        panel.contentView?.wantsLayer = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.completionHandler = {
                panel.orderOut(nil)
                panel.alphaValue = 1
                panel.contentView?.layer?.transform = CATransform3DIdentity
            }

            panel.animator().alphaValue = 0
        }

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 0.992
        scaleAnimation.duration = 0.16
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        panel.contentView?.layer?.add(scaleAnimation, forKey: "clicky-panel-close-scale")
        panel.contentView?.layer?.transform = CATransform3DMakeScale(0.992, 0.992, 1)
    }

    private func relayoutVisiblePanel(animated: Bool) {
        guard let panel, panel.isVisible else { return }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.positionPanelBelowStatusItem(animated: true)
            }
        } else {
            positionPanelBelowStatusItem(animated: false)
        }
    }

    private func scheduleVisiblePanelRelayout(animated: Bool) {
        scheduledPanelRelayoutIsAnimated = scheduledPanelRelayoutIsAnimated || animated

        guard !isPanelRelayoutScheduled else { return }
        isPanelRelayoutScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let shouldAnimate = self.scheduledPanelRelayoutIsAnimated
            self.isPanelRelayoutScheduled = false
            self.scheduledPanelRelayoutIsAnimated = false
            self.relayoutVisiblePanel(animated: shouldAnimate)
        }
    }

    private func positionPanelBelowStatusItem() {
        positionPanelBelowStatusItem(animated: false)
    }

    private func positionPanelBelowStatusItem(animated: Bool) {
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

        let targetFrame = NSRect(x: panelOriginX, y: panelOriginY, width: panelWidth, height: actualPanelHeight)

        if animated {
            panel.animator().setFrame(targetFrame, display: true)
        } else {
            panel.setFrame(targetFrame, display: true)
        }
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
                if !self.companionManager.permissionCoordinator.allPermissionsGranted && !NSApp.isActive {
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

private enum MenuBarStatusBadgeStyle {
    case dot
    case ring
    case bar
}
