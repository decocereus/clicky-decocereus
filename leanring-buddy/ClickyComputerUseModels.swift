import Foundation

enum ClickyComputerUseToolName: String, CaseIterable, Sendable {
    case listApps = "list_apps"
    case listWindows = "list_windows"
    case getWindowState = "get_window_state"
    case click = "click"
    case typeText = "type_text"
    case pressKey = "press_key"
    case scroll = "scroll"
    case setValue = "set_value"
    case performSecondaryAction = "perform_secondary_action"
    case drag = "drag"
    case resize = "resize"
    case setWindowFrame = "set_window_frame"
}

enum ClickyComputerUseRiskLevel: Equatable, Sendable {
    case observe
    case lowImpactAction
    case normalMutation
    case sensitiveHighImpact
    case blocked

    var displayName: String {
        switch self {
        case .observe:
            return "Read only"
        case .lowImpactAction:
            return "Low-risk movement"
        case .normalMutation:
            return "Desktop action"
        case .sensitiveHighImpact:
            return "Sensitive"
        case .blocked:
            return "Blocked"
        }
    }
}

struct ClickyComputerUseCapability: Identifiable, Sendable {
    let name: ClickyComputerUseToolName
    let riskLevel: ClickyComputerUseRiskLevel

    var id: String { name.rawValue }
}

enum ClickyComputerUseActionPolicy {
    private struct SensitiveTermGroup {
        let name: String
        let terms: [String]
    }

    private static let sensitiveTermGroups = [
        SensitiveTermGroup(
            name: "delete/remove",
            terms: ["delete", "remove", "trash", "discard", "erase"]
        ),
        SensitiveTermGroup(
            name: "send/submit",
            terms: ["send", "submit", "post", "publish"]
        ),
        SensitiveTermGroup(
            name: "purchase/payment",
            terms: ["buy", "checkout", "pay", "payment", "purchase", "subscribe"]
        ),
        SensitiveTermGroup(
            name: "account/security",
            terms: ["account", "password", "security", "2fa", "mfa", "token", "secret", "api key", "permission"]
        ),
        SensitiveTermGroup(
            name: "terminal/command",
            terms: ["terminal", "shell", "command", "run command", "bash", "zsh", "sudo", "curl"]
        ),
        SensitiveTermGroup(
            name: "irreversible/destructive",
            terms: ["irreversible", "destructive", "permanent", "cannot be undone", "wipe", "reset"]
        ),
    ]

    private static let hardBlockedSensitiveCategories = [
        "terminal/command",
        "irreversible/destructive",
    ]

    static func isProviderExposedWithoutConfirmation(_ toolName: ClickyComputerUseToolName) -> Bool {
        switch toolName {
        case .listApps, .listWindows, .getWindowState:
            return true
        case .click,
             .typeText,
             .pressKey,
             .scroll,
             .setValue,
             .performSecondaryAction,
             .drag,
             .resize,
             .setWindowFrame:
            return false
        }
    }

    static var providerExposedReadOnlySurface: [ClickyComputerUseCapability] {
        ClickyComputerUseCapabilities.fullInternalSurface.filter {
            isProviderExposedWithoutConfirmation($0.name)
        }
    }

    static var confirmationGatedSurface: [ClickyComputerUseCapability] {
        ClickyComputerUseCapabilities.fullInternalSurface.filter {
            !isProviderExposedWithoutConfirmation($0.name)
        }
    }

    static func policySummary(for toolName: ClickyComputerUseToolName) -> String {
        if isProviderExposedWithoutConfirmation(toolName) {
            return "read-only provider exposed"
        }
        return "controlled by the user's computer use permission level"
    }

    static func review(
        toolName: ClickyComputerUseToolName,
        rawPayload: String,
        originalUserRequest: String? = nil
    ) -> ClickyComputerUseActionReview {
        let payload = payloadObject(from: rawPayload)
        let sensitiveCategories = sensitiveCategories(for: toolName, payload: payload)
        let riskLevel = riskLevel(
            for: toolName,
            payload: payload
        )
        return ClickyComputerUseActionReview(
            toolName: toolName,
            riskLevel: riskLevel,
            summary: actionSummary(toolName: toolName, payload: payload),
            userRequestPreview: userRequestPreview(from: originalUserRequest),
            policySummary: policySummary(
                for: toolName,
                riskLevel: riskLevel,
                sensitiveCategories: sensitiveCategories
            ),
            payloadPreview: payloadPreview(from: rawPayload),
            sensitiveCategories: sensitiveCategories,
            requiresFreshObservation: riskLevel == .sensitiveHighImpact
        )
    }

