import BackgroundComputerUse
import Combine
import Foundation
import OSLog

@MainActor
final class ClickyComputerUseController: ObservableObject {
    @Published private(set) var runtimeSnapshot: ClickyComputerUseRuntimeSnapshot = .idle
    @Published private(set) var pendingAction: ClickyComputerUsePendingAction?

    private let runtime = BackgroundComputerUseRuntime()
    private var startupTask: Task<Void, Never>?
    private(set) lazy var client = ClickyComputerUseClient { [weak self] in
        guard let baseURLString = self?.runtimeSnapshot.baseURLString else {
            return nil
        }
        return URL(string: baseURLString)
    }

    var statusLabel: String {
        switch runtimeSnapshot.phase {
        case .idle:
            return "Idle"
        case .starting:
            return "Starting"
        case .ready:
            return "Ready"
        case .needsPermissions:
            return "Needs permissions"
        case .failed:
            return "Failed"
        }
    }

    var isReady: Bool {
        runtimeSnapshot.phase == .ready
    }

    var permissionSummary: String {
        guard let permissions = runtimeSnapshot.permissions else {
            return "Permission state has not been checked yet."
        }

        if permissions.isReady {
            return "Accessibility and Screen Recording are enabled."
        }

        return "Needs \(missingPermissionNames.joined(separator: " and "))."
    }

    var enablementGuidance: String {
        switch runtimeSnapshot.phase {
        case .ready:
            return "Computer use is enabled."
        case .idle, .starting:
            return "Computer use is still starting. Open Studio and check the Computer Use card if it does not become ready."
        case .needsPermissions:
            return "Computer use needs \(missingPermissionNames.joined(separator: " and ")). Open Studio, use the Computer Use card, then approve the macOS permission prompts."
        case .failed(let message):
            return "Computer use could not start: \(message)"
        }
    }

    var missingPermissionNames: [String] {
        guard let permissions = runtimeSnapshot.permissions else {
            return ["Accessibility", "Screen Recording"]
        }

        var names: [String] = []
        if !permissions.accessibilityGranted {
            names.append("Accessibility")
        }
        if !permissions.screenRecordingGranted {
            names.append("Screen Recording")
        }
        return names
    }

