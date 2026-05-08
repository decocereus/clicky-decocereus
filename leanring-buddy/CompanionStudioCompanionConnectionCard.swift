//
//  CompanionStudioCompanionConnectionCard.swift
//  leanring-buddy
//
//  Assistant connection and computer-use status card for the Companion Studio scene.
//

import SwiftUI

struct CompanionStudioCompanionConnectionCard: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var backendRoutingController: ClickyBackendRoutingController

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _backendRoutingController = ObservedObject(wrappedValue: companionManager.backendRoutingController)
    }

    private var selectedAgentBackend: CompanionAgentBackend {
        preferences.selectedAgentBackend
    }

    private var computerUsePermissionMode: ClickyComputerUsePermissionMode {
        preferences.clickyComputerUsePermissionMode
    }

    private var computerUseRuntimeStatus: ClickyComputerUseRuntimeStatus {
        backendRoutingController.computerUseRuntimeStatus
    }

    private var codexRuntimeStatus: CodexRuntimeStatus {
        backendRoutingController.codexRuntimeStatus
    }

    private var openClawConnectionStatus: OpenClawConnectionStatus {
        backendRoutingController.openClawConnectionStatus
    }

    private var effectiveOpenClawAgentName: String {
        let manualName = preferences.openClawAgentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manualName.isEmpty {
            return manualName
        }

        let inferredName = backendRoutingController.inferredOpenClawAgentIdentityName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !inferredName.isEmpty {
            return inferredName
        }

        return "your OpenClaw agent"
    }

    private var effectiveClickyPresentationName: String {
        if selectedAgentBackend != .openClaw {
            let overrideName = preferences.clickyPersonaOverrideName.trimmingCharacters(in: .whitespacesAndNewlines)
            return overrideName.isEmpty ? "Clicky" : overrideName
        }

        if preferences.clickyPersonaScopeMode == .overrideInClicky {
            let overrideName = preferences.clickyPersonaOverrideName.trimmingCharacters(in: .whitespacesAndNewlines)
            return overrideName.isEmpty ? "Clicky" : overrideName
        }

        return effectiveOpenClawAgentName
    }

    private var isOpenClawGatewayRemote: Bool {
        guard let gatewayURL = URL(string: preferences.openClawGatewayURL),
              let host = gatewayURL.host?.lowercased() else {
            return false
        }

        return gatewayURL.scheme == "wss"
            || !(host == "127.0.0.1" || host == "localhost" || host == "::1")
    }

    private var selectedAssistantModelIdentityLabel: String {
        switch selectedAgentBackend {
        case .claude:
            return preferences.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        case .codex:
            let configuredModel = backendRoutingController.codexConfiguredModelName?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return configuredModel.isEmpty ? "codex" : configuredModel
        case .openClaw:
            let configuredAgentIdentifier = preferences.openClawAgentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            if !configuredAgentIdentifier.isEmpty {
                return configuredAgentIdentifier
            }

            let inferredAgentIdentifier = backendRoutingController.inferredOpenClawAgentIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !inferredAgentIdentifier.isEmpty {
                return inferredAgentIdentifier
            }

            return effectiveOpenClawAgentName
        }
    }

    var body: some View {
        CompanionStudioReadableCard(
            eyebrow: "Connection",
            title: connectionCardTitle
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text(connectionSummaryCopy)
                    .font(ClickyTypography.body(size: 14))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    CompanionStudioGlassChip(text: connectionStatusChip)
                    ForEach(connectionSecondaryChips, id: \.self) { chip in
                        CompanionStudioGlassChip(text: chip)
                    }
                }

                VStack(spacing: 12) {
                    CompanionStudioKeyValueRow(label: "Assistant", value: effectiveClickyPresentationName)
                    ForEach(connectionDetailRows, id: \.label) { row in
                        CompanionStudioKeyValueRow(label: row.label, value: row.value)
                    }
                }

                connectionPrimaryAction

                computerUseStatusBlock
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var connectionCardTitle: String {
        switch selectedAgentBackend {
        case .claude:
            return "Assistant Connection"
        case .codex:
            return "Codex on This Mac"
        case .openClaw:
            return "Assistant Connection"
        }
    }

    private var connectionStatusChip: String {
        switch selectedAgentBackend {
        case .claude:
            return "Ready"
        case .codex:
            return codexRuntimeStatusLabel
        case .openClaw:
            switch openClawConnectionStatus {
            case .idle:
                return "Connection not checked yet"
            case .testing:
                return "Checking connection"
            case .connected:
                return "Connected"
            case .failed:
                return "Needs attention"
            }
        }
    }

    private var connectionSummaryCopy: String {
        switch selectedAgentBackend {
        case .claude:
            return "Claude runs through Clicky's cloud path, so you can keep the everyday companion feeling quick and polished while Studio handles the deeper setup."
        case .codex:
            return codexRuntimeSummaryCopy
        case .openClaw:
            switch openClawConnectionStatus {
            case .idle:
                return "Clicky is ready to connect through your chosen assistant path. Run a quick check any time you want to confirm everything is reachable."
            case .testing:
                return "Clicky is checking the connection right now."
            case .connected:
                return "Clicky can currently reach your assistant, so new conversations should go through without extra setup."
            case .failed:
                return "Clicky is having trouble reaching your assistant right now. A quick connection check can help you see whether anything needs attention."
            }
        }
    }

    private var connectionSecondaryChips: [String] {
        switch selectedAgentBackend {
        case .claude:
            return ["Cloud path"]
        case .codex:
            return codexReadinessChipLabels.filter { $0 != connectionStatusChip }
        case .openClaw:
            return [isOpenClawGatewayRemote ? "Remote gateway" : "Local gateway"]
        }
    }

    private var connectionDetailRows: [(label: String, value: String)] {
        switch selectedAgentBackend {
        case .claude:
            return [
                ("Route", "Clicky cloud"),
                ("Model", selectedAssistantModelIdentityLabel)
            ]
        case .codex:
            return [
                ("Account", codexAccountLabel),
                ("Model", codexConfiguredModelLabel),
                ("Location", "This Mac")
            ]
        case .openClaw:
            return [
                ("Gateway", isOpenClawGatewayRemote ? "Remote OpenClaw" : "This Mac"),
                ("Route", selectedAssistantModelIdentityLabel)
            ]
        }
    }

    @ViewBuilder
    private var connectionPrimaryAction: some View {
        switch selectedAgentBackend {
        case .claude:
            EmptyView()
        case .codex:
            HStack(spacing: 10) {
                Button {
                    companionManager.codexRuntimeCoordinator.refreshRuntimeStatus()
                } label: {
                    Label("Check Codex", systemImage: "bolt.horizontal.circle")
                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                        .frame(minWidth: 160)
                }
                .modifier(CompanionStudioPrimaryButtonModifier())
                .pointerCursor()

                if case .failed = codexRuntimeStatus {
                    Button {
                        if backendRoutingController.codexExecutablePath == nil {
                            companionManager.codexRuntimeCoordinator.openInstallPage()
                        } else {
                            companionManager.codexRuntimeCoordinator.startLoginInTerminal()
                        }
                    } label: {
                        Text(backendRoutingController.codexExecutablePath == nil ? "Install Codex" : "Sign In")
                            .frame(minWidth: 120)
                    }
                    .modifier(CompanionStudioSecondaryButtonModifier())
                    .pointerCursor()
                }
            }
        case .openClaw:
            Button {
                companionManager.openClawStudioCoordinator.testConnection()
            } label: {
                Label("Check Connection", systemImage: "bolt.horizontal.circle")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 170)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        }
    }

    private var codexRuntimeStatusLabel: String {
        switch codexRuntimeStatus {
        case .idle:
            return "Not checked yet"
        case .checking:
            return "Checking Codex"
        case .ready:
            return "Ready"
        case .failed:
            return "Needs setup"
        }
    }

    private var codexRuntimeSummaryCopy: String {
        switch codexRuntimeStatus {
        case .idle:
            return "Codex runs locally on this Mac and can use your ChatGPT subscription when it is signed in and ready."
        case .checking:
            return "Clicky is checking whether Codex is installed and signed in on this Mac."
        case let .ready(summary):
            return summary
        case let .failed(message):
            return message
        }
    }

    private var codexReadinessChipLabels: [String] {
        var labels = [codexRuntimeStatusLabel]

        if let authModeLabel = backendRoutingController.codexAuthModeLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !authModeLabel.isEmpty {
            labels.append(authModeLabel)
        }

        if let configuredModelName = backendRoutingController.codexConfiguredModelName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configuredModelName.isEmpty {
            labels.append(configuredModelName)
        }

        if labels.count == 1 {
            labels.append("Local runtime")
        }

        return labels
    }

    private var codexConfiguredModelLabel: String {
        backendRoutingController.codexConfiguredModelName ?? "Use Codex default"
    }

    private var codexAccountLabel: String {
        backendRoutingController.codexAuthModeLabel ?? "ChatGPT sign-in needed"
    }

    private var computerUseStatusBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Computer use")
                    .font(ClickyTypography.body(size: 14, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)

                Spacer(minLength: 0)

                Text(computerUseRuntimeStatusLabel)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardSecondaryText)
            }

            Text(computerUseRuntimeSummaryCopy)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                computerUseModeButton(title: "Off", isSelected: computerUsePermissionMode == .off) {
                    companionManager.settingsMutationCoordinator.setComputerUsePermissionMode(.off)
                }
                computerUseModeButton(title: "Observe", isSelected: computerUsePermissionMode == .observeOnly) {
                    companionManager.settingsMutationCoordinator.setComputerUsePermissionMode(.observeOnly)
                }
                computerUseModeButton(title: "Review", isSelected: computerUsePermissionMode == .review) {
                    companionManager.settingsMutationCoordinator.setComputerUsePermissionMode(.review)
                }
                computerUseModeButton(title: "Direct", isSelected: computerUsePermissionMode == .direct) {
                    companionManager.settingsMutationCoordinator.setComputerUsePermissionMode(.direct)
                }
            }

            if let reviewRequest = backendRoutingController.computerUsePendingReviewRequest {
                computerUseReviewCard(reviewRequest)
            }

            HStack(spacing: 8) {
                ForEach(computerUseReadinessChipLabels, id: \.self) { chip in
                    CompanionStudioGlassChip(text: chip)
                }
            }

            VStack(spacing: 10) {
                CompanionStudioKeyValueRow(label: "Command", value: computerUseLaunchCommandLabel)
                CompanionStudioKeyValueRow(label: "Working dir", value: computerUseWorkingDirectoryLabel)
            }

            Button {
                companionManager.computerUseMCPRuntimeCoordinator.refreshRuntimeStatus(permissionMode: computerUsePermissionMode)
            } label: {
                Label("Check Computer Use", systemImage: "desktopcomputer")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 170)
            }
            .modifier(CompanionStudioSecondaryButtonModifier())
            .pointerCursor()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardAccent.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }

    private var computerUseRuntimeStatusLabel: String {
        if computerUsePermissionMode == .off {
            return "Off"
        }

        switch computerUseRuntimeStatus {
        case .idle:
            return "Not checked yet"
        case .checking:
            return "Checking MCP"
        case .ready:
            return "MCP ready"
        case .failed:
            return "Needs setup"
        }
    }

    private var computerUseRuntimeSummaryCopy: String {
        if computerUsePermissionMode == .off {
            return "Clicky is not attaching desktop-control tools to model turns. The MCP helper can be checked, but providers cannot use it until you switch modes."
        }

        if computerUsePermissionMode == .observeOnly {
            switch computerUseRuntimeStatus {
            case .idle:
                return "Clicky will expose BackgroundComputerUse through an observe-only MCP proxy once the helper is available."
            case .checking:
                return "Clicky is checking the observe-only BackgroundComputerUse MCP path."
            case let .ready(summary):
                return "\(summary) Mutating desktop tools are blocked in Observe mode."
            case let .failed(message):
                return message
            }
        }

        if computerUsePermissionMode == .review {
            switch computerUseRuntimeStatus {
            case .idle:
                return "Clicky will expose BackgroundComputerUse through a review-gated MCP proxy once the helper is available."
            case .checking:
                return "Clicky is checking the review-gated BackgroundComputerUse MCP path."
            case let .ready(summary):
                return "\(summary) Mutating desktop tools pause here for approval before they run."
            case let .failed(message):
                return message
            }
        }

        switch computerUseRuntimeStatus {
        case .idle:
            return "Computer use is available through BackgroundComputerUse MCP once Clicky can locate the helper."
        case .checking:
            return "Clicky is checking the BackgroundComputerUse MCP helper."
        case let .ready(summary):
            return summary
        case let .failed(message):
            return message
        }
    }

    private var computerUseReadinessChipLabels: [String] {
        var labels = [computerUseRuntimeStatusLabel, "Mode: \(computerUsePermissionModeLabel)"]

        if computerUsePermissionMode == .off {
            return labels
        }

        labels.append("BackgroundComputerUse")

        if backendRoutingController.computerUseMCPInstructionResourceURI?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            labels.append("Instruction resource")
        }

        return labels
    }

    private var computerUsePermissionModeLabel: String {
        switch computerUsePermissionMode {
        case .off:
            return "Off"
        case .observeOnly:
            return "Observe"
        case .review:
            return "Review"
        case .direct:
            return "Direct"
        }
    }

    private var computerUseLaunchCommandLabel: String {
        guard let commandPath = backendRoutingController.computerUseMCPCommandPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !commandPath.isEmpty else {
            return "Not resolved"
        }

        let arguments = backendRoutingController.computerUseMCPArguments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return ([commandPath] + arguments).joined(separator: " ")
    }

    private var computerUseWorkingDirectoryLabel: String {
        let path = backendRoutingController.computerUseMCPWorkingDirectoryPath?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? "Bundled helper" : path
    }

    private func computerUseReviewCard(_ request: ClickyComputerUseReviewRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Approval needed")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)

                Spacer(minLength: 0)

                Text(request.toolName)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardSecondaryText)
            }

            if let createdAt = request.createdAt {
                Text("Requested \(createdAt.formatted(date: .omitted, time: .shortened))")
                    .font(ClickyTypography.body(size: 11))
                    .foregroundColor(palette.cardSecondaryText)
            }

            Text(request.argumentsSummary)
                .font(ClickyTypography.mono(size: 11))
                .foregroundColor(palette.cardSecondaryText)
                .lineLimit(5)
                .truncationMode(.tail)

            Text("Clicky will re-read the target window after approval and block the action if the state is stale.")
                .font(ClickyTypography.body(size: 11))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    companionManager.computerUseReviewCoordinator.denyCurrentRequest()
                } label: {
                    Label("Deny", systemImage: "xmark.circle")
                        .font(ClickyTypography.body(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .modifier(CompanionStudioSecondaryButtonModifier())
                .pointerCursor()

                Button {
                    companionManager.computerUseReviewCoordinator.approveCurrentRequest()
                } label: {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                        .font(ClickyTypography.body(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .modifier(CompanionStudioPrimaryButtonModifier())
                .pointerCursor()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.cardAccent.opacity(0.34))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.48), lineWidth: 0.8)
                )
        )
    }

    private func computerUseModeButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(ClickyTypography.body(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .modifier(CompanionStudioModeButtonModifier(isSelected: isSelected))
        .pointerCursor()
    }
}