    static func riskLevel(
        for toolName: ClickyComputerUseToolName,
        payload: [String: Any] = [:]
    ) -> ClickyComputerUseRiskLevel {
        switch toolName {
        case .listApps, .listWindows, .getWindowState:
            return .observe
        case .scroll, .drag, .resize, .setWindowFrame:
            return .lowImpactAction
        case .pressKey, .click, .typeText, .setValue, .performSecondaryAction:
            let sensitiveCategories = sensitiveCategories(for: toolName, payload: payload)
            guard !sensitiveCategories.isEmpty else {
                return .normalMutation
            }
            if sensitiveCategories.contains(where: hardBlockedSensitiveCategories.contains) {
                return .blocked
            }
            return .sensitiveHighImpact
        }
    }

    private static func policySummary(
        for toolName: ClickyComputerUseToolName,
        riskLevel: ClickyComputerUseRiskLevel,
        sensitiveCategories: [String]
    ) -> String {
        switch riskLevel {
        case .observe:
            return "Read-only provider exposed."
        case .lowImpactAction:
            return "Low-risk movement or window positioning."
        case .normalMutation:
            return "Desktop state will change."
        case .sensitiveHighImpact:
            let categories = sensitiveCategories.joined(separator: ", ")
            let categorySuffix = categories.isEmpty ? "" : " involving \(categories)"
            return "Sensitive action\(categorySuffix). Clicky will ask before running it and re-observe the target window immediately before execution."
        case .blocked:
            let categories = sensitiveCategories.joined(separator: ", ")
            let categorySuffix = categories.isEmpty ? "" : ": \(categories)"
            return "Blocked\(categorySuffix). Clicky does not run this category yet."
        }
    }

    private static func actionSummary(
        toolName: ClickyComputerUseToolName,
        payload: [String: Any]
    ) -> String {
        switch toolName {
        case .listApps:
            return "List running apps."
        case .listWindows:
            return "List live windows."
        case .getWindowState:
            return "Read the current desktop window."
        case .click:
            if let target = targetSummary(payload) {
                return "Click \(target) in \(windowSummary(payload))."
            }
            if let x = numberValue(payload["x"]), let y = numberValue(payload["y"]) {
                return "Click at \(Int(x)), \(Int(y)) in \(windowSummary(payload))."
            }
            return "Click in \(windowSummary(payload))."
        case .typeText:
            return "Type \(quoted(payload["text"])) in \(windowSummary(payload))."
        case .pressKey:
            return "Press \(quoted(payload["key"])) in \(windowSummary(payload))."
        case .scroll:
            let direction = stringValue(payload["direction"]) ?? "the requested direction"
            return "Scroll \(direction) in \(windowSummary(payload))."
        case .setValue:
            let target = targetSummary(payload) ?? "the requested target"
            return "Set \(target) to \(quoted(payload["value"])) in \(windowSummary(payload))."
        case .performSecondaryAction:
            return "Run secondary action \(quoted(payload["action"])) in \(windowSummary(payload))."
        case .drag:
            return "Drag to \(coordinateSummary(payload)) in \(windowSummary(payload))."
        case .resize:
            return "Resize \(windowSummary(payload)) using handle \(quoted(payload["handle"]))."
        case .setWindowFrame:
            return "Move and resize \(windowSummary(payload)) to \(frameSummary(payload))."
        }
    }

    private static func payloadObject(from rawPayload: String) -> [String: Any] {
        guard let data = rawPayload.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return payload
    }