    func startWithAppIfNeeded() {
        guard startupTask == nil else { return }

        runtimeSnapshot = ClickyComputerUseRuntimeSnapshot(
            phase: .starting,
            baseURLString: nil,
            startedAt: nil,
            manifestPath: nil,
            contractVersion: nil,
            permissions: currentPermissionSnapshot(),
            summary: "Starting Clicky's bundled computer-use runtime."
        )

        startupTask = Task { [weak self] in
            guard let self else { return }
            do {
                let status = try await runtime.start()
                await MainActor.run {
                    self.runtimeSnapshot = Self.snapshot(from: status)
                    ClickyUnifiedTelemetry.computerUse.info(
                        "Computer-use runtime started ready=\(status.ready ? "true" : "false", privacy: .public) baseURL=\(status.baseURL.absoluteString, privacy: .private)"
                    )
                }
            } catch {
                await MainActor.run {
                    self.runtimeSnapshot = ClickyComputerUseRuntimeSnapshot(
                        phase: .failed(message: error.localizedDescription),
                        baseURLString: nil,
                        startedAt: nil,
                        manifestPath: nil,
                        contractVersion: nil,
                        permissions: self.currentPermissionSnapshot(),
                        summary: "Clicky could not start the bundled computer-use runtime."
                    )
                    ClickyUnifiedTelemetry.computerUse.error(
                        "Computer-use runtime start failed error=\(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    func refreshRuntimeStatus() {
        if let status = runtime.currentStatus() {
            runtimeSnapshot = Self.snapshot(from: status)
            return
        }

        runtimeSnapshot = ClickyComputerUseRuntimeSnapshot(
            phase: runtimeSnapshot.phase,
            baseURLString: runtimeSnapshot.baseURLString,
            startedAt: runtimeSnapshot.startedAt,
            manifestPath: runtimeSnapshot.manifestPath,
            contractVersion: runtimeSnapshot.contractVersion,
            permissions: currentPermissionSnapshot(),
            summary: runtimeSnapshot.summary
        )
    }

    func requestAccessibilityPermission() {
        _ = BackgroundComputerUseRuntime.requestAccessibilityPermissionIfNeeded()
        refreshRuntimeStatus()
    }

    func requestScreenRecordingPermission() {
        _ = BackgroundComputerUseRuntime.requestScreenRecordingPermissionIfNeeded()
        refreshRuntimeStatus()
    }

    func requestActionConfirmation(
        toolName: ClickyComputerUseToolName,
        route: String,
        requestIdentifier: String,
        rawPayload: String,
        summary: String,
        originalUserRequest: String?
    ) {
        ClickyUnifiedTelemetry.computerUse.info(
            "Computer-use action confirmation requested tool=\(toolName.rawValue, privacy: .public)"
        )
        pendingAction = ClickyComputerUsePendingAction(
            id: UUID(),
            toolName: toolName,
            route: route,
            requestIdentifier: requestIdentifier,
            summary: summary,
            originalUserRequest: originalUserRequest,
            rawPayload: rawPayload,
            requestedAt: Date(),
            status: .pending
        )
        NotificationCenter.default.post(name: .clickyPanelNeedsLayout, object: nil)
    }

    func cancelPendingAction() {
        guard var action = pendingAction else { return }
        action.status = .canceled
        pendingAction = action
        ClickyUnifiedTelemetry.computerUse.info(
            "Computer-use action canceled tool=\(action.toolName.rawValue, privacy: .public)"
        )
    }

    func clearPendingAction() {
        pendingAction = nil
    }

    func markPendingActionExecuting() {
        guard var action = pendingAction else { return }
        action.status = .executing
        pendingAction = action
        ClickyUnifiedTelemetry.computerUse.info(
            "Computer-use action approval executing tool=\(action.toolName.rawValue, privacy: .public)"
        )
    }

    func completePendingAction(message: String) {
        guard var action = pendingAction else { return }
        action.status = .completed(message: message)
        pendingAction = action
        ClickyUnifiedTelemetry.computerUse.info(
            "Computer-use action completed tool=\(action.toolName.rawValue, privacy: .public)"
        )
    }

    func failPendingAction(message: String) {
        guard var action = pendingAction else { return }
        action.status = .failed(message: message)
        pendingAction = action
        ClickyUnifiedTelemetry.computerUse.error(
            "Computer-use action failed tool=\(action.toolName.rawValue, privacy: .public) error=\(message, privacy: .public)"
        )
    }

    private func currentPermissionSnapshot() -> ClickyComputerUsePermissionSnapshot {
        let permissions = BackgroundComputerUseRuntime.currentPermissions()
        return ClickyComputerUsePermissionSnapshot(
            accessibilityGranted: permissions.accessibility.granted,
            screenRecordingGranted: permissions.screenRecording.granted,
            checkedAt: permissions.checkedAt
        )
    }

    private static func snapshot(
        from status: BackgroundComputerUseRuntimeStatus
    ) -> ClickyComputerUseRuntimeSnapshot {
        let permissions = ClickyComputerUsePermissionSnapshot(
            accessibilityGranted: status.permissions.accessibility.granted,
            screenRecordingGranted: status.permissions.screenRecording.granted,
            checkedAt: status.permissions.checkedAt
        )

        return ClickyComputerUseRuntimeSnapshot(
            phase: status.ready ? .ready : .needsPermissions,
            baseURLString: status.baseURL.absoluteString,
            startedAt: status.startedAt,
            manifestPath: status.manifestPath,
            contractVersion: status.contractVersion,
            permissions: permissions,
            summary: status.summary
        )
    }
}
