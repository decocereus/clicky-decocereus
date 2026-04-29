//
//  CompanionStudioNextView.swift
//  leanring-buddy
//
//  Parallel replacement Studio root with top tabs and scene-by-scene rebuilds.
//

import AppKit
import SwiftUI

enum CompanionStudioNextSection: String, CaseIterable, Identifiable, Hashable {
    case companion
    case profile
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .companion:
            return "Companion"
        case .profile:
            return "Profile"
        case .support:
            return "Support"
        }
    }

    var subtitle: String {
        switch self {
        case .companion:
            return "Daily shell controls"
        case .profile:
            return "Account, access, and app"
        case .support:
            return "Diagnostics and backstage tools"
        }
    }

    var systemImage: String {
        switch self {
        case .companion:
            return "sparkles"
        case .profile:
            return "person.crop.circle"
        case .support:
            return "stethoscope"
        }
    }
}

struct CompanionStudioNextView: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    @ObservedObject private var backendRoutingController: ClickyBackendRoutingController
    @ObservedObject private var surfaceController: ClickySurfaceController

    @AppStorage("clickySupportModeEnabled") private var isSupportModeEnabled = false
    @State private var selection: CompanionStudioNextSection = .companion

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
        _backendRoutingController = ObservedObject(wrappedValue: companionManager.backendRoutingController)
        _surfaceController = ObservedObject(wrappedValue: companionManager.surfaceController)
    }

    private var clickyLaunchBillingStatusLabel: String {
        switch launchAccessController.clickyLaunchBillingState {
        case .idle:
            return "Idle"
        case .openingCheckout:
            return "Opening checkout"
        case .waitingForCompletion:
            return "Waiting for purchase"
        case .canceled:
            return "Checkout canceled"
        case .completed:
            return "Checkout completed"
        case let .failed(message):
            return message
        }
    }

    private var clickyLaunchTrialStatusLabel: String {
        switch launchAccessController.clickyLaunchTrialState {
        case .inactive:
            return "Inactive"
        case let .active(remainingCredits):
            return "\(remainingCredits) credits left"
        case .armed:
            return "Paywall armed"
        case .paywalled:
            return "Paywall active"
        case .unlocked:
            return "Unlocked"
        case let .failed(message):
            return message
        }
    }

    private var isClickyLaunchSignedIn: Bool {
        if case .signedIn = launchAccessController.clickyLaunchAuthState {
            return true
        }

        return false
    }

    private var hasUnlimitedClickyLaunchAccess: Bool {
        if case .unlocked = launchAccessController.clickyLaunchTrialState {
            return true
        }

        return false
    }

    private var clickyLaunchDisplayName: String {
        let profileName = launchAccessController.clickyLaunchProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileName.isEmpty {
            return profileName
        }

        let fullUserName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullUserName.isEmpty {
            return fullUserName
        }

        guard case let .signedIn(email) = launchAccessController.clickyLaunchAuthState else {
            return "Clicky User"
        }

        let localPart = email.split(separator: "@").first.map(String.init) ?? ""
        let normalizedLocalPart = localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedLocalPart.isEmpty {
            return "Clicky User"
        }

        return normalizedLocalPart
            .split(separator: " ")
            .map { fragment in
                let lowercased = fragment.lowercased()
                return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }

    private var clickyLaunchDisplayInitials: String {
        let words = clickyLaunchDisplayName
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .map(String.init)

        if words.count >= 2 {
            return String(words.prefix(2).compactMap(\.first)).uppercased()
        }

        let compactName = clickyLaunchDisplayName.replacingOccurrences(of: " ", with: "")
        return String(compactName.prefix(2)).uppercased()
    }

    private var theme: ClickyTheme {
        preferences.clickyThemePreset.theme
    }

    private var allPermissionsGranted: Bool {
        surfaceController.hasAccessibilityPermission
            && surfaceController.hasScreenRecordingPermission
            && surfaceController.hasMicrophonePermission
            && surfaceController.hasScreenContentPermission
    }

    private var launchAccess: CompanionStudioLaunchAccessSnapshot {
        CompanionStudioLaunchAccessSnapshot(
            authState: launchAccessController.clickyLaunchAuthState,
            billingState: launchAccessController.clickyLaunchBillingState,
            trialState: launchAccessController.clickyLaunchTrialState,
            profileName: launchAccessController.clickyLaunchProfileName,
            profileImageURL: launchAccessController.clickyLaunchProfileImageURL,
            hasCompletedOnboarding: preferences.hasCompletedOnboarding,
            hasAccessibilityPermission: surfaceController.hasAccessibilityPermission,
            hasScreenRecordingPermission: surfaceController.hasScreenRecordingPermission,
            hasMicrophonePermission: surfaceController.hasMicrophonePermission,
            hasScreenContentPermission: surfaceController.hasScreenContentPermission
        )
    }

    private var isClickyLaunchAuthPending: Bool {
        switch launchAccessController.clickyLaunchAuthState {
        case .restoring, .signingIn:
            return true
        case .signedOut, .signedIn, .failed:
            return false
        }
    }

    private var isClickyLaunchPaywallActive: Bool {
        if let storedSession = ClickyAuthSessionStore.load() {
            return !storedSession.entitlement.hasAccess && storedSession.trial?.status == "paywalled"
        }

        if case .paywalled = launchAccessController.clickyLaunchTrialState {
            return true
        }

        return false
    }

    private var requiresLaunchSignInForCompanionUse: Bool {
        guard preferences.hasCompletedOnboarding && allPermissionsGranted else {
            return false
        }

        if isClickyLaunchPaywallActive {
            return false
        }

        switch launchAccessController.clickyLaunchAuthState {
        case .signedOut, .failed:
            return true
        case .restoring, .signingIn, .signedIn:
            return false
        }
    }

    private var clickyLaunchAuthStatusLabel: String {
        switch launchAccessController.clickyLaunchAuthState {
        case .signedOut:
            return "Signed out"
        case .restoring:
            return "Restoring session"
        case .signingIn:
            return "Waiting for browser sign-in"
        case let .signedIn(email):
            return email
        case let .failed(message):
            return message
        }
    }

    private var availableSections: [CompanionStudioNextSection] {
        CompanionStudioNextSection.allCases.filter { section in
            if section == .support {
                return isSupportModeEnabled
            }
            return true
        }
    }

    private var isLaunchAuthGateActive: Bool {
        launchAccess.requiresSignInForCompanionUse || isClickyLaunchAuthPending
    }

    var body: some View {
        ZStack {
            CompanionStudioNextBackdrop(theme: theme, palette: palette)

            VStack(alignment: .leading, spacing: 18) {
                CompanionStudioWindowHeader(
                    theme: theme,
                    palette: palette,
                    sections: availableSections,
                    selection: $selection,
                    showsSectionTabs: !isLaunchAuthGateActive
                )

                CompanionStudioSceneShell {
                    currentScene
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 22)
            .padding(.bottom, 12)
            .background(outerShell)
        }
        .modifier(CompanionStudioNextWindowBackgroundClearStyle())
        .background(CompanionStudioNextWindowConfigurator())
        .onChange(of: isSupportModeEnabled) { _, newValue in
            if !newValue && selection == .support {
                selection = .companion
            }
        }
    }

    @ViewBuilder
    private var currentScene: some View {
        if isLaunchAuthGateActive {
            CompanionStudioLaunchAuthScene(companionManager: companionManager)
        } else {
            switch selection {
            case .companion:
                CompanionStudioCompanionScene(
                    companionManager: companionManager,
                    isSupportModeEnabled: $isSupportModeEnabled
                )
            case .profile:
                CompanionStudioProfileScene(companionManager: companionManager)
            case .support:
                CompanionStudioSupportScene(
                    companionManager: companionManager,
                    isSupportModeEnabled: $isSupportModeEnabled
                )
            }
        }
    }

    @ViewBuilder
    private var outerShell: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

        if #available(macOS 26.0, *) {
            Color.clear
                .padding(12)
                .glassEffect(.clear, in: shape)
                .overlay(
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.10),
                                    palette.sage.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.10), radius: 18, y: 8)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.fill(Color.white.opacity(0.06))
                )
                .overlay(
                    shape.stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        }
    }
}

