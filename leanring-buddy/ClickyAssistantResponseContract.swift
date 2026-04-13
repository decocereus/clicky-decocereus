//
//  ClickyAssistantResponseContract.swift
//  leanring-buddy
//
//  Shared response envelope that every assistant backend should return.
//

import Foundation

enum ClickyAssistantPresentationMode: String, Codable, Sendable {
    case answer
    case point
    case walkthrough
    case tutorial
}

struct ClickyAssistantResponsePoint: Codable, Sendable {
    let x: Int
    let y: Int
    let label: String
    let bubbleText: String?
    let explanation: String?
    let screenNumber: Int?
}

struct ClickyAssistantStructuredResponse: Codable, Sendable {
    let mode: ClickyAssistantPresentationMode?
    let spokenText: String
    let points: [ClickyAssistantResponsePoint]
}

enum ClickyAssistantResponseContractError: LocalizedError {
    case invalidResponse(issues: [String], rawResponse: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let issues, _):
            if issues.isEmpty {
                return "assistant response did not match clicky's structured contract."
            }
            return "assistant response did not match clicky's structured contract: \(issues.joined(separator: "; "))"
        }
    }
}

enum ClickyAssistantResponseContract {
    static let promptInstructions = """
    response contract:
    - return exactly one json object and nothing else. no markdown, no prose outside json, no code fences.
    - this response contract overrides any conflicting formatting or prose-style instruction. the transport must be json. only spokenText should read like natural speech.
    - schema:
      {"mode":"answer|point|walkthrough|tutorial","spokenText":"string","points":[{"x":741,"y":213,"label":"gearshift","bubbleText":"gearshift","explanation":"the gearshift is down in the lower middle of the cabin.","screenNumber":1}]}
    - this json object is only the transport envelope. spokenText is what clicky speaks aloud, so that field should stay natural, useful, and formatted for the ear.
    - mode is optional. when present, it tells clicky whether this is a plain answer, one pointed item, a multi-point walkthrough, or a tutorial-style sequence.
    - points is an ordered array of things clicky should point at after or while speaking.
    - each point may include explanation. when present, clicky will speak that line while pointing at that specific target.
    - use an empty array for points when no pointing is needed.
    - every point object must use integer pixel coordinates in the screenshot's coordinate space.
    - label should be a short one to three word identifier.
    - bubbleText should be a very short on-screen cue, ideally one to four words, but still human-friendly and concrete. prefer phrases like "center screen", "climate panel", or "panoramic roof" over generic words like "screen" or "controls". if it is omitted or empty, clicky will fall back to label.
    - include screenNumber only when the point belongs to a different screen than the cursor's current screen.
    - if the user asks for a walkthrough, tour, breakdown, or overview of multiple visible things, include multiple ordered point objects and include explanation for each point so clicky can narrate in sync with the pointer.
    - if the user asks where a visible control, button, icon, or area is on screen, include at least one point object with real coordinates.
    - example with one point:
      {"mode":"point","spokenText":"here’s the gearshift.","points":[{"x":741,"y":213,"label":"gearshift","bubbleText":"gearshift","explanation":"the gearshift is down in the lower middle of the cabin, between the two front seats."}]}
    - example with multiple points:
      {"mode":"walkthrough","spokenText":"here are the main interior highlights.","points":[{"x":793,"y":320,"label":"instrument cluster","bubbleText":"speedometer","explanation":"the speedometer is behind the wheel in the hooded driver display."},{"x":920,"y":360,"label":"center display","bubbleText":"maps and media","explanation":"the center display handles maps, media, and vehicle settings."},{"x":930,"y":500,"label":"climate controls","bubbleText":"climate","explanation":"the climate controls sit below the vents and handle ac, temperature, and defogging."}]}
    """

