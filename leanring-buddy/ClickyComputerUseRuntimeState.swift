import Foundation

enum ClickyComputerUseRuntimePhase: Equatable {
    case idle
    case starting
    case ready
    case needsPermissions
    case failed(message: String)
}

struct ClickyComputerUsePermissionSnapshot: Equatable {
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
    let checkedAt: String

    var isReady: Bool {
        accessibilityGranted && screenRecordingGranted
    }
}

struct ClickyComputerUseRuntimeSnapshot: Equatable {
    let phase: ClickyComputerUseRuntimePhase
    let baseURLString: String?
    let startedAt: Date?
    let manifestPath: String?
    let contractVersion: String?
    let permissions: ClickyComputerUsePermissionSnapshot?
    let summary: String

    static let idle = ClickyComputerUseRuntimeSnapshot(
        phase: .idle,
        baseURLString: nil,
        startedAt: nil,
        manifestPath: nil,
        contractVersion: nil,
        permissions: nil,
        summary: "Computer use has not started yet."
    )
}

enum ClickyComputerUsePendingActionStatus: Equatable {
    case pending
    case executing
    case completed(message: String)
    case canceled
    case failed(message: String)
}

struct ClickyComputerUsePendingAction: Identifiable, Equatable {
    let id: UUID
    let toolName: ClickyComputerUseToolName
    let route: String
    let requestIdentifier: String
    let summary: String
    let originalUserRequest: String?
    let rawPayload: String
    let requestedAt: Date
    var status: ClickyComputerUsePendingActionStatus
}
