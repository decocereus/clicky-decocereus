import Foundation

enum ClickyComputerUseClientError: LocalizedError {
    case runtimeNotReady
    case invalidResponse
    case invalidRequest(message: String)
    case routeFailed(statusCode: Int, bodyPreview: String)
    case decodingFailed(route: String, underlyingMessage: String, bodyPreview: String)

    var errorDescription: String? {
        switch self {
        case .runtimeNotReady:
            return "Clicky's computer-use runtime is not ready."
        case .invalidResponse:
            return "The computer-use runtime returned an invalid response."
        case .invalidRequest(let message):
            return message
        case .routeFailed(let statusCode, let bodyPreview):
            return "The computer-use runtime returned HTTP \(statusCode): \(bodyPreview)"
        case .decodingFailed(let route, let underlyingMessage, let bodyPreview):
            return "Clicky could not decode the computer-use \(route) response: \(underlyingMessage). Response preview: \(bodyPreview)"
        }
    }
}

struct ClickyComputerUseRouteResponse: Sendable {
    let statusCode: Int
    let body: Data

    var bodyText: String {
        String(data: body, encoding: .utf8) ?? ""
    }
}

@MainActor
final class ClickyComputerUseClient {
    private let baseURLProvider: () -> URL?
    private let urlSession: URLSession

    init(
        baseURLProvider: @escaping () -> URL?,
        urlSession: URLSession = .shared
    ) {
        self.baseURLProvider = baseURLProvider
        self.urlSession = urlSession
    }

    func health() async throws -> ClickyComputerUseRouteResponse {
        try await get("/health")
    }

    func bootstrap() async throws -> ClickyComputerUseRouteResponse {
        try await get("/v1/bootstrap")
    }

    func routes() async throws -> ClickyComputerUseRouteResponse {
        try await get("/v1/routes")
    }

    func listApps() async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/list_apps", body: [:])
    }

    func listWindows(app: String) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/list_windows", body: ["app": app])
    }

    func listWindows(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/list_windows", body: body)
    }

    func getWindowState(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/get_window_state", body: body)
    }

    func click(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/click", body: body)
    }

    func scroll(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/scroll", body: body)
    }

    func typeText(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/type_text", body: body)
    }

    func pressKey(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/press_key", body: body)
    }

    func setValue(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/set_value", body: body)
    }

    func performSecondaryAction(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/perform_secondary_action", body: body)
    }

    func drag(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/drag", body: body)
    }

    func resize(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/resize", body: body)
    }

    func setWindowFrame(_ body: [String: Any]) async throws -> ClickyComputerUseRouteResponse {
        try await post("/v1/set_window_frame", body: body)
    }

    private func get(_ path: String) async throws -> ClickyComputerUseRouteResponse {
        let request = try await makeRequest(path: path, method: "GET", body: nil)
        return try await execute(request)
    }

    private func post(
        _ path: String,
        body: [String: Any]
    ) async throws -> ClickyComputerUseRouteResponse {
        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        let request = try await makeRequest(path: path, method: "POST", body: data)
        return try await execute(request)
    }

    private func makeRequest(
        path: String,
        method: String,
        body: Data?
    ) async throws -> URLRequest {
        guard let baseURL = baseURLProvider() else {
            throw ClickyComputerUseClientError.runtimeNotReady
        }

        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func execute(_ request: URLRequest) async throws -> ClickyComputerUseRouteResponse {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClickyComputerUseClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClickyComputerUseClientError.routeFailed(
                statusCode: httpResponse.statusCode,
                bodyPreview: Self.bodyPreview(from: data)
            )
        }

        return ClickyComputerUseRouteResponse(
            statusCode: httpResponse.statusCode,
            body: data
        )
    }

    nonisolated static func bodyPreview(from data: Data) -> String {
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return "No response body." }
        if text.count <= 700 { return text }
        return String(text.prefix(700)) + "..."
    }
}