    static func parse(
        rawResponse: String,
        requiresPoints: Bool
    ) throws -> ClickyAssistantStructuredResponse {
        let normalizedResponse = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        let issues: [String]

        guard let jsonString = extractJSONObjectString(from: normalizedResponse) else {
            issues = ["response was not a single json object"]
            throw ClickyAssistantResponseContractError.invalidResponse(issues: issues, rawResponse: rawResponse)
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            issues = ["response json could not be encoded as utf-8"]
            throw ClickyAssistantResponseContractError.invalidResponse(issues: issues, rawResponse: rawResponse)
        }

        let decoder = JSONDecoder()
        let decodedResponse: ClickyAssistantStructuredResponse
        do {
            decodedResponse = try decoder.decode(ClickyAssistantStructuredResponse.self, from: jsonData)
        } catch {
            let decodingIssue = "response json did not match the expected schema"
            throw ClickyAssistantResponseContractError.invalidResponse(
                issues: [decodingIssue],
                rawResponse: rawResponse
            )
        }

        let validationIssues = validate(decodedResponse, requiresPoints: requiresPoints)
        guard validationIssues.isEmpty else {
            throw ClickyAssistantResponseContractError.invalidResponse(
                issues: validationIssues,
                rawResponse: rawResponse
            )
        }

        return sanitize(decodedResponse)
    }

    private static func validate(
        _ response: ClickyAssistantStructuredResponse,
        requiresPoints: Bool
    ) -> [String] {
        var issues: [String] = []

        if response.spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("spokenText was empty")
        }

        if requiresPoints && response.points.isEmpty {
            issues.append("points array was empty even though the request required pointing")
        }

        switch response.mode {
        case .answer:
            if !response.points.isEmpty {
                issues.append("answer mode must not include points")
            }
        case .point:
            if response.points.count != 1 {
                issues.append("point mode must include exactly one point")
            }
        case .walkthrough:
            if response.points.count < 2 {
                issues.append("walkthrough mode must include at least two points")
            }
        case .tutorial:
            if response.points.isEmpty {
                issues.append("tutorial mode must include at least one point")
            }
        case .none:
            break
        }

        for (index, point) in response.points.enumerated() {
            if point.x < 0 || point.y < 0 {
                issues.append("point \(index + 1) had negative coordinates")
            }

            if point.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("point \(index + 1) had an empty label")
            }

            if let screenNumber = point.screenNumber, screenNumber < 1 {
                issues.append("point \(index + 1) had an invalid screenNumber")
            }
        }

        if let mode = response.mode, mode != .answer {
            for (index, point) in response.points.enumerated() {
                if (point.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty {
                    issues.append("point \(index + 1) was missing an explanation")
                }
            }
        }

        return issues
    }

    private static func sanitize(
        _ response: ClickyAssistantStructuredResponse
    ) -> ClickyAssistantStructuredResponse {
        ClickyAssistantStructuredResponse(
            mode: response.mode,
            spokenText: response.spokenText.trimmingCharacters(in: .whitespacesAndNewlines),
            points: response.points.map { point in
                ClickyAssistantResponsePoint(
                    x: point.x,
                    y: point.y,
                    label: point.label.trimmingCharacters(in: .whitespacesAndNewlines),
                    bubbleText: point.bubbleText?.trimmingCharacters(in: .whitespacesAndNewlines),
                    explanation: point.explanation?.trimmingCharacters(in: .whitespacesAndNewlines),
                    screenNumber: point.screenNumber
                )
            }
        )
    }

    private static func extractJSONObjectString(from rawResponse: String) -> String? {
        let trimmedResponse = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResponse.isEmpty else { return nil }

        if trimmedResponse.hasPrefix("```") {
            let lines = trimmedResponse.split(separator: "\n", omittingEmptySubsequences: false)
            if lines.count >= 3,
               let firstLine = lines.first,
               let lastLine = lines.last,
               firstLine.hasPrefix("```"),
               lastLine == "```" {
                return lines.dropFirst().dropLast().joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard trimmedResponse.first == "{",
              trimmedResponse.last == "}" else {
            return nil
        }

        return trimmedResponse
    }
}