    private static func payloadPreview(from rawPayload: String) -> String {
        let trimmed = rawPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "No payload." }
        if trimmed.count <= 700 { return trimmed }
        return String(trimmed.prefix(700)) + "..."
    }

    private static func userRequestPreview(from originalUserRequest: String?) -> String {
        let trimmed = originalUserRequest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "Original user request unavailable." }
        if trimmed.count <= 280 { return trimmed }
        return String(trimmed.prefix(280)) + "..."
    }

    private static func sensitiveCategories(
        for toolName: ClickyComputerUseToolName,
        payload: [String: Any]
    ) -> [String] {
        let text = payloadSearchText(payload)
        guard !text.isEmpty else { return [] }
        return sensitiveTermGroups.compactMap { group in
            if ignoresSensitiveGroup(group.name, for: toolName, payload: payload) {
                return nil
            }
            return group.terms.contains { text.contains($0) } ? group.name : nil
        }
    }

    private static func ignoresSensitiveGroup(
        _ groupName: String,
        for toolName: ClickyComputerUseToolName,
        payload: [String: Any]
    ) -> Bool {
        guard groupName == "send/submit" else { return false }

        switch toolName {
        case .typeText, .setValue:
            return true
        case .click:
            return clickOpensCompositionSurface(payload)
        case .listApps, .listWindows, .getWindowState, .pressKey, .scroll, .performSecondaryAction, .drag, .resize, .setWindowFrame:
            return false
        }
    }

    private static func clickOpensCompositionSurface(_ payload: [String: Any]) -> Bool {
        let searchText = payloadSearchText(payload)
        guard !searchText.isEmpty else { return false }

        let hasCompositionVerb = containsAny(
            ["compose", "composer", "draft", "new post", "new tweet", "create post", "create tweet"],
            in: searchText
        )
        let hasNavigationContext = containsAny(
            ["sidebar", "side bar", "left nav", "left navigation", "navigation", "global nav", "main nav"],
            in: searchText
        )
        let asksToOpenComposition = containsAny(
            ["open composer", "open compose", "open draft", "start draft", "create draft"],
            in: searchText
        )

        guard hasNavigationContext || asksToOpenComposition else { return false }
        return hasCompositionVerb || searchText.contains("post button") || searchText.contains("tweet button")
    }

    private static func containsAny(_ needles: [String], in haystack: String) -> Bool {
        needles.contains { haystack.contains($0) }
    }

    private static func payloadSearchText(_ payload: [String: Any]) -> String {
        normalizedSearchText(
            payload.values.map { value in
                if let string = value as? String {
                    return string
                }
                return String(describing: value)
            }
            .joined(separator: " ")
        )
    }

    private static func normalizedSearchText(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func windowSummary(_ payload: [String: Any]) -> String {
        if let window = stringValue(payload["window"]) {
            return "window \(window)"
        }
        return "the current window"
    }

    private static func targetSummary(_ payload: [String: Any]) -> String? {
        guard let target = payload["target"] as? [String: Any],
              let kind = stringValue(target["kind"]) else {
            return nil
        }
        if let value = stringValue(target["value"]) {
            return "\(kind) \(value)"
        }
        if let value = integerValue(target["value"]) {
            return "\(kind) \(value)"
        }
        return kind
    }

    private static func coordinateSummary(_ payload: [String: Any]) -> String {
        guard let x = numberValue(payload["toX"]), let y = numberValue(payload["toY"]) else {
            return "the requested point"
        }
        return "\(Int(x)), \(Int(y))"
    }

    private static func frameSummary(_ payload: [String: Any]) -> String {
        guard let x = numberValue(payload["x"]),
              let y = numberValue(payload["y"]),
              let width = numberValue(payload["width"]),
              let height = numberValue(payload["height"]) else {
            return "the requested frame"
        }
        return "x \(Int(x)), y \(Int(y)), width \(Int(width)), height \(Int(height))"
    }

    private static func quoted(_ value: Any?) -> String {
        guard let string = stringValue(value), !string.isEmpty else {
            return "the requested value"
        }
        return "\"\(string)\""
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func numberValue(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        return number.doubleValue
    }

    private static func integerValue(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        return number.intValue
    }
}

enum ClickyComputerUseCapabilities {
    static let fullInternalSurface: [ClickyComputerUseCapability] = [
        ClickyComputerUseCapability(name: .listApps, riskLevel: .observe),
        ClickyComputerUseCapability(name: .listWindows, riskLevel: .observe),
        ClickyComputerUseCapability(name: .getWindowState, riskLevel: .observe),
        ClickyComputerUseCapability(name: .click, riskLevel: .normalMutation),
        ClickyComputerUseCapability(name: .typeText, riskLevel: .normalMutation),
        ClickyComputerUseCapability(name: .pressKey, riskLevel: .normalMutation),
        ClickyComputerUseCapability(name: .scroll, riskLevel: .lowImpactAction),
        ClickyComputerUseCapability(name: .setValue, riskLevel: .normalMutation),
        ClickyComputerUseCapability(name: .performSecondaryAction, riskLevel: .normalMutation),
        ClickyComputerUseCapability(name: .drag, riskLevel: .lowImpactAction),
        ClickyComputerUseCapability(name: .resize, riskLevel: .lowImpactAction),
        ClickyComputerUseCapability(name: .setWindowFrame, riskLevel: .lowImpactAction),
    ]
}

struct ClickyComputerUseActionReview: Equatable, Sendable {
    let toolName: ClickyComputerUseToolName
    let riskLevel: ClickyComputerUseRiskLevel
    let summary: String
    let userRequestPreview: String
    let policySummary: String
    let payloadPreview: String
    let sensitiveCategories: [String]
    let requiresFreshObservation: Bool

    var isBlocked: Bool {
        riskLevel == .blocked
    }
}
