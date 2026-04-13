//
//  ClickyBackendRoutingController.swift
//  leanring-buddy
//
//  Observable backend-routing status surface for Studio and the panel.
//

import Combine
import Foundation

@MainActor
final class ClickyBackendRoutingController: ObservableObject {
    @Published var openClawConnectionStatus: OpenClawConnectionStatus = .idle
    @Published var codexRuntimeStatus: CodexRuntimeStatus = .idle
    @Published var clickyShellRegistrationStatus: ClickyShellRegistrationStatus = .idle
    @Published var clickyShellServerFreshnessState: String?
    @Published var clickyShellServerStatusSummary: String?
    @Published var clickyShellServerSessionBindingState: String?
    @Published var clickyShellServerSessionKey: String?
    @Published var clickyShellServerTrustState: String?
    @Published var inferredOpenClawAgentIdentityAvatar: String?
    @Published var inferredOpenClawAgentIdentityName: String?
    @Published var inferredOpenClawAgentIdentityEmoji: String?
    @Published var inferredOpenClawAgentIdentifier: String?
    @Published var codexConfiguredModelName: String?
    @Published var codexExecutablePath: String?
    @Published var codexAuthModeLabel: String?
}
