import Foundation

public struct BackgroundComputerUseRuntimeOptions: Sendable {
    public var visualCursor: VisualCursorMode

    public init(visualCursor: VisualCursorMode = .disabled) {
        self.visualCursor = visualCursor
    }
}

public enum VisualCursorMode: Sendable {
    case disabled
    case enabled
}

public struct BackgroundComputerUsePermissionStatus: Sendable {
    public let granted: Bool
    public let promptable: Bool

    public init(granted: Bool, promptable: Bool) {
        self.granted = granted
        self.promptable = promptable
    }
}

public struct BackgroundComputerUsePermissions: Sendable {
    public let accessibility: BackgroundComputerUsePermissionStatus
    public let screenRecording: BackgroundComputerUsePermissionStatus
    public let checkedAt: String
    public let checkMs: Double

    public var ready: Bool {
        accessibility.granted && screenRecording.granted
    }

    public init(
        accessibility: BackgroundComputerUsePermissionStatus,
        screenRecording: BackgroundComputerUsePermissionStatus,
        checkedAt: String,
        checkMs: Double
    ) {
        self.accessibility = accessibility
        self.screenRecording = screenRecording
        self.checkedAt = checkedAt
        self.checkMs = checkMs
    }
}

public struct BackgroundComputerUseRuntimeStatus: Sendable {
    public let ready: Bool
    public let baseURL: URL
    public let startedAt: Date
    public let manifestPath: String
    public let contractVersion: String
    public let permissions: BackgroundComputerUsePermissions
    public let summary: String

    public init(
        ready: Bool,
        baseURL: URL,
        startedAt: Date,
        manifestPath: String,
        contractVersion: String,
        permissions: BackgroundComputerUsePermissions,
        summary: String
    ) {
        self.ready = ready
        self.baseURL = baseURL
        self.startedAt = startedAt
        self.manifestPath = manifestPath
        self.contractVersion = contractVersion
        self.permissions = permissions
        self.summary = summary
    }
}

public final class BackgroundComputerUseRuntime {
    private let services: RuntimeServices
    private let bootstrap: RuntimeBootstrap
    private var bootState: RuntimeBootState?

    public init(options: BackgroundComputerUseRuntimeOptions = .init()) {
        let actionOptions = ActionExecutionOptions(
            visualCursorEnabled: options.visualCursor == .enabled
        )
        services = RuntimeServices(executionOptions: actionOptions)
        bootstrap = RuntimeBootstrap()
    }

    public func start() async throws -> BackgroundComputerUseRuntimeStatus {
        AppKitRuntimeBootstrap.startIfNeeded()

        if let bootState {
            return Self.makeStatus(from: bootState)
        }

        let state = try await bootstrap.start()
        bootState = state
        return Self.makeStatus(from: state)
    }

    public func currentStatus() -> BackgroundComputerUseRuntimeStatus? {
        guard let bootState else { return nil }
        return Self.makeStatus(from: bootState)
    }

    public static func currentPermissions() -> BackgroundComputerUsePermissions {
        makePermissions(from: RuntimePermissionsSnapshot.current().dto)
    }

    @discardableResult
    public static func requestAccessibilityPermissionIfNeeded() -> Bool {
        AccessibilityAuthorization.isTrusted(prompt: true)
    }

    @discardableResult
    public static func requestScreenRecordingPermissionIfNeeded() -> Bool {
        ScreenCaptureAuthorization.requestIfNeeded()
    }

    public func permissions() -> RuntimePermissionsDTO {
        services.permissions()
    }

    public func listApps() -> ListAppsResponse {
        services.listApps()
    }

    public func listWindows(_ request: ListWindowsRequest) throws -> ListWindowsResponse {
        try services.listWindows(request)
    }

    public func getWindowState(_ request: GetWindowStateRequest) throws -> GetWindowStateResponse {
        try services.getWindowState(request)
    }

    public func click(_ request: ClickRequest) throws -> ClickResponse {
        try services.click(request)
    }

    public func scroll(_ request: ScrollRequest) throws -> ScrollResponse {
        try services.scroll(request)
    }

    public func performSecondaryAction(_ request: PerformSecondaryActionRequest) throws -> PerformSecondaryActionResponse {
        try services.performSecondaryAction(request)
    }

    public func drag(_ request: DragRequest) throws -> DragResponse {
        try services.drag(request)
    }

    public func resize(_ request: ResizeRequest) throws -> ResizeResponse {
        try services.resize(request)
    }

    public func setWindowFrame(_ request: SetWindowFrameRequest) throws -> SetWindowFrameResponse {
        try services.setWindowFrame(request)
    }

    public func typeText(_ request: TypeTextRequest) throws -> TypeTextResponse {
        try services.typeText(request)
    }

    public func pressKey(_ request: PressKeyRequest) throws -> PressKeyResponse {
        try services.pressKey(request)
    }

    public func setValue(_ request: SetValueRequest) throws -> SetValueResponse {
        try services.setValue(request)
    }

    private static func makeStatus(from bootState: RuntimeBootState) -> BackgroundComputerUseRuntimeStatus {
        let permissions = currentPermissions()
        return BackgroundComputerUseRuntimeStatus(
            ready: permissions.ready,
            baseURL: bootState.baseURL,
            startedAt: bootState.startedAt,
            manifestPath: bootState.manifestPath,
            contractVersion: ContractVersion.current,
            permissions: permissions,
            summary: permissions.ready
                ? "BackgroundComputerUse is ready."
                : "BackgroundComputerUse needs Accessibility and Screen Recording permissions."
        )
    }

    private static func makePermissions(from dto: RuntimePermissionsDTO) -> BackgroundComputerUsePermissions {
        BackgroundComputerUsePermissions(
            accessibility: BackgroundComputerUsePermissionStatus(
                granted: dto.accessibility.granted,
                promptable: dto.accessibility.promptable
            ),
            screenRecording: BackgroundComputerUsePermissionStatus(
                granted: dto.screenRecording.granted,
                promptable: dto.screenRecording.promptable
            ),
            checkedAt: dto.checkedAt,
            checkMs: dto.checkMs
        )
    }
}
