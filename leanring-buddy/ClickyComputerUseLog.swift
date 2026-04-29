import Foundation

enum ClickyComputerUseLog {
    nonisolated static func makeActionID() -> String {
        String(UUID().uuidString.prefix(8))
    }

    static func policyDecision(
        id: String,
        review: ClickyComputerUseActionReview,
        decision: String
    ) {
        ClickyLogger.info(
            .computerUse,
            "policy_decision id=\(id) tool=\(review.toolName.rawValue) risk=\(review.riskLevel.logValue) decision=\(decision) sensitive=\(review.sensitiveCategories.joined(separator: ","))"
        )
    }

    static func routeStart(
        id: String,
        route: String,
        payloadSummary: String
    ) {
        ClickyLogger.info(
            .computerUse,
            "route_start id=\(id) route=\(route) payload=\(payloadSummary)"
        )
    }

    static func routeResult(
        id: String,
        route: String,
        statusCode: Int,
        bodyPreview: String
    ) {
        ClickyLogger.info(
            .computerUse,
            "route_result id=\(id) route=\(route) status=\(statusCode) bodyPreview=\"\(short(redactTypedContent(bodyPreview), limit: 260))\""
        )
    }

    static func routeFailure(
        id: String,
        route: String,
        error: Error
    ) {
        ClickyLogger.error(
            .computerUse,
            "route_failure id=\(id) route=\(route) error=\"\(short(errorSummary(error), limit: 420))\""
        )
    }

    nonisolated static func payloadSummary(from rawPayload: String) -> String {
        guard let data = rawPayload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "invalid-json length=\(rawPayload.count)"
        }
        return payloadSummary(from: object)
    }

    nonisolated static func payloadSummary(from payload: [String: Any]) -> String {
        let sortedKeys = payload.keys.sorted()
        var parts = ["keys=\(sortedKeys.joined(separator: ","))"]
        appendString("window", from: payload, to: &parts)
        appendTarget(from: payload, to: &parts)
        appendString("role", from: payload, to: &parts)
        appendNumber("x", from: payload, to: &parts)
        appendNumber("y", from: payload, to: &parts)
        appendString("key", from: payload, to: &parts, limit: 32)
        if let text = payload["text"] as? String {
            parts.append("textLength=\(text.count)")
        }
        return parts.joined(separator: " ")
    }

    nonisolated static func errorSummary(_ error: Error) -> String {
        if let clientError = error as? ClickyComputerUseClientError {
            return redactTypedContent(clientError.errorDescription ?? String(describing: clientError))
        }
        return redactTypedContent(error.localizedDescription)
    }

    private nonisolated static func appendString(
        _ key: String,
        from payload: [String: Any],
        to parts: inout [String],
        limit: Int = 80
    ) {
        guard let value = payload[key] as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        parts.append("\(key)=\"\(short(value, limit: limit))\"")
    }

    private nonisolated static func appendNumber(
        _ key: String,
        from payload: [String: Any],
        to parts: inout [String]
    ) {
        guard let number = payload[key] as? NSNumber else { return }
        parts.append("\(key)=\(number)")
    }

    private nonisolated static func appendTarget(
        from payload: [String: Any],
        to parts: inout [String]
    ) {
        guard let target = payload["target"] as? [String: Any] else { return }
        let kind = (target["kind"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let value = target["value"] as? NSNumber

        switch (kind?.isEmpty == false ? kind : nil, value) {
        case let (.some(kind), .some(value)):
            parts.append("target=\(kind):\(value)")
        case let (.some(kind), nil):
            parts.append("target=\(kind)")
        case let (nil, .some(value)):
            parts.append("target=\(value)")
        default:
            parts.append("target=present")
        }
    }

    private nonisolated static func shortToken(_ token: String) -> String {
        guard token.count > 12 else { return token }
        return "\(token.prefix(6))...\(token.suffix(4))"
    }

    private nonisolated static func short(_ value: String, limit: Int = 160) -> String {
        let trimmed = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "..."
    }

    private nonisolated static func redactTypedContent(_ value: String) -> String {
        var redacted = value
        for key in ["text", "value"] {
            redacted = redacted.replacingOccurrences(
                of: #"("\#(key)"\s*:\s*")[^"]*(")"#,
                with: #"$1[REDACTED]$2"#,
                options: .regularExpression
            )
        }
        return redacted
    }
}

private extension ClickyComputerUseRiskLevel {
    var logValue: String {
        switch self {
        case .observe:
            return "observe"
        case .lowImpactAction:
            return "lowImpactAction"
        case .normalMutation:
            return "normalMutation"
        case .sensitiveHighImpact:
            return "sensitiveHighImpact"
        case .blocked:
            return "blocked"
        }
    }
}