private struct CompanionStudioLaunchAuthScene: View {
    let companionManager: CompanionManager
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
    }

    private var clickyLaunchAuthState: ClickyLaunchAuthState {
        launchAccessController.clickyLaunchAuthState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CompanionStudioReadableCard(
                eyebrow: "Welcome",
                title: launchGateTitle
            ) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(launchGateCopy)
                                .font(ClickyTypography.body(size: 15))
                                .foregroundColor(palette.cardSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                ForEach(launchGateChips, id: \.self) { chip in
                                    CompanionStudioGlassChip(text: chip)
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        CompanionStudioAccessAvatar(
                            initials: "CL",
                            imageURL: "",
                            palette: palette
                        )
                    }

                    CompanionStudioHairline()

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            launchMomentCard(
                                eyebrow: "01",
                                title: "Sign in once",
                                copy: "Tie your Clicky taste, purchase state, and restore flow to your account."
                            )
                            launchMomentCard(
                                eyebrow: "02",
                                title: "Let Studio settle",
                                copy: "Clicky quietly restores and refreshes access in the background as soon as the app loads."
                            )
                            launchMomentCard(
                                eyebrow: "03",
                                title: "Drop into work",
                                copy: "Once auth is ready, the normal Studio surfaces take over and the companion is ready to help."
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            launchMomentCard(
                                eyebrow: "01",
                                title: "Sign in once",
                                copy: "Tie your Clicky taste, purchase state, and restore flow to your account."
                            )
                            launchMomentCard(
                                eyebrow: "02",
                                title: "Let Studio settle",
                                copy: "Clicky quietly restores and refreshes access in the background as soon as the app loads."
                            )
                            launchMomentCard(
                                eyebrow: "03",
                                title: "Drop into work",
                                copy: "Once auth is ready, the normal Studio surfaces take over and the companion is ready to help."
                            )
                        }
                    }

                    launchGateAction
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .topLeading)
    }

    private var launchGateTitle: String {
        switch clickyLaunchAuthState {
        case .restoring:
            return "Loading Your Studio"
        case .signingIn:
            return "Finishing Sign-In"
        case .failed:
            return "Sign In To Continue"
        case .signedOut:
            return "Start With Your Account"
        case .signedIn:
            return "Loading Your Studio"
        }
    }

    private var launchGateCopy: String {
        switch clickyLaunchAuthState {
        case .restoring:
            return "Clicky is restoring your session and checking access in the background so Studio can open in the right state."
        case .signingIn:
            return "Your browser sign-in is in flight. As soon as the callback lands, Studio will switch over to your normal account and access view."
        case .failed(let message):
            return "Clicky couldn’t finish signing you in yet. Start the sign-in again from here and Studio will continue as soon as your account is connected. \(message)"
        case .signedOut:
            return "Sign in to make Clicky yours on this Mac. That gives the app a real account home for your included taste, purchase state, and future restores."
        case .signedIn:
            return "Clicky is getting Studio ready."
        }
    }

    private var launchGateChips: [String] {
        switch clickyLaunchAuthState {
        case .restoring:
            return ["Restoring session", "Checking access"]
        case .signingIn:
            return ["Waiting for browser sign-in"]
        case .failed:
            return ["Sign-in needs attention"]
        case .signedOut:
            return ["Account required"]
        case .signedIn:
            return ["Loading"]
        }
    }

    @ViewBuilder
    private var launchGateAction: some View {
        switch clickyLaunchAuthState {
        case .restoring, .signingIn:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(clickyLaunchAuthState == .restoring ? "Restoring your Clicky session..." : "Waiting for the browser to hand auth back...")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
            }
            .padding(.vertical, 6)
        case .signedOut, .failed:
            Button {
                companionManager.startClickyLaunchSignIn()
            } label: {
                Label("Continue With Google", systemImage: "person.crop.circle.badge.plus")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 200)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        case .signedIn:
            EmptyView()
        }
    }

    private func launchMomentCard(eyebrow: String, title: String, copy: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(title)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)

            Text(copy)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardAccent.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }
}

