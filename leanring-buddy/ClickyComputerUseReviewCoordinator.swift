//
//  ClickyComputerUseReviewCoordinator.swift
//  leanring-buddy
//
//  Bridges review-gated MCP calls between Clicky's proxy helper and Studio.
//

import Foundation

@MainActor
final class ClickyComputerUseReviewCoordinator {
    private static let pendingRequestTimeout: TimeInterval = 300
    private static let completedDecisionRetention: TimeInterval = 900

    private let routingController: ClickyBackendRoutingController
    private let fileManager: FileManager
    private var pollTimer: Timer?

    init(
        routingController: ClickyBackendRoutingController,
        fileManager: FileManager = .default
    ) {
        self.routingController = routingController
        self.fileManager = fileManager
    }

    var reviewDirectoryURL: URL {
        Self.reviewDirectoryURL(fileManager: fileManager)
    }

    static func reviewDirectoryURL(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL
            .appendingPathComponent("Clicky", isDirectory: true)
            .appendingPathComponent("ComputerUseReview", isDirectory: true)
    }

    func start() {
        ensureReviewDirectories()
        cleanupExpiredReviewFiles()
        refreshPendingRequest()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPendingRequest()
            }
        }
    }

    func stop() {
        denyAllPendingRequests(reason: "clicky_stopped")
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func approveCurrentRequest() {
        guard let request = routingController.computerUsePendingReviewRequest else { return }
        writeDecision(for: request, decisionDirectoryName: "approved")
    }

    func denyCurrentRequest() {
        guard let request = routingController.computerUsePendingReviewRequest else { return }
        writeDecision(for: request, decisionDirectoryName: "denied")
    }

    func denyAllPendingRequests(reason: String) {
        ensureReviewDirectories()
        for request in pendingRequests() {
            writeDecision(
                for: request,
                decisionDirectoryName: "denied",
                reason: reason,
                allowExpired: true
            )
        }
        routingController.computerUsePendingReviewRequest = nil
    }

    func refreshPendingRequest() {
        ensureReviewDirectories()
        cleanupExpiredReviewFiles()
        routingController.computerUsePendingReviewRequest = latestPendingRequest()
    }

    private func latestPendingRequest() -> ClickyComputerUseReviewRequest? {
        pendingRequests().first
    }

    private func pendingRequests() -> [ClickyComputerUseReviewRequest] {
        let pendingDirectoryURL = reviewDirectoryURL.appendingPathComponent("pending", isDirectory: true)
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: pendingDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return fileURLs
            .filter { $0.pathExtension == "json" }
            .sorted { first, second in
                let firstDate = (try? first.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let secondDate = (try? second.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return firstDate < secondDate
            }
            .compactMap(readPendingRequest)
    }

    private func readPendingRequest(from fileURL: URL) -> ClickyComputerUseReviewRequest? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = payload["id"] as? String,
              let toolName = payload["toolName"] as? String,
              let requestDigest = payload["requestDigest"] as? String else {
            return nil
        }

        let argumentsSummary = summarizeArguments(payload["arguments"])
        let createdAt = (payload["createdAt"] as? String).flatMap {
            ISO8601DateFormatter().date(from: $0)
        }

        return ClickyComputerUseReviewRequest(
            id: id,
            toolName: toolName,
            argumentsSummary: argumentsSummary,
            requestDigest: requestDigest,
            createdAt: createdAt
        )
    }

    private func summarizeArguments(_ value: Any?) -> String {
        guard let value else { return "{}" }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let summary = String(data: data, encoding: .utf8) else {
            return String(describing: value)
        }
        return summary
    }

    private func writeDecision(for request: ClickyComputerUseReviewRequest, decisionDirectoryName: String) {
        writeDecision(for: request, decisionDirectoryName: decisionDirectoryName, reason: nil)
    }

    private func writeDecision(
        for request: ClickyComputerUseReviewRequest,
        decisionDirectoryName: String,
        reason: String?,
        allowExpired: Bool = false
    ) {
        guard allowExpired || !request.isExpired else {
            removePendingRequest(withID: request.id)
            routingController.computerUsePendingReviewRequest = nil
            return
        }

        ensureReviewDirectories()
        let decisionDirectoryURL = reviewDirectoryURL.appendingPathComponent(decisionDirectoryName, isDirectory: true)
        let decisionURL = decisionDirectoryURL.appendingPathComponent("\(request.id).json")
        let payload: [String: Any] = [
            "id": request.id,
            "requestDigest": request.requestDigest,
            "reason": reason ?? decisionDirectoryName,
            "decidedAt": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: decisionURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: decisionURL.path)
            routingController.computerUsePendingReviewRequest = nil
        } catch {
            ClickyLogger.error(.agent, "Computer use review decision failed id=\(request.id) error=\(String(describing: error))")
        }
    }

    private func ensureReviewDirectories() {
        for name in ["pending", "approved", "denied"] {
            let directoryURL = reviewDirectoryURL.appendingPathComponent(name, isDirectory: true)
            try? fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
        }
    }

    private func cleanupExpiredReviewFiles(now: Date = Date()) {
        removeExpiredFiles(
            in: reviewDirectoryURL.appendingPathComponent("pending", isDirectory: true),
            maxAge: Self.pendingRequestTimeout,
            now: now
        )
        removeExpiredFiles(
            in: reviewDirectoryURL.appendingPathComponent("approved", isDirectory: true),
            maxAge: Self.completedDecisionRetention,
            now: now
        )
        removeExpiredFiles(
            in: reviewDirectoryURL.appendingPathComponent("denied", isDirectory: true),
            maxAge: Self.completedDecisionRetention,
            now: now
        )
    }

    private func removeExpiredFiles(in directoryURL: URL, maxAge: TimeInterval, now: Date) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for fileURL in fileURLs where fileURL.pathExtension == "json" {
            let modifiedAt = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
            if now.timeIntervalSince(modifiedAt) > maxAge {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    private func removePendingRequest(withID id: String) {
        let pendingURL = reviewDirectoryURL
            .appendingPathComponent("pending", isDirectory: true)
            .appendingPathComponent("\(id).json")
        try? fileManager.removeItem(at: pendingURL)
    }
}

private extension ClickyComputerUseReviewRequest {
    var isExpired: Bool {
        guard let createdAt else {
            return true
        }
        return Date().timeIntervalSince(createdAt) > 300
    }
}
