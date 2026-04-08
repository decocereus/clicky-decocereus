//
//  CompanionAgentBackend.swift
//  leanring-buddy
//
//  Shared backend selection for the companion response pipeline.
//

import Foundation

enum CompanionAgentBackend: String, CaseIterable {
    case claude
    case openClaw

    var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .openClaw:
            return "OpenClaw"
        }
    }
}