private struct CompanionStudioCompanionScene: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    @ObservedObject private var backendRoutingController: ClickyBackendRoutingController
    @ObservedObject private var surfaceController: ClickySurfaceController
    @Binding var isSupportModeEnabled: Bool

    @Environment(\.clickyTheme) private var theme
    @State private var isPersonaPopoverPresented = false
    @State private var isVoicePopoverPresented = false
    @State private var isThemePopoverPresented = false
    @State private var isCursorPopoverPresented = false
    @State private var isProviderPanelExpanded = false
    @State private var isAdvancedToneExpanded = false
    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager, isSupportModeEnabled: Binding<Bool>) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
        _backendRoutingController = ObservedObject(wrappedValue: companionManager.backendRoutingController)
        _surfaceController = ObservedObject(wrappedValue: companionManager.surfaceController)
        _isSupportModeEnabled = isSupportModeEnabled
    }

    private var selectedAgentBackend: CompanionAgentBackend {
        preferences.selectedAgentBackend
    }

    private var clickyPersonaPreset: ClickyPersonaPreset {
        preferences.clickyPersonaPreset
    }

    private var clickyVoicePreset: ClickyVoicePreset {
        preferences.clickyVoicePreset
    }

    private var clickySpeechProviderMode: ClickySpeechProviderMode {
        preferences.clickySpeechProviderMode
    }

    private var clickyThemePreset: ClickyThemePreset {
        preferences.clickyThemePreset
    }

    private var clickyCursorStyle: ClickyCursorStyle {
        preferences.clickyCursorStyle
    }

    private var isClickyCursorEnabled: Bool {
        preferences.isClickyCursorEnabled
    }

    private var activeClickyPersonaSummary: String {
        preferences.clickyPersonaPreset.definition.summary
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

    private var effectiveVoiceOutputDisplayName: String {
        switch clickySpeechProviderMode {
        case .system:
            return "System Speech · \(clickyVoicePreset.displayName)"
        case .elevenLabsBYO:
            let label = preferences.elevenLabsSelectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
            return "ElevenLabs · \(label.isEmpty ? "No voice selected" : label)"
        }
    }

    private var codexRuntimeStatus: CodexRuntimeStatus {
        backendRoutingController.codexRuntimeStatus
    }

    private var openClawConnectionStatus: OpenClawConnectionStatus {
        backendRoutingController.openClawConnectionStatus
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

    private var launchAccess: CompanionStudioLaunchAccessSnapshot {
        CompanionStudioLaunchAccessSnapshot(
            authState: launchAccessController.clickyLaunchAuthState,
            billingState: launchAccessController.clickyLaunchBillingState,
            trialState: launchAccessController.clickyLaunchTrialState,
            profileName: launchAccessController.clickyLaunchProfileName,
            profileImageURL: launchAccessController.clickyLaunchProfileImageURL,
            hasCompletedOnboarding: preferences.hasCompletedOnboarding,
            hasAccessibilityPermission: surfaceController.hasAccessibilityPermission,
            hasScreenRecordingPermission: surfaceController.hasScreenRecordingPermission,
            hasMicrophonePermission: surfaceController.hasMicrophonePermission,
            hasScreenContentPermission: surfaceController.hasScreenContentPermission
        )
    }

    private var clickyLaunchBillingStatusLabel: String {
        switch launchAccessController.clickyLaunchBillingState {
        case .idle:
            return "Idle"
        case .openingCheckout:
            return "Opening checkout"
        case .waitingForCompletion:
            return "Waiting for purchase"
        case .canceled:
            return "Checkout canceled"
        case .completed:
            return "Checkout completed"
        case let .failed(message):
            return message
        }
    }

    private var clickyLaunchTrialStatusLabel: String {
        switch launchAccessController.clickyLaunchTrialState {
        case .inactive:
            return "Inactive"
        case let .active(remainingCredits):
            return "\(remainingCredits) credits left"
        case .armed:
            return "Paywall armed"
        case .paywalled:
            return "Paywall active"
        case .unlocked:
            return "Unlocked"
        case let .failed(message):
            return message
        }
    }

    private var isClickyLaunchSignedIn: Bool {
        if case .signedIn = launchAccessController.clickyLaunchAuthState {
            return true
        }

        return false
    }

    private var hasUnlimitedClickyLaunchAccess: Bool {
        if case .unlocked = launchAccessController.clickyLaunchTrialState {
            return true
        }

        return false
    }

    private var clickyLaunchDisplayName: String {
        let profileName = launchAccessController.clickyLaunchProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileName.isEmpty {
            return profileName
        }

        let fullUserName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullUserName.isEmpty {
            return fullUserName
        }

        guard case let .signedIn(email) = launchAccessController.clickyLaunchAuthState else {
            return "Clicky User"
        }

        let localPart = email.split(separator: "@").first.map(String.init) ?? ""
        let normalizedLocalPart = localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedLocalPart.isEmpty {
            return "Clicky User"
        }

        return normalizedLocalPart
            .split(separator: " ")
            .map { fragment in
                let lowercased = fragment.lowercased()
                return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }

    private var clickyLaunchDisplayInitials: String {
        let words = clickyLaunchDisplayName
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .map(String.init)

        if words.count >= 2 {
            return String(words.prefix(2).compactMap(\.first)).uppercased()
        }

        let compactName = clickyLaunchDisplayName.replacingOccurrences(of: " ", with: "")
        return String(compactName.prefix(2)).uppercased()
    }

    private var isClickyLaunchPaywallActive: Bool {
        if let storedSession = ClickyAuthSessionStore.load() {
            return !storedSession.entitlement.hasAccess && storedSession.trial?.status == "paywalled"
        }

        if case .paywalled = launchAccessController.clickyLaunchTrialState {
            return true
        }

        return false
    }

    private var requiresLaunchSignInForCompanionUse: Bool {
        let allPermissionsGranted = surfaceController.hasAccessibilityPermission
            && surfaceController.hasScreenRecordingPermission
            && surfaceController.hasMicrophonePermission
            && surfaceController.hasScreenContentPermission

        guard preferences.hasCompletedOnboarding && allPermissionsGranted else {
            return false
        }

        if isClickyLaunchPaywallActive {
            return false
        }

        switch launchAccessController.clickyLaunchAuthState {
        case .signedOut, .failed:
            return true
        case .restoring, .signingIn, .signedIn:
            return false
        }
    }

    private var clickyLaunchAuthStatusLabel: String {
        switch launchAccessController.clickyLaunchAuthState {
        case .signedOut:
            return "Signed out"
        case .restoring:
            return "Restoring session"
        case .signingIn:
            return "Waiting for browser sign-in"
        case let .signedIn(email):
            return email
        case let .failed(message):
            return message
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            hero

            journeyCard

            personalizeCard

            HStack(alignment: .top, spacing: 18) {
                connectionSummaryCard
                accessSummaryCard
            }
        }
    }

    private var hero: some View {
        CompanionStudioReadableCard(
            eyebrow: "Companion",
            title: "Your Everyday Copilot"
        ) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Clicky stays out of your way until you need it, then listens, thinks, speaks back, and helps point you in the right direction.")
                    .font(ClickyTypography.body(size: 14))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 14) {
                        openPanelButton

                        Text("Open the floating companion when you want the fastest way to talk to Clicky.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        openPanelButton

                        Text("Open the floating companion when you want the fastest way to talk to Clicky.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                    }
                }

                CompanionStudioHairline()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) {
                        heroSignalColumn(
                            title: "Assistant",
                            value: effectiveClickyPresentationName,
                            detail: assistantModeDetail
                        )
                        heroSignalColumn(
                            title: "Voice",
                            value: effectiveVoiceOutputDisplayName,
                            detail: clickyVoicePreset.displayName
                        )
                        heroSignalColumn(
                            title: "Guidance",
                            value: isClickyCursorEnabled ? "Pointer guidance on" : "Pointer guidance off",
                            detail: "Screen help when needed"
                        )
                    }

                    VStack(spacing: 12) {
                        heroSignalStack(
                            title: "Assistant",
                            value: effectiveClickyPresentationName,
                            detail: assistantModeDetail
                        )
                        heroSignalStack(
                            title: "Voice",
                            value: effectiveVoiceOutputDisplayName,
                            detail: clickyVoicePreset.displayName
                        )
                        heroSignalStack(
                            title: "Guidance",
                            value: isClickyCursorEnabled ? "Pointer guidance on" : "Pointer guidance off",
                            detail: "Screen help when needed"
                        )
                    }
                }
            }
        }
    }

    private var openPanelButton: some View {
        Button {
            NotificationCenter.default.post(name: .clickyShowPanel, object: nil)
        } label: {
            Label("Open Companion Panel", systemImage: "sparkles")
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .frame(minWidth: 180)
        }
        .modifier(CompanionStudioPrimaryButtonModifier())
        .pointerCursor()
    }

    private func heroSignalColumn(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(value)
                .font(ClickyTypography.section(size: 22))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private func heroSignalStack(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(value)
                .font(ClickyTypography.body(size: 16, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(2)
                .truncationMode(.tail)
                .minimumScaleFactor(0.90)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardAccent.opacity(0.40))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }

    private var journeyCard: some View {
        CompanionStudioReadableCard(
            eyebrow: "Flow",
            title: "How A Clicky Moment Works"
        ) {
            HStack(alignment: .top, spacing: 14) {
                CompanionStudioJourneyStep(
                    step: "01",
                    title: "Hold the shortcut",
                    copy: "Clicky starts listening the moment you hold Control + Option."
                )
                CompanionStudioJourneyStep(
                    step: "02",
                    title: "Ask naturally",
                    copy: "Say what you want help with in plain language, without opening a settings page first."
                )
                CompanionStudioJourneyStep(
                    step: "03",
                    title: "Get a spoken answer",
                    copy: "Clicky replies in your selected voice and can point at things on screen when it helps."
                )
            }
        }
    }

    private var personalizeCard: some View {
        CompanionStudioReadableCard(
            eyebrow: "Personalize",
            title: "Change The Feel"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Make the two or three changes most people reach for first: how Clicky answers, whether it points things out on screen, and the style it uses.")
                    .font(ClickyTypography.body(size: 14))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        CompanionStudioPreferenceBlock(
                            title: "Assistant mode",
                            subtitle: "Choose whether Clicky replies through Claude, Codex on this Mac, or your OpenClaw setup.",
                            content: AnyView(
                                HStack(spacing: 10) {
                                    assistantModeButton(
                                        title: "Claude",
                                        isSelected: selectedAgentBackend == .claude
                                    ) {
                                        companionManager.setSelectedAgentBackend(.claude)
                                    }

                                    assistantModeButton(
                                        title: "Codex",
                                        isSelected: selectedAgentBackend == .codex
                                    ) {
                                        companionManager.setSelectedAgentBackend(.codex)
                                    }

                                    assistantModeButton(
                                        title: "OpenClaw",
                                        isSelected: selectedAgentBackend == .openClaw
                                    ) {
                                        companionManager.setSelectedAgentBackend(.openClaw)
                                    }
                                }
                            )
                        )

                        if selectedAgentBackend == .codex {
                            CompanionStudioPreferenceBlock(
                                title: "Codex on this Mac",
                                subtitle: "Clicky uses your local Codex install directly, keeping the interaction simple and fully inside Clicky.",
                                content: AnyView(
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("No extra thread or project setup is needed here anymore. Once Codex is installed and signed in, Clicky can route answers through it like any other backend.")
                                            .font(.caption)
                                            .foregroundColor(palette.cardSecondaryText)
                                            .fixedSize(horizontal: false, vertical: true)

                                        HStack(spacing: 8) {
                                            CompanionStudioGlassChip(text: "Local runtime")
                                            CompanionStudioGlassChip(text: "ChatGPT subscription")
                                        }
                                    }
                                )
                            )
                        }

                        CompanionStudioPreferenceRow(
                            title: "Pointer guidance",
                            subtitle: "Let Clicky point to things on screen when that makes the answer easier to follow.",
                            control: AnyView(
                                CompanionStudioPointerGuidanceToggle(
                                    preferences: preferences,
                                    onSetClickyCursorEnabled: companionManager.setClickyCursorEnabled,
                                    theme: theme
                                )
                            )
                        )

                        CompanionStudioPreferenceRow(
                            title: "Support tools",
                            subtitle: "Keep the backstage tools hidden unless you are intentionally troubleshooting.",
                            control: AnyView(
                                Toggle("Enable support mode", isOn: $isSupportModeEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .tint(theme.accent)
                            )
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Current style")
                            .font(ClickyTypography.mono(size: 11, weight: .semibold))
                            .foregroundColor(palette.cardSecondaryText)
                            .tracking(0.8)

                        Text(activeClickyPersonaSummary)
                            .font(ClickyTypography.body(size: 14, weight: .medium))
                            .foregroundColor(palette.cardPrimaryText)
                            .lineLimit(3)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: 72, alignment: .topLeading)

                        ViewThatFits(in: .horizontal) {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    personaPresetButton
                                    voicePresetButton
                                }
                                HStack(spacing: 12) {
                                    themePresetButton
                                    cursorPresetButton
                                }
                                providerButton
                            }

                            VStack(spacing: 12) {
                                personaPresetButton
                                voicePresetButton
                                themePresetButton
                                cursorPresetButton
                                providerButton
                            }
                        }

                        if isProviderPanelExpanded {
                            CompanionStudioProviderPopover(companionManager: companionManager)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                isAdvancedToneExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isAdvancedToneExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Advanced tone notes")
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                            }
                            .foregroundColor(palette.cardPrimaryText)
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()

                        if isAdvancedToneExpanded {
                            CompanionStudioAdvancedToneEditor(
                                preferences: preferences,
                                palette: palette
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
    }

    private func assistantModeButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .modifier(CompanionStudioModeButtonModifier(isSelected: isSelected))
        .pointerCursor()
    }

    private var voicePresetButton: some View {
        Button {
            isVoicePopoverPresented.toggle()
        } label: {
            CompanionStudioMiniMetric(
                title: "Voice",
                value: clickyVoicePreset.displayName,
                allowExpansion: true
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .popover(isPresented: $isVoicePopoverPresented, arrowEdge: .bottom) {
            CompanionStudioVoicePresetPopover(companionManager: companionManager)
                .frame(width: 360, height: 300)
        }
    }

    private var personaPresetButton: some View {
        Button {
            isPersonaPopoverPresented.toggle()
        } label: {
            CompanionStudioMiniMetric(
                title: "Persona",
                value: clickyPersonaPreset.definition.displayName,
                allowExpansion: true
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .popover(isPresented: $isPersonaPopoverPresented, arrowEdge: .bottom) {
            CompanionStudioPersonaPresetPopover(companionManager: companionManager)
                .frame(width: 360, height: 340)
        }
    }

    private var themePresetButton: some View {
        Button {
            isThemePopoverPresented.toggle()
        } label: {
            CompanionStudioMiniMetric(
                title: "Theme",
                value: clickyThemePreset.displayName,
                allowExpansion: true
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .popover(isPresented: $isThemePopoverPresented, arrowEdge: .bottom) {
            CompanionStudioThemePresetPopover(companionManager: companionManager)
                .frame(width: 360, height: 300)
        }
    }

    private var cursorPresetButton: some View {
        Button {
            isCursorPopoverPresented.toggle()
        } label: {
            CompanionStudioMiniMetric(
                title: "Cursor",
                value: clickyCursorStyle.displayName,
                allowExpansion: true
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .popover(isPresented: $isCursorPopoverPresented, arrowEdge: .bottom) {
            CompanionStudioCursorPresetPopover(companionManager: companionManager)
                .frame(width: 360, height: 300)
        }
    }

    private var providerButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                isProviderPanelExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                CompanionStudioMiniMetric(
                    title: "Provider",
                    value: clickySpeechProviderMode.displayName,
                    allowExpansion: true
                )

                HStack(spacing: 6) {
                    Image(systemName: isProviderPanelExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isProviderPanelExpanded ? "Hide voice library" : "Show voice library")
                        .font(.caption)
                        .foregroundColor(palette.cardSecondaryText)
                }
                .padding(.leading, 4)
            }
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private var connectionSummaryCard: some View {
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var accessSummaryCard: some View {
        CompanionStudioReadableCard(
            eyebrow: "Access",
            title: "Your Access"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                accessAccountHeader

                if launchAccess.hasUnlimitedAccess {
                    CompanionStudioAccessCelebrationCard()
                } else {
                    Text(accessSummaryCopy)
                        .font(ClickyTypography.body(size: 14))
                        .foregroundColor(palette.cardSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    ForEach(accessChipLabels, id: \.self) { label in
                        CompanionStudioGlassChip(text: label)
                    }
                }

                VStack(spacing: 12) {
                    CompanionStudioKeyValueRow(label: "Account", value: launchAccess.displayName)

                    if !launchAccess.hasUnlimitedAccess {
                        if launchAccess.isSignedIn {
                            CompanionStudioKeyValueRow(label: "Access", value: accessStatusLine)
                        }

                        if showsTrialRow {
                            CompanionStudioKeyValueRow(label: "Trial", value: launchAccess.trialStatusLabel)
                        }

                        if showsCheckoutRow {
                            CompanionStudioKeyValueRow(label: "Checkout", value: launchAccess.billingStatusLabel)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    accessPrimaryAction
                    accessSecondaryActions
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task(id: accessBackgroundSyncToken) {
            guard launchAccess.isSignedIn else {
                return
            }

            companionManager.refreshClickyLaunchEntitlementQuietlyIfNeeded(
                reason: "studio-access-card",
                minimumInterval: 15
            )
        }
    }

    private var assistantModeDetail: String {
        switch selectedAgentBackend {
        case .claude:
            return "Cloud companion"
        case .codex:
            return "Local Codex companion"
        case .openClaw:
            return "OpenClaw companion"
        }
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
                    companionManager.refreshCodexRuntimeStatus()
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
                            companionManager.openCodexInstallPage()
                        } else {
                            companionManager.startCodexLoginInTerminal()
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
                companionManager.testOpenClawConnection()
            } label: {
                Label("Check Connection", systemImage: "bolt.horizontal.circle")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 170)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        }
    }

    private var accessSummaryCopy: String {
        if launchAccess.hasUnlimitedAccess {
            return "Your subscription is live. Clicky is fully unlocked here, so you can talk to it as much as you want."
        }

        if launchAccess.requiresSignInForCompanionUse {
            return "Sign in to start your Clicky trial and keep your access tied to your account."
        }

        if launchAccess.isPaywallActive {
            return "Your included taste is finished. Unlock Clicky to keep the companion with you across as many turns as you want."
        }

        if launchAccess.billingStatusLabel == "Waiting for purchase" {
            return "Clicky is checking your purchase in the background so this Mac can unlock itself as soon as it lands."
        }

        return "Your account is in good shape, and Clicky is quietly keeping your access up to date on this Mac."
    }

    private var accessAccountHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            CompanionStudioAccessAvatar(
                initials: launchAccess.displayInitials,
                imageURL: launchAccessController.clickyLaunchProfileImageURL,
                palette: palette
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(launchAccess.displayName)
                    .font(ClickyTypography.section(size: 24))
                    .foregroundColor(palette.cardPrimaryText)
                    .lineLimit(1)

                Text(accessHeaderSubtitle)
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var accessHeaderSubtitle: String {
        if launchAccess.hasUnlimitedAccess {
            return "You’re fully unlocked on this Mac."
        }

        if launchAccess.requiresSignInForCompanionUse {
            return "Sign in once to tie your trial and future access to your account."
        }

        if launchAccess.isPaywallActive {
            return "Your trial has wrapped, but this is where Clicky can unlock for good."
        }

        return "Clicky keeps this Mac in sync with your access in the background."
    }

    private var accessChipLabels: [String] {
        if launchAccess.hasUnlimitedAccess {
            return ["Subscription active", "Unlimited access"]
        }

        if launchAccess.requiresSignInForCompanionUse {
            return ["Sign in required"]
        }

        if launchAccess.isPaywallActive {
            return ["Trial finished", "Unlock available"]
        }

        if launchAccess.billingStatusLabel == "Waiting for purchase" {
            return ["Finishing purchase"]
        }

        return ["Ready on this Mac"]
    }

    private var accessStatusLine: String {
        if launchAccess.isPaywallActive {
            return "Needs unlock"
        }

        if launchAccess.billingStatusLabel == "Waiting for purchase" {
            return "Checking purchase"
        }

        return "Ready to use"
    }

    private var showsTrialRow: Bool {
        !launchAccess.hasUnlimitedAccess
    }

    private var showsCheckoutRow: Bool {
        !launchAccess.hasUnlimitedAccess
            && launchAccess.isSignedIn
            && launchAccess.billingStatusLabel != "Idle"
    }

    private var accessBackgroundSyncToken: String {
        [
            launchAccess.authStatusLabel,
            launchAccess.billingStatusLabel,
            launchAccess.trialStatusLabel
        ].joined(separator: "|")
    }

    @ViewBuilder
    private var accessPrimaryAction: some View {
        if launchAccess.requiresSignInForCompanionUse {
            Button {
                companionManager.startClickyLaunchSignIn()
            } label: {
                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 150)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        } else if launchAccess.isPaywallActive {
            Button {
                companionManager.startClickyLaunchCheckout()
            } label: {
                Label("Unlock Clicky", systemImage: "creditcard")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 150)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        }
    }

    @ViewBuilder
    private var accessSecondaryActions: some View {
        if launchAccess.isSignedIn {
            Button {
                companionManager.signOutClickyLaunchSession()
            } label: {
                Text("Sign Out")
                    .font(ClickyTypography.body(size: 12, weight: .semibold))
                    .foregroundColor(palette.cardSecondaryText)
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
    }

}

private struct CompanionStudioProfileScene: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    @ObservedObject private var backendRoutingController: ClickyBackendRoutingController
    @ObservedObject private var surfaceController: ClickySurfaceController
    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
        _backendRoutingController = ObservedObject(wrappedValue: companionManager.backendRoutingController)
        _surfaceController = ObservedObject(wrappedValue: companionManager.surfaceController)
    }

    private var clickyLaunchBillingStatusLabel: String {
        switch launchAccessController.clickyLaunchBillingState {
        case .idle:
            return "Idle"
        case .openingCheckout:
            return "Opening checkout"
        case .waitingForCompletion:
            return "Waiting for purchase"
        case .canceled:
            return "Checkout canceled"
        case .completed:
            return "Checkout completed"
        case let .failed(message):
            return message
        }
    }

    private var clickyLaunchTrialStatusLabel: String {
        switch launchAccessController.clickyLaunchTrialState {
        case .inactive:
            return "Inactive"
        case let .active(remainingCredits):
            return "\(remainingCredits) credits left"
        case .armed:
            return "Paywall armed"
        case .paywalled:
            return "Paywall active"
        case .unlocked:
            return "Unlocked"
        case let .failed(message):
            return message
        }
    }

    private var isClickyLaunchSignedIn: Bool {
        if case .signedIn = launchAccessController.clickyLaunchAuthState {
            return true
        }

        return false
    }

    private var hasUnlimitedClickyLaunchAccess: Bool {
        if case .unlocked = launchAccessController.clickyLaunchTrialState {
            return true
        }

        return false
    }

    private var clickyLaunchDisplayName: String {
        let profileName = launchAccessController.clickyLaunchProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileName.isEmpty {
            return profileName
        }

        let fullUserName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullUserName.isEmpty {
            return fullUserName
        }

        guard case let .signedIn(email) = launchAccessController.clickyLaunchAuthState else {
            return "Clicky User"
        }

        let localPart = email.split(separator: "@").first.map(String.init) ?? ""
        let normalizedLocalPart = localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedLocalPart.isEmpty {
            return "Clicky User"
        }

        return normalizedLocalPart
            .split(separator: " ")
            .map { fragment in
                let lowercased = fragment.lowercased()
                return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }

    private var clickyLaunchDisplayInitials: String {
        let words = clickyLaunchDisplayName
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .map(String.init)

        if words.count >= 2 {
            return String(words.prefix(2).compactMap(\.first)).uppercased()
        }

        let compactName = clickyLaunchDisplayName.replacingOccurrences(of: " ", with: "")
        return String(compactName.prefix(2)).uppercased()
    }

    private var isClickyLaunchPaywallActive: Bool {
        if let storedSession = ClickyAuthSessionStore.load() {
            return !storedSession.entitlement.hasAccess && storedSession.trial?.status == "paywalled"
        }

        if case .paywalled = launchAccessController.clickyLaunchTrialState {
            return true
        }

        return false
    }

    private var requiresLaunchSignInForCompanionUse: Bool {
        let allPermissionsGranted = surfaceController.hasAccessibilityPermission
            && surfaceController.hasScreenRecordingPermission
            && surfaceController.hasMicrophonePermission
            && surfaceController.hasScreenContentPermission

        guard preferences.hasCompletedOnboarding && allPermissionsGranted else {
            return false
        }

        if isClickyLaunchPaywallActive {
            return false
        }

        switch launchAccessController.clickyLaunchAuthState {
        case .signedOut, .failed:
            return true
        case .restoring, .signingIn, .signedIn:
            return false
        }
    }

    private var clickyLaunchAuthStatusLabel: String {
        switch launchAccessController.clickyLaunchAuthState {
        case .signedOut:
            return "Signed out"
        case .restoring:
            return "Restoring session"
        case .signingIn:
            return "Waiting for browser sign-in"
        case let .signedIn(email):
            return email
        case let .failed(message):
            return message
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CompanionStudioReadableCard(
                eyebrow: "Profile",
                title: "Your Account"
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 14) {
                        CompanionStudioAccessAvatar(
                            initials: clickyLaunchDisplayInitials,
                            imageURL: launchAccessController.clickyLaunchProfileImageURL,
                            palette: palette
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(clickyLaunchDisplayName)
                                .font(ClickyTypography.section(size: 24))
                                .foregroundColor(palette.cardPrimaryText)
                                .lineLimit(1)

                            Text(profileHeaderSubtitle)
                                .font(ClickyTypography.body(size: 13))
                                .foregroundColor(palette.cardSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    Text("This page keeps your account, purchase state, and app maintenance in one calm place so the companion can stay focused on helping you work.")
                        .font(ClickyTypography.body(size: 14))
                        .foregroundColor(palette.cardSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        ForEach(profileChipLabels, id: \.self) { label in
                            CompanionStudioGlassChip(text: label)
                        }
                    }
                }
            }
            .task(id: profileBackgroundSyncToken) {
                guard isClickyLaunchSignedIn else {
                    return
                }

                companionManager.refreshClickyLaunchEntitlementQuietlyIfNeeded(
                    reason: "studio-profile-scene",
                    minimumInterval: 15
                )
            }

            HStack(alignment: .top, spacing: 18) {
                CompanionStudioReadableCard(
                    eyebrow: "Account",
                    title: profileAccessTitle
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        if hasUnlimitedClickyLaunchAccess {
                            CompanionStudioAccessCelebrationCard()
                        } else {
                            Text(profileAccessCopy)
                                .font(ClickyTypography.body(size: 14))
                                .foregroundColor(palette.cardSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 12) {
                            CompanionStudioKeyValueRow(label: "Signed in", value: isClickyLaunchSignedIn ? "Yes" : "Not yet")
                            CompanionStudioKeyValueRow(label: "Account", value: clickyLaunchDisplayName)
                            CompanionStudioKeyValueRow(label: "Purchase", value: profilePurchaseStatusLabel)

                            if showsProfileCreditsRow {
                                CompanionStudioKeyValueRow(label: "Credits", value: clickyLaunchTrialStatusLabel)
                            }

                            if showsProfileCheckoutRow {
                                CompanionStudioKeyValueRow(label: "Checkout", value: clickyLaunchBillingStatusLabel)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            profilePrimaryAction
                            profileSecondaryActions
                        }
                    }
                }

                CompanionStudioReadableCard(
                    eyebrow: "App",
                    title: "Keep Clicky Up To Date"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use this space for app upkeep while the rest of Clicky stays about guidance and flow. Updates belong here, not in the daily companion surface.")
                            .font(ClickyTypography.body(size: 14))
                            .foregroundColor(palette.cardSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            NotificationCenter.default.post(name: .clickyCheckForUpdates, object: nil)
                        } label: {
                            Label("Check for Updates", systemImage: "arrow.down.circle")
                                .font(ClickyTypography.body(size: 13, weight: .semibold))
                                .frame(minWidth: 180)
                        }
                        .modifier(CompanionStudioPrimaryButtonModifier())
                        .pointerCursor()

                        Text("App updates, account state, and subscription access live here so the companion surface can stay focused on helping you get work done.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var profileHeaderSubtitle: String {
        if hasUnlimitedClickyLaunchAccess {
            return "Subscription active on this Mac."
        }

        if requiresLaunchSignInForCompanionUse {
            return "Sign in to start your Clicky taste and keep access tied to you."
        }

        if isClickyLaunchPaywallActive {
            return "Your trial wrapped up. Unlock Clicky here when you’re ready for unlimited use."
        }

        return "Your account and access are quietly syncing in the background."
    }

    private var profileChipLabels: [String] {
        if hasUnlimitedClickyLaunchAccess {
            return ["Subscription active", "Signed in"]
        }

        if requiresLaunchSignInForCompanionUse {
            return ["Sign in required"]
        }

        if isClickyLaunchPaywallActive {
            return ["Trial finished", "Unlock available"]
        }

        if clickyLaunchBillingStatusLabel == "Waiting for purchase" {
            return ["Finishing purchase", "Signed in"]
        }

        return isClickyLaunchSignedIn ? ["Signed in", "Ready on this Mac"] : ["Account not connected"]
    }

    private var profileAccessTitle: String {
        if hasUnlimitedClickyLaunchAccess {
            return "Full Access"
        }

        if requiresLaunchSignInForCompanionUse {
            return "Get Started"
        }

        if isClickyLaunchPaywallActive {
            return "Unlock Clicky"
        }

        return "Your Access"
    }

    private var profileAccessCopy: String {
        if requiresLaunchSignInForCompanionUse {
            return "Sign in once and Clicky will keep your trial, purchase state, and future restore tied to your account."
        }

        if isClickyLaunchPaywallActive {
            return "You’ve already had the taste. Unlock Clicky to keep talking to it without limits."
        }

        if clickyLaunchBillingStatusLabel == "Waiting for purchase" {
            return "Your purchase is being checked in the background. This screen should update on its own as soon as the backend confirms it."
        }

        return "Your account is active on this Mac, and Clicky is keeping access in sync behind the scenes."
    }

    private var profilePurchaseStatusLabel: String {
        if hasUnlimitedClickyLaunchAccess {
            return "Active"
        }

        if requiresLaunchSignInForCompanionUse {
            return "Not connected"
        }

        if isClickyLaunchPaywallActive {
            return "Needs unlock"
        }

        if clickyLaunchBillingStatusLabel == "Waiting for purchase" {
            return "Checking purchase"
        }

        return "Taste available"
    }

    private var showsProfileCreditsRow: Bool {
        !hasUnlimitedClickyLaunchAccess
    }

    private var showsProfileCheckoutRow: Bool {
        isClickyLaunchSignedIn
            && !hasUnlimitedClickyLaunchAccess
            && clickyLaunchBillingStatusLabel != "Idle"
    }

    private var profileBackgroundSyncToken: String {
        [
            clickyLaunchAuthStatusLabel,
            clickyLaunchBillingStatusLabel,
            clickyLaunchTrialStatusLabel,
            launchAccessController.clickyLaunchProfileImageURL
        ].joined(separator: "|")
    }

    @ViewBuilder
    private var profilePrimaryAction: some View {
        if requiresLaunchSignInForCompanionUse {
            Button {
                companionManager.startClickyLaunchSignIn()
            } label: {
                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 150)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        } else if isClickyLaunchPaywallActive {
            Button {
                companionManager.startClickyLaunchCheckout()
            } label: {
                Label("Unlock Clicky", systemImage: "creditcard")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .frame(minWidth: 150)
            }
            .modifier(CompanionStudioPrimaryButtonModifier())
            .pointerCursor()
        }
    }

    @ViewBuilder
    private var profileSecondaryActions: some View {
        if isClickyLaunchSignedIn {
            Button {
                companionManager.signOutClickyLaunchSession()
            } label: {
                Text("Sign Out")
                    .font(ClickyTypography.body(size: 12, weight: .semibold))
                    .foregroundColor(palette.cardSecondaryText)
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
    }
}

private struct CompanionStudioSupportScene: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    @ObservedObject private var backendRoutingController: ClickyBackendRoutingController
    @ObservedObject private var surfaceController: ClickySurfaceController
    @ObservedObject private var speechProviderController: ClickySpeechProviderController
    @Binding var isSupportModeEnabled: Bool
    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager, isSupportModeEnabled: Binding<Bool>) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
        _backendRoutingController = ObservedObject(wrappedValue: companionManager.backendRoutingController)
        _surfaceController = ObservedObject(wrappedValue: companionManager.surfaceController)
        _speechProviderController = ObservedObject(wrappedValue: companionManager.speechProviderController)
        _isSupportModeEnabled = isSupportModeEnabled
    }

    private var effectiveVoiceOutputDisplayName: String {
        switch preferences.clickySpeechProviderMode {
        case .system:
            return "System Speech · \(preferences.clickyVoicePreset.displayName)"
        case .elevenLabsBYO:
            let label = preferences.elevenLabsSelectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
            return "ElevenLabs · \(label.isEmpty ? "No voice selected" : label)"
        }
    }

    private var speechFallbackSummary: String? {
        if let lastSpeechFallbackMessage = speechProviderController.lastSpeechFallbackMessage {
            return lastSpeechFallbackMessage
        }

        guard preferences.clickySpeechProviderMode == .elevenLabsBYO else {
            return nil
        }

        if !companionManager.hasStoredElevenLabsAPIKey {
            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Add your ElevenLabs API key. Clicky stores it only in Keychain on this Mac."
        }

        let selectedVoiceID = preferences.elevenLabsSelectedVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedVoiceID.isEmpty {
            if case .loaded = speechProviderController.elevenLabsVoiceFetchStatus,
               speechProviderController.elevenLabsAvailableVoices.isEmpty {
                return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. This ElevenLabs account does not have any voices available yet."
            }

            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Load voices and choose the one you want Clicky to use."
        }

        if speechProviderController.isElevenLabsCreditExhausted {
            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Your ElevenLabs credits are exhausted right now, so Clicky is using System Speech until you top up or switch voices."
        }

        return nil
    }

    private var clickyOpenClawPluginStatusLabel: String {
        companionManager.clickyOpenClawPluginStatusLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CompanionStudioReadableCard(
                eyebrow: "Support",
                title: "Backstage Tools"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This page is for troubleshooting and support work. It stays separate so the rest of Studio can stay calm and user-facing.")
                        .font(ClickyTypography.body(size: 14))
                        .foregroundColor(palette.cardSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle("Show support tools", isOn: $isSupportModeEnabled)
                        .toggleStyle(.switch)
                }
            }

            HStack(alignment: .top, spacing: 18) {
                CompanionStudioReadableCard(
                    eyebrow: "Current State",
                    title: "What Clicky Is Reporting"
                ) {
                    VStack(spacing: 12) {
                        CompanionStudioKeyValueRow(label: "Speech", value: effectiveVoiceOutputDisplayName)
                        CompanionStudioKeyValueRow(label: "Bridge", value: clickyOpenClawPluginStatusLabel)
                    }
                }

                CompanionStudioReadableCard(
                    eyebrow: "When To Use This",
                    title: "What Support Mode Is For"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use this when you are helping someone restore access, checking a connection issue, or confirming what Clicky is currently using behind the scenes.")
                            .font(.body)
                            .foregroundColor(palette.cardPrimaryText)

                        Text(speechFallbackSummary ?? "No voice fallback is active right now.")
                            .font(.caption)
                            .foregroundColor(palette.cardSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct CompanionStudioProviderPopover: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var speechProviderController: ClickySpeechProviderController
    @State private var isImportVoiceExpanded = false

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _speechProviderController = ObservedObject(wrappedValue: companionManager.speechProviderController)
    }

    private var speechFallbackSummary: String? {
        if let lastSpeechFallbackMessage = speechProviderController.lastSpeechFallbackMessage {
            return lastSpeechFallbackMessage
        }

        guard preferences.clickySpeechProviderMode == .elevenLabsBYO else {
            return nil
        }

        if !companionManager.hasStoredElevenLabsAPIKey {
            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Add your ElevenLabs API key. Clicky stores it only in Keychain on this Mac."
        }

        let selectedVoiceID = preferences.elevenLabsSelectedVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedVoiceID.isEmpty {
            if case .loaded = speechProviderController.elevenLabsVoiceFetchStatus,
               speechProviderController.elevenLabsAvailableVoices.isEmpty {
                return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. This ElevenLabs account does not have any voices available yet."
            }

            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Load voices and choose the one you want Clicky to use."
        }

        if speechProviderController.isElevenLabsCreditExhausted {
            return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. Your ElevenLabs credits are exhausted right now, so Clicky is using System Speech until you top up or switch voices."
        }

        return nil
    }

    private var hasStoredElevenLabsAPIKey: Bool {
        companionManager.hasStoredElevenLabsAPIKey
    }

    private var elevenLabsStatusLabel: String {
        switch speechProviderController.elevenLabsVoiceFetchStatus {
        case .idle:
            return hasStoredElevenLabsAPIKey ? "Ready to load voices" : "API key needed"
        case .loading:
            return "Loading voices"
        case .loaded:
            return speechProviderController.elevenLabsAvailableVoices.isEmpty
                ? "No voices available"
                : "\(speechProviderController.elevenLabsAvailableVoices.count) voices available"
        case let .failed(message):
            return message
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice provider")
                .font(ClickyTypography.section(size: 24))
                .foregroundColor(palette.cardPrimaryText)

            Text("Choose the voice engine Clicky should use, then pick or import the voice you want.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                providerModeButton(
                    title: "System",
                    isSelected: preferences.clickySpeechProviderMode == .system
                ) {
                    companionManager.setClickySpeechProviderMode(.system)
                }

                providerModeButton(
                    title: "ElevenLabs",
                    isSelected: preferences.clickySpeechProviderMode == .elevenLabsBYO
                ) {
                    companionManager.setClickySpeechProviderMode(.elevenLabsBYO)
                }
            }

            if preferences.clickySpeechProviderMode == .system {
                VStack(alignment: .leading, spacing: 10) {
                    Text("System speech is active on this Mac.")
                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                        .foregroundColor(palette.cardPrimaryText)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.cardAccent.opacity(0.40))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                        )
                )
                .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let fallbackSummary = speechFallbackSummary {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Voice fallback active")
                                .font(ClickyTypography.body(size: 13, weight: .semibold))
                                .foregroundColor(palette.cardPrimaryText)

                            Text(fallbackSummary)
                                .font(.caption)
                                .foregroundColor(palette.cardSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(palette.cardAccent.opacity(0.32))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(palette.cardBorder.opacity(0.32), lineWidth: 0.8)
                                )
                        )
                    }

                    Text(hasStoredElevenLabsAPIKey ? "Update or remove your ElevenLabs API key." : "Add your ElevenLabs API key to unlock extra voices.")
                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                        .foregroundColor(palette.cardPrimaryText)

                    CompanionStudioElevenLabsAPIKeyField(companionManager: companionManager)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        Button {
                            companionManager.saveElevenLabsAPIKey()
                        } label: {
                            Label(hasStoredElevenLabsAPIKey ? "Update API Key" : "Save API Key", systemImage: "key.horizontal")
                                .font(ClickyTypography.body(size: 13, weight: .semibold))
                        }
                        .modifier(CompanionStudioPrimaryButtonModifier())
                        .pointerCursor()

                        if hasStoredElevenLabsAPIKey {
                            Button {
                                companionManager.deleteElevenLabsAPIKey()
                            } label: {
                                Label("Delete API Key", systemImage: "trash")
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                            }
                            .modifier(CompanionStudioSecondaryButtonModifier())
                            .pointerCursor()
                        }
                    }

                    if hasStoredElevenLabsAPIKey {
                        Text("Loaded voices")
                            .font(ClickyTypography.mono(size: 10, weight: .semibold))
                            .foregroundColor(palette.cardSecondaryText)

                        if speechProviderController.elevenLabsAvailableVoices.isEmpty {
                            Text(elevenLabsStatusLabel)
                                .font(.caption)
                                .foregroundColor(palette.cardSecondaryText)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(speechProviderController.elevenLabsAvailableVoices) { voice in
                                        Button {
                                            companionManager.selectElevenLabsVoice(voice)
                                            companionManager.previewCurrentSpeechOutput()
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(voice.name)
                                                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                                                    Text(voice.displaySubtitle)
                                                        .font(.caption)
                                                        .foregroundColor(palette.cardSecondaryText)
                                                }

                                                Spacer()

                                                if preferences.elevenLabsSelectedVoiceID == voice.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                }
                                            }
                                            .foregroundColor(palette.cardPrimaryText)
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(preferences.elevenLabsSelectedVoiceID == voice.id ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .pointerCursor()
                                    }
                                }
                            }
                            .frame(minHeight: 220, maxHeight: 220)
                        }

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                isImportVoiceExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isImportVoiceExpanded ? "chevron.up.circle.fill" : "square.and.arrow.down")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(isImportVoiceExpanded ? "Hide voice ID import" : "Import a voice by ID")
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                            }
                            .foregroundColor(palette.cardPrimaryText)
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()

                        if isImportVoiceExpanded {
                            VStack(alignment: .leading, spacing: 8) {
                                CompanionStudioElevenLabsVoiceIDField(companionManager: companionManager)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    companionManager.importElevenLabsVoiceByID()
                                } label: {
                                    Label("Import Voice", systemImage: "square.and.arrow.down")
                                        .font(ClickyTypography.body(size: 13, weight: .semibold))
                                }
                                .modifier(CompanionStudioModeButtonModifier(isSelected: false))
                                .pointerCursor()
                            }
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.cardAccent.opacity(0.40))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                        )
                )
                .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 24)
        .background(palette.cardBackground)
        .animation(nil, value: preferences.clickySpeechProviderMode)
        .animation(nil, value: preferences.elevenLabsSelectedVoiceID)
        .animation(nil, value: speechProviderController.elevenLabsAvailableVoices.count)
        .onAppear {
            if preferences.clickySpeechProviderMode == .elevenLabsBYO &&
                hasStoredElevenLabsAPIKey &&
                speechProviderController.elevenLabsAvailableVoices.isEmpty {
                companionManager.refreshElevenLabsVoices()
            }
        }
        .onChange(of: preferences.clickySpeechProviderMode) { _, newValue in
            guard newValue == .elevenLabsBYO else { return }
            if hasStoredElevenLabsAPIKey && speechProviderController.elevenLabsAvailableVoices.isEmpty {
                companionManager.refreshElevenLabsVoices()
            }
        }
    }

    private func providerModeButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .modifier(CompanionStudioModeButtonModifier(isSelected: isSelected))
        .pointerCursor()
    }
}

private struct CompanionStudioVoicePresetPopover: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Voice style")
                .font(ClickyTypography.section(size: 24))
                .foregroundColor(palette.cardPrimaryText)

            Text("Pick the delivery style that makes Clicky sound right to you.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ClickyVoicePreset.allCases) { preset in
                    Button {
                        preferences.clickyVoicePreset = preset
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.displayName)
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                                Text(preset.summary)
                                    .font(.caption)
                                    .foregroundColor(palette.cardSecondaryText)
                            }

                            Spacer()

                            if preferences.clickyVoicePreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(preferences.clickyVoicePreset == preset ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(palette.cardBackground)
    }
}

private struct CompanionStudioPersonaPresetPopover: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Persona")
                .font(ClickyTypography.section(size: 24))
                .foregroundColor(palette.cardPrimaryText)

            Text("Choose the overall feeling Clicky should bring. Picking a persona also resets the default voice, theme, and cursor pairing for that style.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ClickyPersonaPreset.allCases) { preset in
                    Button {
                        companionManager.setClickyPersonaPreset(preset)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.definition.displayName)
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                                Text(preset.definition.summary)
                                    .font(.caption)
                                    .foregroundColor(palette.cardSecondaryText)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            if preferences.clickyPersonaPreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(preferences.clickyPersonaPreset == preset ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(palette.cardBackground)
    }
}

private struct CompanionStudioThemePresetPopover: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Theme")
                .font(ClickyTypography.section(size: 24))
                .foregroundColor(palette.cardPrimaryText)

            Text("Choose the overall look Clicky should use inside the app.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ClickyThemePreset.allCases) { preset in
                    Button {
                        preferences.clickyThemePreset = preset
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.displayName)
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                                Text(preset == .dark ? "Moody and focused" : "Warm and airy")
                                    .font(.caption)
                                    .foregroundColor(palette.cardSecondaryText)
                            }

                            Spacer()

                            if preferences.clickyThemePreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(preferences.clickyThemePreset == preset ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(palette.cardBackground)
    }
}

private struct CompanionStudioCursorPresetPopover: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cursor style")
                .font(ClickyTypography.section(size: 24))
                .foregroundColor(palette.cardPrimaryText)

            Text("Choose how Clicky should feel beside the cursor when it listens, thinks, and points.")
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ClickyCursorStyle.allCases) { style in
                    Button {
                        preferences.clickyCursorStyle = style
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(style.displayName)
                                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                                Text(style.summary)
                                    .font(.caption)
                                    .foregroundColor(palette.cardSecondaryText)
                            }

                            Spacer()

                            if preferences.clickyCursorStyle == style {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .foregroundColor(palette.cardPrimaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(preferences.clickyCursorStyle == style ? palette.cardAccent.opacity(0.60) : palette.cardAccent.opacity(0.28))
                        )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(palette.cardBackground)
    }
}

private struct CompanionStudioAccessAvatar: View {
    let initials: String
    let imageURL: String
    let palette: CompanionStudioScalaPalette

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.sage.opacity(0.92),
                            palette.cardAccent.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let avatarURL = resolvedAvatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    fallbackInitials
                }
                .clipShape(Circle())
            } else {
                fallbackInitials
            }

            Circle()
                .stroke(palette.cardBorder.opacity(0.55), lineWidth: 1)
        }
        .frame(width: 56, height: 56)
    }

    private var resolvedAvatarURL: URL? {
        let trimmedURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            return nil
        }

        return URL(string: trimmedURL)
    }

    private var fallbackInitials: some View {
        Text(initials.isEmpty ? "CU" : initials)
            .font(ClickyTypography.mono(size: 18, weight: .semibold))
            .foregroundColor(palette.cardPrimaryText)
    }
}

private struct CompanionStudioAccessCelebrationCard: View {
    @State private var isAnimating = false

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.sage.opacity(0.88),
                                palette.cardAccent.opacity(0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.50), lineWidth: 1)
                    )

                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(palette.cardPrimaryText)
                    .scaleEffect(isAnimating ? 1.03 : 0.98)
            }
            .frame(width: 60, height: 60)
            .shadow(color: palette.sage.opacity(isAnimating ? 0.18 : 0.08), radius: isAnimating ? 14 : 8, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Subscription active")
                    .font(ClickyTypography.section(size: 22))
                    .foregroundColor(palette.cardPrimaryText)

                Text("You’ve bought full access, so Clicky is now yours to use however much you want.")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.cardAccent.opacity(0.36))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.42), lineWidth: 0.9)
                )
        )
        .onAppear {
            guard !isAnimating else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

private struct CompanionStudioNextBackdrop: View {
    let theme: ClickyTheme
    let palette: CompanionStudioScalaPalette

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                Color.clear
            } else {
                LinearGradient(
                    colors: [
                        palette.shellBackgroundTop.opacity(0.92),
                        palette.shellBackgroundMid.opacity(0.90),
                        palette.shellBackgroundBottom.opacity(0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct CompanionStudioReadableCard<Content: View>: View {
    let palette = CompanionStudioScalaPalette()

    let eyebrow: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardSecondaryText)
                    .tracking(1.0)

                Text(title)
                    .font(ClickyTypography.section(size: 30))
                    .foregroundColor(palette.cardPrimaryText)
            }

            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(palette.cardBackground)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            palette.cardAccent.opacity(0.12),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.72), lineWidth: 0.9)
                )
        )
    }
}

