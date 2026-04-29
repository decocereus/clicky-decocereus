import Foundation

enum ClickyComputerUseRouteUtilities {
    nonisolated static func makeRouteDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let unixTimestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: unixTimestamp)
            }

            let value = try container.decode(String.self)
            let formatters: [ISO8601DateFormatter] = [
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter
                }(),
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime]
                    return formatter
                }(),
            ]

            for formatter in formatters {
                if let date = formatter.date(from: value) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO-8601 date string or UNIX timestamp."
            )
        }
        return decoder
    }
}