private struct CompanionStudioGlassChip: View {
    let text: String
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        let shape = Capsule(style: .continuous)

        Group {
            if #available(macOS 26.0, *) {
                Text(text)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassEffect(.regular, in: shape)
            } else {
                Text(text)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(shape.fill(.ultraThinMaterial))
            }
        }
        .fixedSize()
    }
}

private struct CompanionStudioJourneyStep: View {
    let step: String
    let title: String
    let copy: String

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(step)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.cardPrimaryText)
                    )

                Text(title)
                    .font(ClickyTypography.body(size: 14, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
            }

            Text(copy)
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardAccent.opacity(0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.48), lineWidth: 0.8)
                )
        )
    }
}

private struct CompanionStudioPreferenceRow: View {
    let title: String
    let subtitle: String
    let control: AnyView

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ClickyTypography.body(size: 14, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)

                Text(subtitle)
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            control
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
}

private struct CompanionStudioPreferenceBlock: View {
    let title: String
    let subtitle: String
    let content: AnyView

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)

            Text(subtitle)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            content
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
}

private struct CompanionStudioMiniMetric: View {
    let title: String
    let value: String
    var allowExpansion: Bool = false

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(value)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: allowExpansion ? .infinity : nil, alignment: .leading)
        .frame(minWidth: 0, alignment: .leading)
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
}

private struct CompanionStudioKeyValueRow: View {
    let label: String
    let value: String
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
    }
}

private struct CompanionStudioPrimaryButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.primary.opacity(0.10))
                )
        }
    }
}

private struct CompanionStudioSecondaryButtonModifier: ViewModifier {
    private let palette = CompanionStudioScalaPalette()

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            content
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.cardAccent.opacity(0.45))
                )
        }
    }
}

private struct CompanionStudioModeButtonModifier: ViewModifier {
    private let palette = CompanionStudioScalaPalette()
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if isSelected {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
            } else {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
            }
        } else {
            content
                .foregroundColor(isSelected ? .white : palette.cardPrimaryText)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? palette.sage : palette.cardAccent.opacity(0.50))
                )
        }
    }
}

private struct CompanionStudioSelectableRowButtonModifier: ViewModifier {
    private let palette = CompanionStudioScalaPalette()
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if isSelected {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
            } else {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
            }
        } else {
            content
                .foregroundColor(palette.cardPrimaryText)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? palette.sage.opacity(0.18) : Color.white.opacity(0.52))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isSelected ? palette.sage.opacity(0.45) : palette.cardBorder.opacity(0.28),
                                    lineWidth: 0.9
                                )
                        )
                )
        }
    }
}

private struct CompanionStudioHairline: View {
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        palette.cardBorder.opacity(0.65),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

struct CompanionStudioToolbarIconButtonModifier: ViewModifier {
    private let palette = CompanionStudioScalaPalette()
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        if #available(macOS 26.0, *) {
            if isSelected {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .background(
                        shape
                            .fill(palette.cardBackground.opacity(0.94))
                    )
                    .overlay(
                        shape
                            .stroke(Color.white.opacity(0.30), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 8, y: 3)
            } else {
                content
                    .foregroundColor(Color.white.opacity(0.88))
                    .background(
                        shape
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        shape
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                    )
            }
        } else {
            content
                .foregroundColor(isSelected ? palette.cardPrimaryText : Color.white.opacity(0.88))
                .background(
                    shape
                        .fill(isSelected ? palette.cardBackground.opacity(0.94) : Color.white.opacity(0.05))
                )
                .overlay(
                    shape
                        .stroke(isSelected ? Color.white.opacity(0.28) : Color.white.opacity(0.08), lineWidth: 0.6)
                )
        }
    }
}

struct CompanionStudioScalaPalette {
    let shellBackgroundTop = Color(hex: "#F2FCFF")
    let shellBackgroundMid = Color(hex: "#EAF8FF")
    let shellBackgroundBottom = Color(hex: "#DDE8EE")

    let shellTint = Color(hex: "#4FE7EE")
    let shellPrimaryText = Color(hex: "#16212B")
    let shellSecondaryText = Color(hex: "#5D7283")

    let cardBackground = Color(hex: "#FAFCFF")
    let cardPrimaryText = Color(hex: "#16212B")
    let cardSecondaryText = Color(hex: "#5D7283")
    let cardBorder = Color(hex: "#DDE8EE")
    let cardAccent = Color(hex: "#EAF8FF")

    let lavender = Color(hex: "#8EA2FF")
    let sage = Color(hex: "#4FE7EE")
    let sageText = Color(hex: "#3478F6")
    let brandWordmark = Color(hex: "#16212B")
}

private struct CompanionStudioNextWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            guard let window = view.window else { return }

            positionTrafficLights(for: window)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.toolbar = nil
            window.styleMask.insert(.fullSizeContentView)
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }

            positionTrafficLights(for: window)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.toolbar = nil
            window.styleMask.insert(.fullSizeContentView)
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }
        }
    }

    private func positionTrafficLights(for window: NSWindow) {
        guard
            let closeButton = window.standardWindowButton(.closeButton),
            let miniButton = window.standardWindowButton(.miniaturizeButton),
            let zoomButton = window.standardWindowButton(.zoomButton)
        else {
            return
        }

        let targetY: CGFloat = 14
        let startX: CGFloat = 14
        let spacing: CGFloat = 6

        closeButton.setFrameOrigin(NSPoint(x: startX, y: targetY))
        miniButton.setFrameOrigin(NSPoint(x: startX + closeButton.frame.width + spacing, y: targetY))
        zoomButton.setFrameOrigin(NSPoint(x: startX + closeButton.frame.width + miniButton.frame.width + (spacing * 2), y: targetY))
    }
}

private struct CompanionStudioNextWindowBackgroundClearStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.containerBackground(Color.clear, for: .window)
        } else {
            content
        }
    }
}
