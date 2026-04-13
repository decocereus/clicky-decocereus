//
//  CompanionManager.swift
//  leanring-buddy
//
//  Central state manager for the companion voice mode. Owns the push-to-talk
//  pipeline (dictation manager + global shortcut monitor + overlay) and
//  exposes observable voice state for the panel UI.
//

@preconcurrency import AVFoundation
import Combine
import Foundation
import OSLog
import ScreenCaptureKit
import SwiftUI

enum CompanionVoiceState {
    case idle
    case listening
    case transcribing
    case thinking
    case responding
}

enum OpenClawConnectionStatus {
    case idle
    case testing
    case connected(summary: String)
    case failed(message: String)
}

enum CodexRuntimeStatus {
    case idle
    case checking
    case ready(summary: String)
    case failed(message: String)
}

enum ClickyOpenClawPluginStatus {
    case notConfigured
    case disabled
    case enabled
}

enum ClickyShellRegistrationStatus {
    case idle
    case registering
    case registered(summary: String)
    case failed(message: String)
}

enum ClickyPersonaScopeMode: String, CaseIterable {
    case useOpenClawIdentity
    case overrideInClicky
}

enum ElevenLabsVoiceFetchStatus: Equatable {
    case idle
    case loading
    case loaded
    case failed(message: String)
}

enum ClickySpeechOutputMode {
    case system
    case elevenLabsBYO(ElevenLabsDirectConfiguration)
}

enum ClickySpeechPreviewStatus: Equatable {
    case idle
    case previewing
    case succeeded(message: String)
    case failed(message: String)
}

enum ClickyLaunchAuthState: Equatable {
    case signedOut
    case restoring
    case signingIn
    case signedIn(email: String)
    case failed(message: String)
}

enum ClickyLaunchBillingState: Equatable {
    case idle
    case openingCheckout
    case waitingForCompletion
    case canceled
    case completed
    case failed(message: String)
}

enum ClickyLaunchTrialState: Equatable {
    case inactive
    case active(remainingCredits: Int)
    case armed
    case paywalled
    case unlocked
    case failed(message: String)
}

enum ElevenLabsVoiceImportStatus: Equatable {
    case idle
    case importing
    case succeeded(message: String)
    case failed(message: String)
}

struct ClickySpeechRouting {
    let selectedProvider: ClickySpeechProviderMode
    let outputMode: ClickySpeechOutputMode
    let selectedVoiceID: String
    let selectedVoiceName: String
    let configurationFallbackMessage: String?

    var selectedProviderDisplayName: String {
        selectedProvider.displayName
    }

    var resolvedProviderDisplayName: String {
        switch outputMode {
        case .system:
            return "System Speech"
        case .elevenLabsBYO:
            return "ElevenLabs"
        }
    }

    var didFallbackToSystem: Bool {
        selectedProvider == .elevenLabsBYO && configurationFallbackMessage != nil
    }

    var selectedVoiceNameLabel: String {
        let trimmedName = selectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "No ElevenLabs voice selected" : trimmedName
    }

    var selectedVoiceIDLabel: String {
        let trimmedVoiceID = selectedVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedVoiceID.isEmpty ? "No voice id selected" : trimmedVoiceID
    }
}

private enum ClickySpeechPlaybackPurpose: String {
    case preview
    case systemMessage = "system-message"
    case assistantResponse = "assistant-response"

    var logLabel: String { rawValue }
}

private struct ClickySpeechPlaybackOutcome {
    let finalProviderDisplayName: String
    let fallbackMessage: String?
    let encounteredElevenLabsFailure: Bool
}

private struct ManagedPointNarrationStep {
    let spokenText: String
}

private struct LaunchAssistantTurnAuthorization {
    let session: ClickyAuthSessionSnapshot?
    let shouldUseWelcomeTurn: Bool
    let shouldUsePaywallTurn: Bool
}

private enum ClickyLaunchEntitlementSyncMode {
    case current
    case refresh
    case restore
}

@MainActor
final class CompanionManager: ObservableObject {
    let surfaceController = ClickySurfaceController()

    // MARK: - Onboarding Video State (shared across all screen overlays)

    private var onboardingVideoEndObserver: NSObjectProtocol?
    private var onboardingDemoTimeObserver: Any?

    // MARK: - Onboarding Prompt Bubble

    /// Text streamed character-by-character on the cursor after the onboarding video ends.
    // MARK: - Tutorial Playback State

    let tutorialController = ClickyTutorialController()
    private var tutorialImportTask: Task<Void, Never>?

    // MARK: - Onboarding Music

    private var onboardingMusicPlayer: AVAudioPlayer?
    private var onboardingMusicFadeTimer: Timer?
    private var onboardingPromptTask: Task<Void, Never>?

    let preferences = ClickyPreferencesStore()
    let backendRoutingController = ClickyBackendRoutingController()
    let launchAccessController = ClickyLaunchAccessController()
    let speechProviderController = ClickySpeechProviderController()
    let buddyDictationManager = BuddyDictationManager()
    let globalPushToTalkShortcutMonitor = GlobalPushToTalkShortcutMonitor()
    let overlayWindowManager = OverlayWindowManager()
    // Response text is now displayed inline on the cursor overlay via
    // streamingResponseText, so no separate response overlay manager is needed.

    private lazy var claudeAPI: ClaudeAPI = {
        return ClaudeAPI(proxyURL: "\(CompanionRuntimeConfiguration.workerBaseURL)/chat", model: selectedModel)
    }()

    private lazy var claudeAssistantProvider: ClaudeAssistantProvider = {
        ClaudeAssistantProvider(claudeAPI: claudeAPI)
    }()

    private let openClawGatewayCompanionAgent = OpenClawGatewayCompanionAgent()
    private let codexRuntimeClient = CodexRuntimeClient()

    private lazy var openClawAssistantProvider: OpenClawAssistantProvider = {
        OpenClawAssistantProvider(
            gatewayAgent: openClawGatewayCompanionAgent,
            configurationProvider: { [weak self] in
                guard let self else {
                    return OpenClawAssistantProviderConfiguration(
                        gatewayURLString: "",
                        gatewayAuthToken: nil,
                        agentIdentifier: "",
                        sessionKey: "",
                        shellIdentifier: ""
                    )
                }

                return OpenClawAssistantProviderConfiguration(
                    gatewayURLString: self.openClawGatewayURL,
                    gatewayAuthToken: self.openClawGatewayAuthToken,
                    agentIdentifier: self.openClawAgentIdentifier,
                    sessionKey: self.openClawSessionKey,
                    shellIdentifier: self.clickyShellIdentifier
                )
            }
        )
    }()

    private lazy var codexAssistantProvider: CodexAssistantProvider = {
        CodexAssistantProvider(runtimeClient: codexRuntimeClient)
    }()

    private let assistantTurnBuilder = ClickyAssistantTurnBuilder()
    private let assistantSystemPromptPlanner = ClickyAssistantSystemPromptPlanner()
    private let assistantFocusContextProvider = ClickyAssistantFocusContextProvider()
    private lazy var assistantBasePromptSource = ClickyAssistantBasePromptSource { [weak self] backend in
        guard let self else { return "" }
        switch backend {
        case .claude:
            return self.companionVoiceResponseSystemPrompt()
        case .codex:
            return self.companionVoiceResponseSystemPrompt()
        case .openClaw:
            return self.openClawShellScopedSystemPrompt()
        }
    }

    private lazy var assistantProviderRegistry: ClickyAssistantProviderRegistry = {
        ClickyAssistantProviderRegistry(
            providers: [
                claudeAssistantProvider,
                codexAssistantProvider,
                openClawAssistantProvider,
            ]
        )
    }()

    private lazy var assistantTurnExecutor: ClickyAssistantTurnExecutor = {
        ClickyAssistantTurnExecutor(providerRegistry: assistantProviderRegistry)
    }()

    private lazy var elevenLabsTTSClient: ElevenLabsTTSClient = {
        return ElevenLabsTTSClient(proxyURL: "\(CompanionRuntimeConfiguration.workerBaseURL)/tts")
    }()

    /// Conversation history so Claude remembers prior exchanges within a session.
    /// Each entry is the user's transcript and Claude's response.
    private var conversationHistory: [(userTranscript: String, assistantResponse: String)] = []
    private var tutorialConversationHistory: [(userTranscript: String, assistantResponse: String)] = []
    private var pendingDetectedElementTargets: [QueuedPointingTarget] = []
    private var pendingManagedPointNarrationSteps: [ManagedPointNarrationStep] = []
    private var pointTargetArrivalContinuation: CheckedContinuation<Void, Never>?
    private var isManagedPointSequenceActive = false

    /// The currently running AI response task, if any. Cancelled when the user
    /// speaks again so a new response can begin immediately.
    private var currentResponseTask: Task<Void, Never>?

    private var shortcutTransitionCancellable: AnyCancellable?
    private var voiceStateCancellable: AnyCancellable?
    private var audioPowerCancellable: AnyCancellable?
    private var tutorialPlaybackShortcutCancellable: AnyCancellable?
    private var accessibilityCheckTimer: Timer?
    private var pendingKeyboardShortcutStartTask: Task<Void, Never>?
    private var clickyShellHeartbeatTimer: Timer?
    /// Scheduled hide for transient cursor mode — cancelled if the user
    /// speaks again before the delay elapses.
    private var transientHideTask: Task<Void, Never>?
    private var quietLaunchEntitlementRefreshTask: Task<Void, Never>?
    private var lastQuietLaunchEntitlementRefreshAt: Date?
    private var preferencesObjectWillChangeCancellable: AnyCancellable?
    private var backendRoutingObjectWillChangeCancellable: AnyCancellable?
    private var launchAccessObjectWillChangeCancellable: AnyCancellable?
    private var tutorialObjectWillChangeCancellable: AnyCancellable?
    private var surfaceObjectWillChangeCancellable: AnyCancellable?
    private var speechProviderObjectWillChangeCancellable: AnyCancellable?

    init() {
        preferencesObjectWillChangeCancellable = preferences.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        backendRoutingObjectWillChangeCancellable = backendRoutingController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        launchAccessObjectWillChangeCancellable = launchAccessController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        tutorialObjectWillChangeCancellable = tutorialController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        surfaceObjectWillChangeCancellable = surfaceController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        speechProviderObjectWillChangeCancellable = speechProviderController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// True when all three required permissions (accessibility, screen recording,
    /// microphone) are granted. Used by the panel to show a single "all good" state.
    var allPermissionsGranted: Bool {
        hasAccessibilityPermission && hasScreenRecordingPermission && hasMicrophonePermission && hasScreenContentPermission
    }

    var voiceState: CompanionVoiceState {
        get { surfaceController.voiceState }
        set { surfaceController.voiceState = newValue }
    }

    var lastTranscript: String? {
        get { surfaceController.lastTranscript }
        set { surfaceController.lastTranscript = newValue }
    }

    var currentAudioPowerLevel: CGFloat {
        get { surfaceController.currentAudioPowerLevel }
        set { surfaceController.currentAudioPowerLevel = newValue }
    }

    var hasAccessibilityPermission: Bool {
        get { surfaceController.hasAccessibilityPermission }
        set { surfaceController.hasAccessibilityPermission = newValue }
    }

    var hasScreenRecordingPermission: Bool {
        get { surfaceController.hasScreenRecordingPermission }
        set { surfaceController.hasScreenRecordingPermission = newValue }
    }

    var hasMicrophonePermission: Bool {
        get { surfaceController.hasMicrophonePermission }
        set { surfaceController.hasMicrophonePermission = newValue }
    }

    var hasScreenContentPermission: Bool {
        get { surfaceController.hasScreenContentPermission }
        set { surfaceController.hasScreenContentPermission = newValue }
    }

    /// Screen location (global AppKit coords) of a detected UI element the
    /// buddy should fly to and point at. Parsed from Claude's response;
    /// observed by BlueCursorView to trigger the flight animation.
    var detectedElementScreenLocation: CGPoint? {
        get { surfaceController.detectedElementScreenLocation }
        set { surfaceController.detectedElementScreenLocation = newValue }
    }

    /// The display frame (global AppKit coords) of the screen the detected
    /// element is on, so BlueCursorView knows which screen overlay should animate.
    var detectedElementDisplayFrame: CGRect? {
        get { surfaceController.detectedElementDisplayFrame }
        set { surfaceController.detectedElementDisplayFrame = newValue }
    }

    /// Custom speech bubble text for the pointing animation. When set,
    /// BlueCursorView uses this instead of a random pointer phrase.
    var detectedElementBubbleText: String? {
        get { surfaceController.detectedElementBubbleText }
        set { surfaceController.detectedElementBubbleText = newValue }
    }

    var managedPointSequenceReturnToken: Int {
        get { surfaceController.managedPointSequenceReturnToken }
        set { surfaceController.managedPointSequenceReturnToken = newValue }
    }

    var onboardingVideoPlayer: AVPlayer? {
        get { surfaceController.onboardingVideoPlayer }
        set { surfaceController.onboardingVideoPlayer = newValue }
    }

    var showOnboardingVideo: Bool {
        get { surfaceController.showOnboardingVideo }
        set { surfaceController.showOnboardingVideo = newValue }
    }

    var onboardingVideoOpacity: Double {
        get { surfaceController.onboardingVideoOpacity }
        set { surfaceController.onboardingVideoOpacity = newValue }
    }

    /// Text streamed character-by-character on the cursor after the onboarding video ends.
    var onboardingPromptText: String {
        get { surfaceController.onboardingPromptText }
        set { surfaceController.onboardingPromptText = newValue }
    }

    var onboardingPromptOpacity: Double {
        get { surfaceController.onboardingPromptOpacity }
        set { surfaceController.onboardingPromptOpacity = newValue }
    }

    var showOnboardingPrompt: Bool {
        get { surfaceController.showOnboardingPrompt }
        set { surfaceController.showOnboardingPrompt = newValue }
    }

    /// Whether the blue cursor overlay is currently visible on screen.
    /// Used by the panel to show accurate status text ("Active" vs "Ready").
    var isOverlayVisible: Bool {
        get { surfaceController.isOverlayVisible }
        set { surfaceController.isOverlayVisible = newValue }
    }

    var tutorialPlaybackState: TutorialPlaybackBindingState? {
        get { tutorialController.tutorialPlaybackState }
        set { tutorialController.tutorialPlaybackState = newValue }
    }

    var tutorialPlaybackBubbleOpacity: Double {
        get { tutorialController.tutorialPlaybackBubbleOpacity }
        set { tutorialController.tutorialPlaybackBubbleOpacity = newValue }
    }

    var tutorialPlaybackLastCommand: TutorialPlaybackCommand? {
        get { tutorialController.tutorialPlaybackLastCommand }
        set { tutorialController.tutorialPlaybackLastCommand = newValue }
    }

    var tutorialPlaybackCommandNonce: Int {
        get { tutorialController.tutorialPlaybackCommandNonce }
        set { tutorialController.tutorialPlaybackCommandNonce = newValue }
    }

    var tutorialImportURLDraft: String {
        get { tutorialController.tutorialImportURLDraft }
        set { tutorialController.tutorialImportURLDraft = newValue }
    }

    var currentTutorialImportDraft: TutorialImportDraft? {
        get { tutorialController.currentTutorialImportDraft }
        set { tutorialController.currentTutorialImportDraft = newValue }
    }

    var tutorialSessionState: TutorialSessionState? {
        get { tutorialController.tutorialSessionState }
        set { tutorialController.tutorialSessionState = newValue }
    }

    var isTutorialImportRunning: Bool {
        get { tutorialController.isTutorialImportRunning }
        set { tutorialController.isTutorialImportRunning = newValue }
    }

    var tutorialImportStatusMessage: String? {
        get { tutorialController.tutorialImportStatusMessage }
        set { tutorialController.tutorialImportStatusMessage = newValue }
    }

    /// The Claude model used for voice responses. Persisted to UserDefaults.
    var selectedModel: String {
        get { preferences.selectedModel }
        set { preferences.selectedModel = newValue }
    }

    /// The active agent backend driving the companion response pipeline.
    /// Claude remains the default, but OpenClaw can be selected for local
    /// Gateway-backed agent runs.
    var selectedAgentBackend: CompanionAgentBackend {
        get { preferences.selectedAgentBackend }
        set { preferences.selectedAgentBackend = newValue }
    }

    /// Connection details for the OpenClaw Gateway backend. These are kept
    /// lightweight for the first integration pass so the app can target a
    /// local Gateway quickly while still allowing remote/tunneled setups.
    var openClawGatewayURL: String {
        get { preferences.openClawGatewayURL }
        set { preferences.openClawGatewayURL = newValue }
    }

    var openClawAgentIdentifier: String {
        get { preferences.openClawAgentIdentifier }
        set { preferences.openClawAgentIdentifier = newValue }
    }

    var openClawAgentName: String {
        get { preferences.openClawAgentName }
        set { preferences.openClawAgentName = newValue }
    }

    var openClawGatewayAuthToken: String {
        get { preferences.openClawGatewayAuthToken }
        set { preferences.openClawGatewayAuthToken = newValue }
    }

    var openClawSessionKey: String {
        get { preferences.openClawSessionKey }
        set { preferences.openClawSessionKey = newValue }
    }

    var openClawConnectionStatus: OpenClawConnectionStatus {
        get { backendRoutingController.openClawConnectionStatus }
        set { backendRoutingController.openClawConnectionStatus = newValue }
    }

    var codexRuntimeStatus: CodexRuntimeStatus {
        get { backendRoutingController.codexRuntimeStatus }
        set { backendRoutingController.codexRuntimeStatus = newValue }
    }

    var clickyShellRegistrationStatus: ClickyShellRegistrationStatus {
        get { backendRoutingController.clickyShellRegistrationStatus }
        set { backendRoutingController.clickyShellRegistrationStatus = newValue }
    }

    var clickyShellServerFreshnessState: String? {
        get { backendRoutingController.clickyShellServerFreshnessState }
        set { backendRoutingController.clickyShellServerFreshnessState = newValue }
    }

    var clickyShellServerStatusSummary: String? {
        get { backendRoutingController.clickyShellServerStatusSummary }
        set { backendRoutingController.clickyShellServerStatusSummary = newValue }
    }

    var clickyShellServerSessionBindingState: String? {
        get { backendRoutingController.clickyShellServerSessionBindingState }
        set { backendRoutingController.clickyShellServerSessionBindingState = newValue }
    }

    var clickyShellServerSessionKey: String? {
        get { backendRoutingController.clickyShellServerSessionKey }
        set { backendRoutingController.clickyShellServerSessionKey = newValue }
    }

    var clickyShellServerTrustState: String? {
        get { backendRoutingController.clickyShellServerTrustState }
        set { backendRoutingController.clickyShellServerTrustState = newValue }
    }

    var inferredOpenClawAgentIdentityAvatar: String? {
        get { backendRoutingController.inferredOpenClawAgentIdentityAvatar }
        set { backendRoutingController.inferredOpenClawAgentIdentityAvatar = newValue }
    }

    var inferredOpenClawAgentIdentityName: String? {
        get { backendRoutingController.inferredOpenClawAgentIdentityName }
        set { backendRoutingController.inferredOpenClawAgentIdentityName = newValue }
    }

    var inferredOpenClawAgentIdentityEmoji: String? {
        get { backendRoutingController.inferredOpenClawAgentIdentityEmoji }
        set { backendRoutingController.inferredOpenClawAgentIdentityEmoji = newValue }
    }

    var inferredOpenClawAgentIdentifier: String? {
        get { backendRoutingController.inferredOpenClawAgentIdentifier }
        set { backendRoutingController.inferredOpenClawAgentIdentifier = newValue }
    }

    var codexConfiguredModelName: String? {
        get { backendRoutingController.codexConfiguredModelName }
        set { backendRoutingController.codexConfiguredModelName = newValue }
    }

    var codexExecutablePath: String? {
        get { backendRoutingController.codexExecutablePath }
        set { backendRoutingController.codexExecutablePath = newValue }
    }

    var codexAuthModeLabel: String? {
        get { backendRoutingController.codexAuthModeLabel }
        set { backendRoutingController.codexAuthModeLabel = newValue }
    }

    var clickyPersonaScopeMode: ClickyPersonaScopeMode {
        get { preferences.clickyPersonaScopeMode }
        set {
            guard preferences.clickyPersonaScopeMode != newValue else { return }
            preferences.clickyPersonaScopeMode = newValue
            refreshClickyShellRegistrationLifecycle()
        }
    }

    var clickyPersonaOverrideName: String {
        get { preferences.clickyPersonaOverrideName }
        set {
            guard preferences.clickyPersonaOverrideName != newValue else { return }
            preferences.clickyPersonaOverrideName = newValue
            refreshClickyShellRegistrationLifecycle()
        }
    }

    var clickyPersonaOverrideInstructions: String {
        get { preferences.clickyPersonaOverrideInstructions }
        set {
            guard preferences.clickyPersonaOverrideInstructions != newValue else { return }
            preferences.clickyPersonaOverrideInstructions = newValue
            refreshClickyShellRegistrationLifecycle()
        }
    }

    var clickyPersonaPreset: ClickyPersonaPreset {
        get { preferences.clickyPersonaPreset }
        set {
            guard preferences.clickyPersonaPreset != newValue else { return }
            preferences.clickyPersonaPreset = newValue
            refreshClickyShellRegistrationLifecycle()
        }
    }

    var clickyPersonaToneInstructions: String {
        get { preferences.clickyPersonaToneInstructions }
        set {
            guard preferences.clickyPersonaToneInstructions != newValue else { return }
            preferences.clickyPersonaToneInstructions = newValue
            refreshClickyShellRegistrationLifecycle()
        }
    }

    var clickyVoicePreset: ClickyVoicePreset {
        get { preferences.clickyVoicePreset }
        set { preferences.clickyVoicePreset = newValue }
    }

    var clickyCursorStyle: ClickyCursorStyle {
        get { preferences.clickyCursorStyle }
        set { preferences.clickyCursorStyle = newValue }
    }

    var clickySpeechProviderMode: ClickySpeechProviderMode {
        get { preferences.clickySpeechProviderMode }
        set {
            guard preferences.clickySpeechProviderMode != newValue else { return }
            preferences.clickySpeechProviderMode = newValue
            ClickyLogger.notice(.audio, "Speech provider selected provider=\(clickySpeechProviderMode.displayName)")
        }
    }

    var elevenLabsAPIKeyDraft: String {
        get { speechProviderController.elevenLabsAPIKeyDraft }
        set { speechProviderController.elevenLabsAPIKeyDraft = newValue }
    }

    var elevenLabsImportVoiceIDDraft: String {
        get { speechProviderController.elevenLabsImportVoiceIDDraft }
        set { speechProviderController.elevenLabsImportVoiceIDDraft = newValue }
    }

    var elevenLabsAvailableVoices: [ElevenLabsVoiceOption] {
        get { speechProviderController.elevenLabsAvailableVoices }
        set { speechProviderController.elevenLabsAvailableVoices = newValue }
    }

    var elevenLabsVoiceFetchStatus: ElevenLabsVoiceFetchStatus {
        get { speechProviderController.elevenLabsVoiceFetchStatus }
        set { speechProviderController.elevenLabsVoiceFetchStatus = newValue }
    }

    var elevenLabsVoiceImportStatus: ElevenLabsVoiceImportStatus {
        get { speechProviderController.elevenLabsVoiceImportStatus }
        set { speechProviderController.elevenLabsVoiceImportStatus = newValue }
    }

    var speechPreviewStatus: ClickySpeechPreviewStatus {
        get { speechProviderController.speechPreviewStatus }
        set { speechProviderController.speechPreviewStatus = newValue }
    }

    var lastSpeechFallbackMessage: String? {
        get { speechProviderController.lastSpeechFallbackMessage }
        set { speechProviderController.lastSpeechFallbackMessage = newValue }
    }

    var isElevenLabsCreditExhausted: Bool {
        get { speechProviderController.isElevenLabsCreditExhausted }
        set { speechProviderController.isElevenLabsCreditExhausted = newValue }
    }

    var isElevenLabsAPIKeyRejected: Bool {
        get { speechProviderController.isElevenLabsAPIKeyRejected }
        set { speechProviderController.isElevenLabsAPIKeyRejected = newValue }
    }

    var isElevenLabsBackendVoiceUnavailable: Bool {
        get { speechProviderController.isElevenLabsBackendVoiceUnavailable }
        set { speechProviderController.isElevenLabsBackendVoiceUnavailable = newValue }
    }
    var clickyLaunchAuthState: ClickyLaunchAuthState {
        get { launchAccessController.clickyLaunchAuthState }
        set { launchAccessController.clickyLaunchAuthState = newValue }
    }

    var clickyLaunchEntitlementStatusLabel: String {
        get { launchAccessController.clickyLaunchEntitlementStatusLabel }
        set { launchAccessController.clickyLaunchEntitlementStatusLabel = newValue }
    }

    var clickyLaunchBillingState: ClickyLaunchBillingState {
        get { launchAccessController.clickyLaunchBillingState }
        set { launchAccessController.clickyLaunchBillingState = newValue }
    }

    var clickyLaunchTrialState: ClickyLaunchTrialState {
        get { launchAccessController.clickyLaunchTrialState }
        set { launchAccessController.clickyLaunchTrialState = newValue }
    }

    var clickyLaunchProfileName: String {
        get { launchAccessController.clickyLaunchProfileName }
        set { launchAccessController.clickyLaunchProfileName = newValue }
    }

    var clickyLaunchProfileImageURL: String {
        get { launchAccessController.clickyLaunchProfileImageURL }
        set { launchAccessController.clickyLaunchProfileImageURL = newValue }
    }
    var clickyBackendBaseURL: String {
        get { preferences.clickyBackendBaseURL }
        set { preferences.clickyBackendBaseURL = newValue }
    }

    var elevenLabsSelectedVoiceID: String {
        get { preferences.elevenLabsSelectedVoiceID }
        set { preferences.elevenLabsSelectedVoiceID = newValue }
    }

    var elevenLabsSelectedVoiceName: String {
        get { preferences.elevenLabsSelectedVoiceName }
        set { preferences.elevenLabsSelectedVoiceName = newValue }
    }

    var clickyThemePreset: ClickyThemePreset {
        get { preferences.clickyThemePreset }
        set { preferences.clickyThemePreset = newValue }
    }

    var clickyLaunchAuthStatusLabel: String {
        switch clickyLaunchAuthState {
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

    var clickyLaunchBillingStatusLabel: String {
        switch clickyLaunchBillingState {
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

    var clickyLaunchTrialStatusLabel: String {
        switch clickyLaunchTrialState {
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

    var isClickyLaunchSignedIn: Bool {
        if case .signedIn = clickyLaunchAuthState {
            return true
        }

        return false
    }

    var clickyLaunchDisplayName: String {
        let profileName = clickyLaunchProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileName.isEmpty {
            return profileName
        }

        let fullUserName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullUserName.isEmpty {
            return fullUserName
        }

        guard case let .signedIn(email) = clickyLaunchAuthState else {
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

    var clickyLaunchDisplayInitials: String {
        let words = clickyLaunchDisplayName
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .map(String.init)

        if words.count >= 2 {
            return String(words.prefix(2).compactMap(\.first)).uppercased()
        }

        let compactName = clickyLaunchDisplayName.replacingOccurrences(of: " ", with: "")
        return String(compactName.prefix(2)).uppercased()
    }

    var hasUnlimitedClickyLaunchAccess: Bool {
        if case .unlocked = clickyLaunchTrialState {
            return true
        }

        return false
    }

    var isClickyLaunchAuthPending: Bool {
        switch clickyLaunchAuthState {
        case .restoring, .signingIn:
            return true
        case .signedOut, .signedIn, .failed:
            return false
        }
    }

    var requiresLaunchRepurchaseForCompanionUse: Bool {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            return false
        }

        return launchEntitlementRequiresRepurchase(storedSession.entitlement)
    }

    var requiresLaunchEntitlementRefreshForCompanionUse: Bool {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            return false
        }

        return launchEntitlementGraceExpired(storedSession.entitlement)
    }

    var requiresLaunchSignInForCompanionUse: Bool {
        guard hasCompletedOnboarding && allPermissionsGranted else {
            return false
        }

        if isClickyLaunchPaywallActive {
            return false
        }

        switch clickyLaunchAuthState {
        case .signedOut, .failed:
            return true
        case .restoring, .signingIn, .signedIn:
            return false
        }
    }

    var isClickyLaunchPaywallActive: Bool {
        if let storedSession = ClickyAuthSessionStore.load() {
            return !storedSession.entitlement.hasAccess && storedSession.trial?.status == "paywalled"
        }

        switch clickyLaunchTrialState {
        case .paywalled:
            return true
        default:
            return false
        }
    }

    var hasStoredElevenLabsAPIKey: Bool {
        !(ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var activeClickyPersonaDefinition: ClickyPersonaDefinition {
        clickyPersonaPreset.definition
    }

    var effectiveClickyVoicePreset: ClickyVoicePreset {
        clickyVoicePreset
    }

    var effectiveClickyCursorStyle: ClickyCursorStyle {
        clickyCursorStyle
    }

    var effectiveClickyPersonaSpeechInstructions: String {
        let presetGuidance = activeClickyPersonaDefinition.speechGuidance
        let responseContract = activeClickyPersonaDefinition.responseContract
        let customTone = clickyPersonaToneInstructions.trimmingCharacters(in: .whitespacesAndNewlines)

        if customTone.isEmpty {
            return "\(presetGuidance) \(responseContract)"
        }

        return "\(presetGuidance) \(responseContract) also follow these clicky-only tone notes: \(customTone)"
    }

    func setClickyPersonaPreset(_ preset: ClickyPersonaPreset) {
        clickyPersonaPreset = preset
        clickyThemePreset = preset.definition.defaultThemePreset
        clickyVoicePreset = preset.definition.defaultVoicePreset
        clickyCursorStyle = preset.definition.defaultCursorStyle
    }

    func saveElevenLabsAPIKey() {
        let trimmedAPIKey = elevenLabsAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        speechPreviewStatus = .idle
        lastSpeechFallbackMessage = nil
        isElevenLabsCreditExhausted = false
        isElevenLabsAPIKeyRejected = false
        isElevenLabsBackendVoiceUnavailable = false

        if trimmedAPIKey.isEmpty {
            ClickySecrets.delete(account: "elevenlabs_api_key")
            elevenLabsAvailableVoices = []
            elevenLabsVoiceFetchStatus = .idle
            elevenLabsVoiceImportStatus = .idle
            elevenLabsSelectedVoiceID = ""
            elevenLabsSelectedVoiceName = ""
            clickySpeechProviderMode = .system
            ClickyLogger.notice(.audio, "Removed ElevenLabs API key from local Keychain storage")
            return
        }

        do {
            try ClickySecrets.save(key: trimmedAPIKey, account: "elevenlabs_api_key")
            elevenLabsVoiceFetchStatus = .idle
            elevenLabsVoiceImportStatus = .idle
            ClickyLogger.notice(.audio, "Saved ElevenLabs API key to local Keychain storage")
        } catch {
            elevenLabsVoiceFetchStatus = .failed(message: "Could not save API key")
            ClickyLogger.error(.audio, "Failed to save ElevenLabs API key locally error=\(error.localizedDescription)")
        }
    }

    func deleteElevenLabsAPIKey() {
        elevenLabsAPIKeyDraft = ""
        saveElevenLabsAPIKey()
    }

    func refreshElevenLabsVoices() {
        let apiKey = (ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            elevenLabsVoiceFetchStatus = .failed(message: "Add an API key first")
            ClickyLogger.error(.audio, "Voice refresh blocked because no ElevenLabs API key is saved locally")
            return
        }

        elevenLabsVoiceFetchStatus = .loading
        elevenLabsVoiceImportStatus = .idle
        speechPreviewStatus = .idle
        lastSpeechFallbackMessage = nil
        isElevenLabsCreditExhausted = false
        isElevenLabsAPIKeyRejected = false
        isElevenLabsBackendVoiceUnavailable = false
        ClickyLogger.info(.audio, "Refreshing ElevenLabs voice list")

        Task { @MainActor in
            do {
                let voices = try await ElevenLabsService.fetchVoices(apiKey: apiKey)
                elevenLabsAvailableVoices = voices
                elevenLabsVoiceFetchStatus = .loaded

                if voices.isEmpty {
                    elevenLabsSelectedVoiceID = ""
                    elevenLabsSelectedVoiceName = ""
                    ClickyLogger.notice(.audio, "ElevenLabs voice refresh succeeded with zero available voices")
                } else if elevenLabsSelectedVoiceID.isEmpty, let firstVoice = voices.first {
                    elevenLabsSelectedVoiceID = firstVoice.id
                    elevenLabsSelectedVoiceName = firstVoice.name
                } else if let selectedVoice = voices.first(where: { $0.id == elevenLabsSelectedVoiceID }) {
                    elevenLabsSelectedVoiceName = selectedVoice.name
                } else if let firstVoice = voices.first {
                    elevenLabsSelectedVoiceID = firstVoice.id
                    elevenLabsSelectedVoiceName = firstVoice.name
                }

                ClickyLogger.notice(.audio, "ElevenLabs voice refresh succeeded count=\(voices.count)")
            } catch {
                elevenLabsVoiceFetchStatus = .failed(message: error.localizedDescription)
                ClickyLogger.error(.audio, "ElevenLabs voice refresh failed error=\(error.localizedDescription)")
            }
        }
    }

    func selectElevenLabsVoice(_ voice: ElevenLabsVoiceOption) {
        elevenLabsSelectedVoiceID = voice.id
        elevenLabsSelectedVoiceName = voice.name
        elevenLabsImportVoiceIDDraft = voice.id
        speechPreviewStatus = .idle
        lastSpeechFallbackMessage = nil
        isElevenLabsCreditExhausted = false
        isElevenLabsAPIKeyRejected = false
        isElevenLabsBackendVoiceUnavailable = false
        ClickyLogger.notice(.audio, "Selected ElevenLabs voice name=\(voice.name) id=\(voice.id)")
    }

    func importElevenLabsVoiceByID() {
        let apiKey = (ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            elevenLabsVoiceImportStatus = .failed(message: "Save your ElevenLabs API key first.")
            ClickyLogger.error(.audio, "Voice import blocked because no ElevenLabs API key is saved locally")
            return
        }

        let voiceID = elevenLabsImportVoiceIDDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !voiceID.isEmpty else {
            elevenLabsVoiceImportStatus = .failed(message: "Paste a voice ID first.")
            return
        }

        elevenLabsVoiceImportStatus = .importing
        ClickyLogger.info(.audio, "Importing ElevenLabs voice by id=\(voiceID)")

        Task { @MainActor in
            do {
                let importedVoice = try await ElevenLabsService.fetchVoice(apiKey: apiKey, voiceID: voiceID)
                upsertElevenLabsVoice(importedVoice)
                elevenLabsVoiceFetchStatus = .loaded
                selectElevenLabsVoice(importedVoice)
                elevenLabsVoiceImportStatus = .succeeded(message: "Imported \(importedVoice.name).")
                ClickyLogger.notice(.audio, "Imported ElevenLabs voice name=\(importedVoice.name) id=\(importedVoice.id)")
            } catch {
                elevenLabsVoiceImportStatus = .failed(message: error.localizedDescription)
                ClickyLogger.error(.audio, "Failed to import ElevenLabs voice id=\(voiceID) error=\(error.localizedDescription)")
            }
        }
    }

    func previewCurrentSpeechOutput() {
        if case .previewing = speechPreviewStatus {
            return
        }

        speechPreviewStatus = .previewing
        elevenLabsTTSClient.stopPlayback()

        Task { @MainActor in
            let outcome = await playSpeechText(
                Self.speechPreviewSampleText,
                purpose: .preview
            )

            if outcome.finalProviderDisplayName == "Unavailable" {
                speechPreviewStatus = .failed(
                    message: outcome.fallbackMessage ?? "Clicky could not play the preview."
                )
                return
            }

            if let fallbackMessage = outcome.fallbackMessage {
                speechPreviewStatus = .succeeded(message: fallbackMessage)
                return
            }

            speechPreviewStatus = .succeeded(
                message: "Preview played through \(outcome.finalProviderDisplayName)."
            )
        }
    }

    func setSelectedModel(_ model: String) {
        guard selectedModel != model else { return }
        selectedModel = model
        UserDefaults.standard.set(model, forKey: "selectedClaudeModel")
        Task { @MainActor [weak self] in
            self?.claudeAPI.model = model
        }
    }

    func startClickyLaunchSignIn() {
        ClickyUnifiedTelemetry.launchAuth.info("Launch auth sign-in requested")
        ClickyLogger.notice(.app, "Starting Clicky launch sign-in")

        Task { @MainActor in
            do {
                let payload = try await clickyBackendAuthClient.startNativeSignIn()
                guard let browserURL = URL(string: payload.browserURL) else {
                    throw ClickyBackendAuthClientError.invalidBackendURL
                }

                let didOpenBrowser = NSWorkspace.shared.open(browserURL)
                setLaunchAuthState(.signingIn, reason: "sign-in-browser-opened")
                ClickyUnifiedTelemetry.launchAuth.info(
                    "Launch auth sign-in browser opened success=\(didOpenBrowser ? "true" : "false", privacy: .public)"
                )
            } catch {
                setLaunchAuthState(.failed(message: error.localizedDescription), reason: "sign-in-start-failed")
                ClickyUnifiedTelemetry.launchAuth.error(
                    "Launch auth sign-in failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to start Clicky launch sign-in error=\(error.localizedDescription)")
            }
        }
    }

    func signOutClickyLaunchSession() {
        ClickyAuthSessionStore.clear()
        setLaunchAuthState(.signedOut, reason: "sign-out")
        clickyLaunchEntitlementStatusLabel = "Unknown"
        setLaunchBillingState(.idle, reason: "sign-out")
        setLaunchTrialState(.inactive, reason: "sign-out")
        clickyLaunchProfileName = ""
        clickyLaunchProfileImageURL = ""
        ClickyUnifiedTelemetry.launchAuth.info("Launch auth sign-out completed")
        ClickyLogger.notice(.app, "Cleared Clicky launch auth session")
    }

    func startClickyLaunchCheckout() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            setLaunchBillingState(.failed(message: "Sign in before starting checkout."), reason: "checkout-blocked-no-session")
            ClickyUnifiedTelemetry.billing.info("Checkout blocked reason=no-session")
            ClickyLogger.error(.app, "Checkout blocked because no launch auth session is available")
            return
        }

        setLaunchBillingState(.openingCheckout, reason: "checkout-requested")
        ClickyUnifiedTelemetry.billing.info("Checkout requested")
        ClickyLogger.notice(.app, "Starting Polar checkout")

        Task { @MainActor in
            do {
                let checkoutPayload = try await clickyBackendAuthClient.createCheckoutSession(sessionToken: storedSession.sessionToken)
                guard let checkoutURL = URL(string: checkoutPayload.checkout.url) else {
                    throw ClickyBackendAuthClientError.invalidBackendURL
                }

                let didOpenBrowser = NSWorkspace.shared.open(checkoutURL)
                setLaunchBillingState(.waitingForCompletion, reason: "checkout-browser-opened")
                ClickyUnifiedTelemetry.billing.info(
                    "Checkout browser opened success=\(didOpenBrowser ? "true" : "false", privacy: .public)"
                )
                ClickyLogger.notice(.app, "Opened Polar checkout")
            } catch {
                setLaunchBillingState(.failed(message: error.localizedDescription), reason: "checkout-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Checkout failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to start Polar checkout error=\(error.localizedDescription)")
            }
        }
    }

    func refreshClickyLaunchEntitlement() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            setLaunchAuthState(.signedOut, reason: "manual-entitlement-refresh-no-session")
            clickyLaunchEntitlementStatusLabel = "Unknown"
            clickyLaunchProfileName = ""
            clickyLaunchProfileImageURL = ""
            ClickyUnifiedTelemetry.billing.info("Entitlement refresh blocked reason=no-session")
            ClickyLogger.error(.app, "Entitlement refresh blocked because no launch auth session is available")
            return
        }

        ClickyUnifiedTelemetry.billing.info("Entitlement refresh requested source=manual")
        ClickyLogger.info(.app, "Refreshing launch entitlement")

        Task { @MainActor in
            do {
                let refreshedSnapshot = try await synchronizeLaunchSessionSnapshot(
                    sessionToken: storedSession.sessionToken,
                    fallbackUserID: storedSession.userID,
                    fallbackEmail: storedSession.email,
                    entitlementSyncMode: .refresh
                )
                try persistLaunchSessionSnapshot(refreshedSnapshot, reason: "manual-entitlement-refresh")
                if refreshedSnapshot.entitlement.hasAccess {
                    setLaunchBillingState(.completed, reason: "manual-entitlement-refresh")
                }
                ClickyUnifiedTelemetry.billing.info(
                    "Entitlement refresh completed source=manual access=\(refreshedSnapshot.entitlement.hasAccess ? "true" : "false", privacy: .public) status=\(refreshedSnapshot.entitlement.status, privacy: .public)"
                )
                ClickyLogger.notice(.app, "Launch entitlement refresh completed")
            } catch {
                setLaunchBillingState(.failed(message: error.localizedDescription), reason: "manual-entitlement-refresh-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Entitlement refresh failed source=manual error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to refresh Clicky launch entitlement error=\(error.localizedDescription)")
            }
        }
    }

    func restoreClickyLaunchAccess() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            setLaunchBillingState(.failed(message: "Sign in before restoring access."), reason: "restore-blocked-no-session")
            ClickyUnifiedTelemetry.billing.info("Restore access blocked reason=no-session")
            ClickyLogger.error(.app, "Restore blocked because no launch auth session is available")
            return
        }

        setLaunchBillingState(.waitingForCompletion, reason: "restore-requested")
        ClickyUnifiedTelemetry.billing.info("Restore access requested")
        ClickyLogger.info(.app, "Restoring launch access")

        Task { @MainActor in
            do {
                let restoredSnapshot = try await synchronizeLaunchSessionSnapshot(
                    sessionToken: storedSession.sessionToken,
                    fallbackUserID: storedSession.userID,
                    fallbackEmail: storedSession.email,
                    entitlementSyncMode: .restore
                )
                try persistLaunchSessionSnapshot(restoredSnapshot, reason: "restore-access")
                setLaunchBillingState(
                    restoredSnapshot.entitlement.hasAccess ? .completed : .idle,
                    reason: "restore-access"
                )
                ClickyUnifiedTelemetry.billing.info(
                    "Restore access completed access=\(restoredSnapshot.entitlement.hasAccess ? "true" : "false", privacy: .public) status=\(restoredSnapshot.entitlement.status, privacy: .public)"
                )
                ClickyLogger.notice(.app, "Restore launch access completed")
            } catch {
                setLaunchBillingState(.failed(message: error.localizedDescription), reason: "restore-access-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Restore access failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to restore Clicky launch access error=\(error.localizedDescription)")
            }
        }
    }

    func handleClickyLaunchCallback(url: URL) {
        guard url.scheme?.lowercased() == "clicky" else { return }

        if url.host?.lowercased() == "auth", url.path == "/callback" {
            ClickyUnifiedTelemetry.launchAuth.info("Launch auth callback received")
            ClickyLogger.notice(.app, "Received Clicky auth callback")
            handleClickyLaunchAuthCallback(url: url)
            return
        }

        if url.host?.lowercased() == "billing", url.path == "/success" {
            setLaunchBillingState(.completed, reason: "billing-callback-success")
            ClickyUnifiedTelemetry.billing.info("Billing callback received outcome=success")
            ClickyLogger.notice(.app, "Received Clicky billing success callback")
            refreshClickyLaunchEntitlement()
            return
        }

        if url.host?.lowercased() == "billing", url.path == "/cancel" {
            setLaunchBillingState(.canceled, reason: "billing-callback-cancel")
            ClickyUnifiedTelemetry.billing.info("Billing callback received outcome=cancel")
            ClickyLogger.notice(.app, "Received Clicky billing cancel callback")
        }
    }

    private func handleClickyLaunchAuthCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let exchangeCode = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !exchangeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setLaunchAuthState(
                .failed(message: ClickyBackendAuthClientError.missingExchangeCode.localizedDescription),
                reason: "auth-callback-missing-code"
            )
            ClickyUnifiedTelemetry.launchAuth.error("Launch auth callback missing exchange code")
            return
        }

        setLaunchAuthState(.signingIn, reason: "auth-callback-received")
        ClickyUnifiedTelemetry.launchAuth.info("Launch auth exchange started")

        Task { @MainActor in
            do {
                let exchangePayload = try await clickyBackendAuthClient.exchangeNativeCode(exchangeCode)
                let snapshot = try await synchronizeLaunchSessionSnapshot(
                    sessionToken: exchangePayload.sessionToken,
                    fallbackUserID: exchangePayload.userID
                )

                try persistLaunchSessionSnapshot(snapshot, reason: "auth-exchange")
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .clickyOpenStudio, object: nil)
                ClickyUnifiedTelemetry.launchAuth.info("Launch auth exchange completed")
                ClickyLogger.notice(.app, "Completed Clicky launch auth exchange")
            } catch {
                setLaunchAuthState(.failed(message: error.localizedDescription), reason: "auth-exchange-failed")
                clickyLaunchEntitlementStatusLabel = "Unknown"
                ClickyUnifiedTelemetry.launchAuth.error(
                    "Launch auth exchange failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to complete Clicky launch auth exchange error=\(error.localizedDescription)")
            }
        }
    }

    func setSelectedAgentBackend(_ selectedAgentBackend: CompanionAgentBackend) {
        guard self.selectedAgentBackend != selectedAgentBackend else { return }
        self.selectedAgentBackend = selectedAgentBackend
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.refreshClickyShellRegistrationLifecycle()
            self.refreshOpenClawAgentIdentity()
            self.refreshCodexRuntimeStatus()
        }
    }

    func setClickySpeechProviderMode(_ mode: ClickySpeechProviderMode) {
        guard clickySpeechProviderMode != mode else { return }
        clickySpeechProviderMode = mode

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.speechPreviewStatus = .idle
            self.lastSpeechFallbackMessage = nil

            if mode == .system {
                self.isElevenLabsCreditExhausted = false
                self.isElevenLabsAPIKeyRejected = false
                self.isElevenLabsBackendVoiceUnavailable = false
            } else if self.hasStoredElevenLabsAPIKey && self.elevenLabsAvailableVoices.isEmpty {
                self.refreshElevenLabsVoices()
            }
        }
    }

    func setOpenClawGatewayURL(_ gatewayURL: String) {
        guard openClawGatewayURL != gatewayURL else { return }
        openClawGatewayURL = gatewayURL

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.openClawConnectionStatus = .idle
            self.refreshClickyShellRegistrationLifecycle()
            self.refreshOpenClawAgentIdentity()
        }
    }

    func setOpenClawAgentIdentifier(_ agentIdentifier: String) {
        guard openClawAgentIdentifier != agentIdentifier else { return }
        openClawAgentIdentifier = agentIdentifier

        Task { @MainActor [weak self] in
            self?.refreshOpenClawAgentIdentity()
        }
    }

    func setOpenClawGatewayAuthToken(_ authToken: String) {
        guard openClawGatewayAuthToken != authToken else { return }
        openClawGatewayAuthToken = authToken

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.openClawConnectionStatus = .idle
            self.refreshClickyShellRegistrationLifecycle()
            self.refreshOpenClawAgentIdentity()
        }
    }

    func setOpenClawSessionKey(_ sessionKey: String) {
        guard openClawSessionKey != sessionKey else { return }
        openClawSessionKey = sessionKey

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.openClawConnectionStatus = .idle
            if case .registered = self.clickyShellRegistrationStatus {
                self.bindClickyShellSession()
            } else {
                self.refreshClickyShellRegistrationLifecycle()
            }
            self.refreshOpenClawAgentIdentity()
        }
    }

    var effectiveVoiceOutputDisplayName: String {
        switch effectiveSpeechRouting.outputMode {
        case .system:
            return "System Speech · \(effectiveClickyVoicePreset.displayName)"
        case .elevenLabsBYO:
            let label = effectiveSpeechRouting.selectedVoiceNameLabel
            return "ElevenLabs · \(label)"
        }
    }

    var effectiveSpeechRouting: ClickySpeechRouting {
        let selectedVoiceID = elevenLabsSelectedVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedVoiceName = elevenLabsSelectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)

        switch clickySpeechProviderMode {
        case .system:
            return ClickySpeechRouting(
                selectedProvider: .system,
                outputMode: .system,
                selectedVoiceID: selectedVoiceID,
                selectedVoiceName: selectedVoiceName,
                configurationFallbackMessage: nil
            )
        case .elevenLabsBYO:
            let apiKey = (ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if apiKey.isEmpty {
                return ClickySpeechRouting(
                    selectedProvider: .elevenLabsBYO,
                    outputMode: .system,
                    selectedVoiceID: selectedVoiceID,
                    selectedVoiceName: selectedVoiceName,
                    configurationFallbackMessage: "Add your ElevenLabs API key. Clicky stores it only in Keychain on this Mac."
                )
            }

            if selectedVoiceID.isEmpty {
                let message: String
                if case .loaded = elevenLabsVoiceFetchStatus, elevenLabsAvailableVoices.isEmpty {
                    message = "This ElevenLabs account does not have any voices available yet."
                } else {
                    message = "Load voices and choose the one you want Clicky to use."
                }

                return ClickySpeechRouting(
                    selectedProvider: .elevenLabsBYO,
                    outputMode: .system,
                    selectedVoiceID: selectedVoiceID,
                    selectedVoiceName: selectedVoiceName,
                    configurationFallbackMessage: message
                )
            }

            if isElevenLabsCreditExhausted {
                return ClickySpeechRouting(
                    selectedProvider: .elevenLabsBYO,
                    outputMode: .system,
                    selectedVoiceID: selectedVoiceID,
                    selectedVoiceName: selectedVoiceName,
                    configurationFallbackMessage: "Your ElevenLabs credits are exhausted right now, so Clicky is using System Speech until you top up or switch voices."
                )
            }

            return ClickySpeechRouting(
                selectedProvider: .elevenLabsBYO,
                outputMode: .elevenLabsBYO(ElevenLabsDirectConfiguration(apiKey: apiKey, voiceID: selectedVoiceID)),
                selectedVoiceID: selectedVoiceID,
                selectedVoiceName: selectedVoiceName,
                configurationFallbackMessage: nil
            )
        }
    }

    var speechFallbackSummary: String? {
        if let lastSpeechFallbackMessage {
            return lastSpeechFallbackMessage
        }

        guard let configurationFallbackMessage = effectiveSpeechRouting.configurationFallbackMessage else {
            return nil
        }

        return "ElevenLabs is selected, but Clicky is speaking with System Speech for now. \(configurationFallbackMessage)"
    }

    var speechPreviewStatusLabel: String {
        switch speechPreviewStatus {
        case .idle:
            return "Preview ready"
        case .previewing:
            return "Playing preview"
        case .succeeded:
            return "Preview played"
        case .failed:
            return "Preview failed"
        }
    }

    var speechPreviewStatusMessage: String? {
        switch speechPreviewStatus {
        case .idle:
            return nil
        case .previewing:
            return "Clicky is playing the current voice sample now."
        case .succeeded(let message), .failed(let message):
            return message
        }
    }

    var isSpeechPreviewInFlight: Bool {
        if case .previewing = speechPreviewStatus {
            return true
        }

        return false
    }

    var openClawGatewayAuthSummary: String {
        if !openClawGatewayAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Using token from Studio settings"
        }

        return OpenClawGatewayCompanionAgent.localGatewayAuthTokenSummary()
    }

    var isOpenClawGatewayRemote: Bool {
        guard let gatewayURL = URL(string: openClawGatewayURL),
              let host = gatewayURL.host?.lowercased() else {
            return false
        }

        return gatewayURL.scheme == "wss"
            || !(host == "127.0.0.1" || host == "localhost" || host == "::1")
    }

    var clickyOpenClawPluginIdentifier: String {
        "clicky-shell"
    }

    var clickyOpenClawPluginStatus: ClickyOpenClawPluginStatus {
        guard let openClawConfiguration = loadLocalOpenClawConfiguration(),
              let plugins = openClawConfiguration["plugins"] as? [String: Any],
              let entries = plugins["entries"] as? [String: Any],
              let clickyEntry = entries[clickyOpenClawPluginIdentifier] as? [String: Any] else {
            return .notConfigured
        }

        let isEnabled = (clickyEntry["enabled"] as? Bool) ?? false
        return isEnabled ? .enabled : .disabled
    }

    var clickyOpenClawPluginStatusLabel: String {
        switch clickyOpenClawPluginStatus {
        case .enabled:
            return "Enabled in local OpenClaw config"
        case .disabled:
            return "Installed but disabled"
        case .notConfigured:
            return "Not configured in local OpenClaw yet"
        }
    }

    var clickyOpenClawPluginInstallPathHint: String {
        #if DEBUG
        let repositoryRootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repositoryRootURL.appendingPathComponent("plugins/openclaw-clicky-shell").path
        #else
        return "/path/to/clicky-decocereus/plugins/openclaw-clicky-shell"
        #endif
    }

    var clickyOpenClawPluginInstallCommand: String {
        "openclaw plugins install \(clickyOpenClawPluginInstallPathHint)"
    }

    var clickyOpenClawPluginEnableCommand: String {
        "openclaw plugins enable \(clickyOpenClawPluginIdentifier) && openclaw gateway restart"
    }

    var clickyOpenClawRemoteReadinessSummary: String {
        if isOpenClawGatewayRemote {
            if !openClawGatewayAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Remote Gateway is configured with an explicit Studio token."
            }

            return "Remote Gateway URL is set. Add a Studio token if the remote host does not share your local ~/.openclaw auth."
        }

        return "Local Gateway is ready. Remote-ready mode works once you switch the Gateway URL to wss:// and provide a valid token."
    }

    var clickyShellRegistrationStatusLabel: String {
        switch clickyShellRegistrationStatus {
        case .idle:
            return "Shell not registered yet"
        case .registering:
            return "Registering Clicky shell"
        case .registered:
            return "Shell registered"
        case .failed:
            return "Shell registration failed"
        }
    }

    var clickyShellServerSessionKeyLabel: String {
        clickyShellServerSessionKey ?? "No session bound yet"
    }

    var clickyShellServerFreshnessLabel: String {
        clickyShellServerFreshnessState ?? "unknown"
    }

    var clickyShellServerTrustLabel: String {
        clickyShellServerTrustState ?? "unknown"
    }

    var clickyShellServerBindingLabel: String {
        clickyShellServerSessionBindingState ?? "unknown"
    }

    var effectiveOpenClawAgentName: String {
        let manualName = openClawAgentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manualName.isEmpty {
            return manualName
        }

        let inferredName = inferredOpenClawAgentIdentityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !inferredName.isEmpty {
            return inferredName
        }

        return "your OpenClaw agent"
    }

    var inferredOpenClawAgentIdentityDisplayName: String {
        let emojiPrefix = inferredOpenClawAgentIdentityEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let identityName = inferredOpenClawAgentIdentityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !emojiPrefix.isEmpty && !identityName.isEmpty {
            return "\(emojiPrefix) \(identityName)"
        }

        if !identityName.isEmpty {
            return identityName
        }

        return "Not detected yet"
    }

    var inferredOpenClawAgentIdentityEmojiLabel: String {
        let emojiValue = inferredOpenClawAgentIdentityEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return emojiValue.isEmpty ? "No emoji provided by OpenClaw" : emojiValue
    }

    var inferredOpenClawAgentIdentityAvatarLabel: String {
        let avatarValue = inferredOpenClawAgentIdentityAvatar?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return avatarValue.isEmpty ? "No avatar provided by OpenClaw" : "Avatar available from OpenClaw"
    }

    var effectiveClickyPresentationName: String {
        if selectedAgentBackend != .openClaw {
            let overrideName = clickyPersonaOverrideName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !overrideName.isEmpty {
                return overrideName
            }
            return "Clicky"
        }

        if clickyPersonaScopeMode == .overrideInClicky {
            let overrideName = clickyPersonaOverrideName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !overrideName.isEmpty {
                return overrideName
            }
            return "Clicky"
        }

        return effectiveOpenClawAgentName
    }

    var clickyPersonaScopeLabel: String {
        switch clickyPersonaScopeMode {
        case .useOpenClawIdentity:
            return "Use OpenClaw identity"
        case .overrideInClicky:
            return "Override only in Clicky"
        }
    }

    var activeClickyPersonaLabel: String {
        activeClickyPersonaDefinition.displayName
    }

    var selectedAssistantModelIdentityLabel: String {
        switch selectedAgentBackend {
        case .claude:
            return selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        case .codex:
            let configuredModel = codexConfiguredModelName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !configuredModel.isEmpty {
                return configuredModel
            }
            return "codex"
        case .openClaw:
            let configuredAgentIdentifier = openClawAgentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            if !configuredAgentIdentifier.isEmpty {
                return configuredAgentIdentifier
            }

            let inferredAgentIdentifier = inferredOpenClawAgentIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !inferredAgentIdentifier.isEmpty {
                return inferredAgentIdentifier
            }

            return effectiveOpenClawAgentName
        }
    }

    var elevenLabsStatusLabel: String {
        switch elevenLabsVoiceFetchStatus {
        case .idle:
            return hasStoredElevenLabsAPIKey ? "Ready to load voices" : "API key needed"
        case .loading:
            return "Loading voices"
        case .loaded:
            return elevenLabsAvailableVoices.isEmpty
                ? "No voices available"
                : "\(elevenLabsAvailableVoices.count) voices available"
        case .failed(let message):
            return message
        }
    }

    var effectiveSpeechOutputMode: ClickySpeechOutputMode {
        effectiveSpeechRouting.outputMode
    }

    private func logActivePersonaForRequest(transcript: String, backend: CompanionAgentBackend, systemPrompt: String) {
        ClickyLogger.notice(
            .agent,
            "request backend=\(backend.displayName) model=\(selectedAssistantModelIdentityLabel) persona=\(activeClickyPersonaLabel) display=\(effectiveClickyPresentationName) voice=\(effectiveClickyVoicePreset.displayName) cursor=\(effectiveClickyCursorStyle.displayName) scope=\(clickyPersonaScopeLabel) transcriptLength=\(transcript.count)"
        )
        ClickyLogger.debug(
            .agent,
            "prompt-shape backend=\(backend.displayName) model=\(selectedAssistantModelIdentityLabel) persona=\(activeClickyPersonaLabel) promptLength=\(systemPrompt.count)"
        )
    }

    private func logAgentResponse(_ response: String, backend: CompanionAgentBackend) {
        ClickyLogger.notice(
            .agent,
            "response backend=\(backend.displayName) model=\(selectedAssistantModelIdentityLabel) persona=\(activeClickyPersonaLabel) display=\(effectiveClickyPresentationName) voice=\(effectiveClickyVoicePreset.displayName) responseLength=\(response.count)"
        )
    }

    private func makeAssistantTurnRequest(
        systemPrompt: String,
        transcript: String,
        labeledImages: [(data: Data, label: String)],
        focusContext: ClickyAssistantFocusContext?
    ) -> ClickyAssistantTurnRequest {
        assistantTurnBuilder.buildRequest(
            systemPrompt: systemPrompt,
            userPrompt: transcript,
            conversationHistory: conversationHistory,
            labeledImages: labeledImages.map { labeledImage in
                ClickyAssistantLabeledImage(
                    data: labeledImage.data,
                    label: labeledImage.label,
                    mimeType: "image/jpeg"
                )
            },
            focusContext: focusContext
        )
    }

    private func launchPromptMode(
        for authorization: LaunchAssistantTurnAuthorization
    ) -> ClickyAssistantLaunchPromptMode {
        if authorization.shouldUsePaywallTurn {
            return .paywall
        }
        if authorization.shouldUseWelcomeTurn {
            return .welcome
        }
        return .standard
    }

    private func makeSystemPrompt(
        basePrompt: String,
        authorization: LaunchAssistantTurnAuthorization
    ) -> String {
        assistantSystemPromptPlanner.buildSystemPrompt(
            basePrompt: basePrompt,
            launchMode: launchPromptMode(for: authorization)
        )
    }

    private func makeAssistantTurnPlan(
        backend: CompanionAgentBackend,
        authorization: LaunchAssistantTurnAuthorization,
        transcript: String,
        labeledImages: [(data: Data, label: String)],
        focusContext: ClickyAssistantFocusContext?
    ) -> ClickyAssistantTurnPlan {
        let systemPrompt = makeSystemPrompt(
            basePrompt: assistantBasePromptSource.basePrompt(for: backend),
            authorization: authorization
        )

        let request = makeAssistantTurnRequest(
            systemPrompt: systemPrompt,
            transcript: transcript,
            labeledImages: labeledImages,
            focusContext: focusContext
        )

        ClickyAgentTurnDiagnostics.logCanonicalRequest(
            backend: backend,
            request: request
        )

        return ClickyAssistantTurnPlan(
            backend: backend,
            systemPrompt: systemPrompt,
            request: request
        )
    }

    private func playSpeechText(
        _ text: String,
        purpose: ClickySpeechPlaybackPurpose
    ) async -> ClickySpeechPlaybackOutcome {
        if purpose == .systemMessage {
            return await playSystemMessageText(text)
        }

        let routing = effectiveSpeechRouting
        let selectedVoiceName = routing.selectedVoiceNameLabel
        let selectedVoiceID = routing.selectedVoiceIDLabel
        let configurationFallbackMessage = routing.configurationFallbackMessage ?? "none"

        ClickyLogger.info(
            .audio,
            "speech-routing purpose=\(purpose.logLabel) selected=\(routing.selectedProviderDisplayName) resolved=\(routing.resolvedProviderDisplayName) voiceName=\(selectedVoiceName) voiceID=\(selectedVoiceID) configFallback=\(configurationFallbackMessage)"
        )

        do {
            try await elevenLabsTTSClient.speakText(
                text,
                voicePreset: effectiveClickyVoicePreset,
                outputMode: routing.outputMode
            )

            if case .elevenLabsBYO = routing.outputMode {
                isElevenLabsCreditExhausted = false
            }

            if let fallbackMessage = routing.configurationFallbackMessage {
                let summary = "ElevenLabs is selected, but this \(purpose.logLabel) used System Speech. \(fallbackMessage)"
                lastSpeechFallbackMessage = summary
                ClickyLogger.notice(
                    .audio,
                    "speech-playback success purpose=\(purpose.logLabel) provider=System Speech reason=config-fallback"
                )
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "System Speech",
                    fallbackMessage: summary,
                    encounteredElevenLabsFailure: false
                )
            }

            lastSpeechFallbackMessage = nil
            ClickyLogger.notice(
                .audio,
                "speech-playback success purpose=\(purpose.logLabel) provider=\(routing.resolvedProviderDisplayName)"
            )
            return ClickySpeechPlaybackOutcome(
                finalProviderDisplayName: routing.resolvedProviderDisplayName,
                fallbackMessage: nil,
                encounteredElevenLabsFailure: false
            )
        } catch {
            switch routing.outputMode {
            case .system:
                let failureMessage = "Clicky could not play audio. \(error.localizedDescription)"
                lastSpeechFallbackMessage = failureMessage
                ClickyLogger.error(
                    .audio,
                    "speech-playback failed purpose=\(purpose.logLabel) provider=System Speech error=\(error.localizedDescription)"
                )
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "Unavailable",
                    fallbackMessage: failureMessage,
                    encounteredElevenLabsFailure: false
                )
            case .elevenLabsBYO:
                let isCreditExhaustion = isLikelyElevenLabsCreditExhaustion(error)
                if isCreditExhaustion {
                    isElevenLabsCreditExhausted = true
                }

                let fallbackMessage: String
                if isCreditExhaustion {
                    fallbackMessage = "Your ElevenLabs credits are exhausted right now, so Clicky switched to System Speech and kept the conversation moving."
                } else {
                    fallbackMessage = "ElevenLabs could not play audio, so Clicky fell back to System Speech. \(error.localizedDescription)"
                }
                lastSpeechFallbackMessage = fallbackMessage
                ClickyLogger.error(
                    .audio,
                    "speech-playback failed purpose=\(purpose.logLabel) provider=ElevenLabs voiceName=\(selectedVoiceName) voiceID=\(selectedVoiceID) error=\(error.localizedDescription)"
                )

                do {
                    try await elevenLabsTTSClient.speakText(
                        text,
                        voicePreset: effectiveClickyVoicePreset,
                        outputMode: .system
                    )
                } catch {
                    let failureMessage = "Clicky could not play audio. \(error.localizedDescription)"
                    lastSpeechFallbackMessage = failureMessage
                    ClickyLogger.error(
                        .audio,
                        "speech-playback fallback failed purpose=\(purpose.logLabel) error=\(error.localizedDescription)"
                    )
                    return ClickySpeechPlaybackOutcome(
                        finalProviderDisplayName: "Unavailable",
                        fallbackMessage: failureMessage,
                        encounteredElevenLabsFailure: true
                    )
                }

                ClickyLogger.notice(
                    .audio,
                    "speech-playback fallback purpose=\(purpose.logLabel) provider=System Speech reason=elevenlabs-runtime-failure"
                )
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "System Speech",
                    fallbackMessage: fallbackMessage,
                    encounteredElevenLabsFailure: true
                )
            }
        }
    }

    private func playSystemMessageText(_ text: String) async -> ClickySpeechPlaybackOutcome {
        let selectedVoiceID = elevenLabsSelectedVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedVoiceName = elevenLabsSelectedVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedAPIKey = (ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !storedAPIKey.isEmpty && !selectedVoiceID.isEmpty && !isElevenLabsCreditExhausted && !isElevenLabsAPIKeyRejected {
            do {
                try await elevenLabsTTSClient.speakText(
                    text,
                    voicePreset: effectiveClickyVoicePreset,
                    outputMode: .elevenLabsBYO(
                        ElevenLabsDirectConfiguration(apiKey: storedAPIKey, voiceID: selectedVoiceID)
                    )
                )
                isElevenLabsCreditExhausted = false
                isElevenLabsAPIKeyRejected = false
                lastSpeechFallbackMessage = nil
                ClickyLogger.notice(
                    .audio,
                    "speech-playback success purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=ElevenLabs source=user-key voiceName=\(selectedVoiceName)"
                )
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "ElevenLabs",
                    fallbackMessage: nil,
                    encounteredElevenLabsFailure: false
                )
            } catch {
                if isLikelyElevenLabsCreditExhaustion(error) {
                    isElevenLabsCreditExhausted = true
                    lastSpeechFallbackMessage = "Your ElevenLabs credits are exhausted right now, so Clicky is using its built-in voice for system messages and System Speech for spoken fallback."
                }
                if isLikelyElevenLabsUnauthorized(error) {
                    isElevenLabsAPIKeyRejected = true
                    lastSpeechFallbackMessage = "Your ElevenLabs API key was rejected, so Clicky will use backup voices until you update it."
                }
                ClickyLogger.error(
                    .audio,
                    "speech-playback failed purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=ElevenLabs source=user-key voiceName=\(selectedVoiceName) error=\(error.localizedDescription)"
                )
            }
        }

        if !isElevenLabsBackendVoiceUnavailable {
            do {
                try await elevenLabsTTSClient.speakTextViaProxy(
                    text,
                    voicePreset: effectiveClickyVoicePreset
                )
                if lastSpeechFallbackMessage == nil {
                    lastSpeechFallbackMessage = "Clicky is handling system voice messages with its built-in ElevenLabs voice right now."
                }
                ClickyLogger.notice(
                    .audio,
                    "speech-playback success purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=ElevenLabs source=clicky-backend"
                )
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "ElevenLabs",
                    fallbackMessage: lastSpeechFallbackMessage,
                    encounteredElevenLabsFailure: false
                )
            } catch {
                if isLikelyElevenLabsVoiceMissing(error) {
                    isElevenLabsBackendVoiceUnavailable = true
                    lastSpeechFallbackMessage = "Clicky's backup ElevenLabs voice is unavailable right now, so it is using System Speech for system messages."
                }
                ClickyLogger.error(
                    .audio,
                    "speech-playback failed purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=ElevenLabs source=clicky-backend error=\(error.localizedDescription)"
                )
            }
        }

        do {
            try await elevenLabsTTSClient.speakText(
                text,
                voicePreset: effectiveClickyVoicePreset,
                outputMode: .system
            )
            let fallbackMessage = lastSpeechFallbackMessage ?? "Clicky is using System Speech for now."
            lastSpeechFallbackMessage = fallbackMessage
            ClickyLogger.notice(
                .audio,
                "speech-playback fallback purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=System Speech"
            )
            return ClickySpeechPlaybackOutcome(
                finalProviderDisplayName: "System Speech",
                fallbackMessage: fallbackMessage,
                encounteredElevenLabsFailure: true
            )
        } catch {
            let failureMessage = "Clicky could not play this system message. \(error.localizedDescription)"
            lastSpeechFallbackMessage = failureMessage
            ClickyLogger.error(
                .audio,
                "speech-playback failed purpose=\(ClickySpeechPlaybackPurpose.systemMessage.logLabel) provider=System Speech error=\(error.localizedDescription)"
            )
            return ClickySpeechPlaybackOutcome(
                finalProviderDisplayName: "Unavailable",
                fallbackMessage: failureMessage,
                encounteredElevenLabsFailure: true
            )
        }
    }

    private func isLikelyElevenLabsCreditExhaustion(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("credit")
            || message.contains("credits")
            || message.contains("balance")
            || message.contains("quota")
            || message.contains("insufficient")
    }

    private func isLikelyElevenLabsUnauthorized(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("api key was rejected")
            || message.contains("unauthorized")
            || message.contains("401")
    }

    private func isLikelyElevenLabsVoiceMissing(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("voice could not be found")
            || message.contains("voice not be found")
            || message.contains("voice not found")
            || message.contains("404")
    }

    private static let speechPreviewSampleText = "hey, this is clicky. here is how your current voice sounds."
    private static let launchPaywallLockedMessage = "clicky has used the included trial on this mac. open studio to unlock access or restore your purchase, and everything will pick up from there."

    private func upsertElevenLabsVoice(_ voice: ElevenLabsVoiceOption) {
        var voicesByID: [String: ElevenLabsVoiceOption] = [:]
        for existingVoice in elevenLabsAvailableVoices {
            voicesByID[existingVoice.id] = existingVoice
        }
        voicesByID[voice.id] = voice

        let otherVoices = voicesByID.values
            .filter { $0.id != voice.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        elevenLabsAvailableVoices = [voice] + otherVoices
    }

    func testOpenClawConnection() {
        if case .testing = openClawConnectionStatus {
            return
        }

        openClawConnectionStatus = .testing

        Task { @MainActor in
            do {
                let summary = try await openClawGatewayCompanionAgent.testConnection(
                    gatewayURLString: openClawGatewayURL,
                    explicitGatewayAuthToken: openClawGatewayAuthToken
                )
                openClawConnectionStatus = .connected(summary: summary)
                ClickyLogger.notice(.gateway, "OpenClaw connection test succeeded summary=\(summary)")
                refreshOpenClawAgentIdentity()
            } catch {
                openClawConnectionStatus = .failed(message: error.localizedDescription)
                ClickyLogger.error(.gateway, "OpenClaw connection test failed error=\(error.localizedDescription)")
            }
        }
    }

    func refreshCodexRuntimeStatus() {
        codexRuntimeStatus = .checking

        Task { @MainActor in
            let snapshot = codexRuntimeClient.inspectRuntime()
            codexConfiguredModelName = snapshot.configuredModel
            codexExecutablePath = snapshot.executablePath
            codexAuthModeLabel = snapshot.authModeLabel

            if !snapshot.isInstalled {
                codexRuntimeStatus = .failed(message: "Codex is not installed on this Mac yet.")
                ClickyLogger.error(.agent, "Codex runtime unavailable reason=not-installed")
                return
            }

            if !snapshot.isAuthenticated {
                codexRuntimeStatus = .failed(message: "Codex needs a ChatGPT sign-in before Clicky can use it.")
                ClickyLogger.error(.agent, "Codex runtime unavailable reason=not-authenticated")
                return
            }

            let modelLabel = snapshot.configuredModel ?? "default model"
            codexRuntimeStatus = .ready(summary: "Codex is ready on this Mac using \(modelLabel).")
            ClickyLogger.notice(.agent, "Codex runtime ready authMode=\(snapshot.authModeLabel ?? "unknown") model=\(modelLabel)")
        }
    }

    var codexRuntimeStatusLabel: String {
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

    var codexRuntimeSummaryCopy: String {
        switch codexRuntimeStatus {
        case .idle:
            return "Codex runs locally on this Mac and can use your ChatGPT subscription when it is signed in and ready."
        case .checking:
            return "Clicky is checking whether Codex is installed and signed in on this Mac."
        case .ready(let summary):
            return summary
        case .failed(let message):
            return message
        }
    }

    var codexReadinessChipLabels: [String] {
        var labels: [String] = []
        labels.append(codexRuntimeStatusLabel)

        if let authModeLabel = codexAuthModeLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !authModeLabel.isEmpty {
            labels.append(authModeLabel)
        }

        if let configuredModelName = codexConfiguredModelName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configuredModelName.isEmpty {
            labels.append(configuredModelName)
        }

        if labels.count == 1 {
            labels.append("Local runtime")
        }

        return labels
    }

    var codexConfiguredModelLabel: String {
        codexConfiguredModelName ?? "Use Codex default"
    }

    var codexAccountLabel: String {
        codexAuthModeLabel ?? "ChatGPT sign-in needed"
    }

    func openCodexInstallPage() {
        guard let url = URL(string: "https://github.com/openai/codex") else { return }
        NSWorkspace.shared.open(url)
    }

    func startCodexLoginInTerminal() {
        let command = "codex login"
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }

    func registerClickyShellNow() {
        if selectedAgentBackend != .openClaw {
            clickyShellRegistrationStatus = .failed(message: "Switch the Agent backend to OpenClaw before registering the Clicky shell.")
            ClickyLogger.error(.plugin, "Shell registration blocked because backend is not OpenClaw")
            return
        }

        if openClawGatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clickyShellRegistrationStatus = .failed(message: "Set an OpenClaw Gateway URL before registering the Clicky shell.")
            ClickyLogger.error(.plugin, "Shell registration blocked because gateway URL is empty")
            return
        }

        if !isOpenClawGatewayRemote && clickyOpenClawPluginStatus != .enabled {
            clickyShellRegistrationStatus = .failed(message: "Enable the local clicky-shell plugin first, then try registering again.")
            ClickyLogger.error(.plugin, "Shell registration blocked because clicky-shell plugin is not enabled")
            return
        }

        attemptClickyShellRegistration()
    }

    func refreshClickyShellStatusNow() {
        fetchClickyShellServerStatus()
    }

    func refreshOpenClawAgentIdentity() {
        guard selectedAgentBackend == .openClaw else { return }
        guard !openClawGatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task { @MainActor in
            do {
                let agentIdentitySnapshot = try await openClawGatewayCompanionAgent.fetchAgentIdentity(
                    gatewayURLString: openClawGatewayURL,
                    explicitGatewayAuthToken: openClawGatewayAuthToken,
                    agentIdentifier: openClawAgentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : openClawAgentIdentifier,
                    sessionKey: openClawSessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : openClawSessionKey
                )

                inferredOpenClawAgentIdentityName = agentIdentitySnapshot.name
                inferredOpenClawAgentIdentityEmoji = agentIdentitySnapshot.emoji
                inferredOpenClawAgentIdentityAvatar = agentIdentitySnapshot.avatar
                inferredOpenClawAgentIdentifier = agentIdentitySnapshot.agentIdentifier
                ClickyLogger.info(.gateway, "Fetched OpenClaw identity name=\(agentIdentitySnapshot.name ?? "unknown")")

                if openClawAgentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let inferredAgentIdentifier = agentIdentitySnapshot.agentIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !inferredAgentIdentifier.isEmpty {
                    openClawAgentIdentifier = inferredAgentIdentifier
                }

                if openClawAgentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let inferredAgentIdentityName = agentIdentitySnapshot.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !inferredAgentIdentityName.isEmpty {
                    openClawAgentName = inferredAgentIdentityName
                }
            } catch {
                inferredOpenClawAgentIdentityAvatar = nil
                inferredOpenClawAgentIdentifier = nil
                inferredOpenClawAgentIdentityName = nil
                inferredOpenClawAgentIdentityEmoji = nil
            }
        }
    }

    private func loadLocalOpenClawConfiguration() -> [String: Any]? {
        let openClawHomeDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw", isDirectory: true)
        let configurationFileURL = openClawHomeDirectoryURL.appendingPathComponent("openclaw.json")

        guard let configurationData = try? Data(contentsOf: configurationFileURL),
              let configurationJSON = try? JSONSerialization.jsonObject(with: configurationData) as? [String: Any] else {
            return nil
        }

        return configurationJSON
    }

    private var clickyShellIdentifier: String {
        if let persistedClickyShellIdentifier = UserDefaults.standard.string(forKey: "clickyShellIdentifier"),
           !persistedClickyShellIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return persistedClickyShellIdentifier
        }

        let generatedClickyShellIdentifier = "clicky-shell-\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(generatedClickyShellIdentifier, forKey: "clickyShellIdentifier")
        return generatedClickyShellIdentifier
    }

    private var clickyShellLabel: String {
        let hostName = Host.current().localizedName ?? "This Mac"
        return "Clicky on \(hostName)"
    }

    private var clickyShellBridgeVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var clickyShellRuntimeMode: String {
        #if DEBUG
        return "debug"
        #else
        return "production"
        #endif
    }

    private var shouldAttemptClickyShellRegistration: Bool {
        guard selectedAgentBackend == .openClaw else { return false }
        guard !openClawGatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        if isOpenClawGatewayRemote {
            return true
        }

        return clickyOpenClawPluginStatus == .enabled
    }

    private func refreshClickyShellRegistrationLifecycle() {
        clickyShellHeartbeatTimer?.invalidate()
        clickyShellHeartbeatTimer = nil

        guard shouldAttemptClickyShellRegistration else {
            clickyShellRegistrationStatus = .idle
            clickyShellServerFreshnessState = nil
            clickyShellServerStatusSummary = nil
            clickyShellServerSessionBindingState = nil
            clickyShellServerSessionKey = nil
            clickyShellServerTrustState = nil
            return
        }

        attemptClickyShellRegistration()
    }

    private func attemptClickyShellRegistration() {
        guard shouldAttemptClickyShellRegistration else { return }

        clickyShellRegistrationStatus = .registering

        let shellRegistrationPayload = OpenClawShellRegistrationPayload(
            agentIdentityName: effectiveOpenClawAgentName,
            shellIdentifier: clickyShellIdentifier,
            shellLabel: clickyShellLabel,
            bridgeVersion: clickyShellBridgeVersion,
            cursorPointingProtocol: ClickyShellCapabilities.cursorPointingProtocol,
            capabilities: ClickyShellCapabilities.capabilityIdentifiers,
            clickyShellCapabilityVersion: ClickyShellCapabilities.shellCapabilityVersion,
            clickyPresentationName: effectiveClickyPresentationName,
            personaScope: clickyPersonaScopeMode == .overrideInClicky ? "clicky-local-override" : "openclaw-identity",
            runtimeMode: clickyShellRuntimeMode,
            screenContextTransport: ClickyShellCapabilities.screenContextTransport,
            sessionKey: openClawSessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : openClawSessionKey,
            shellProtocolVersion: ClickyShellCapabilities.shellProtocolVersion,
            speechOutputMode: ClickyShellCapabilities.speechOutputMode,
            supportsInlineTextBubble: ClickyShellCapabilities.supportsInlineTextBubble,
            registeredAtMilliseconds: Int(Date().timeIntervalSince1970 * 1000)
        )

        Task { @MainActor in
            do {
                let summary = try await openClawGatewayCompanionAgent.registerShell(
                    gatewayURLString: openClawGatewayURL,
                    explicitGatewayAuthToken: openClawGatewayAuthToken,
                    payload: shellRegistrationPayload
                )

                clickyShellRegistrationStatus = .registered(summary: summary)
                clickyShellServerFreshnessState = "fresh"
                clickyShellServerStatusSummary = summary
                clickyShellServerSessionBindingState = shellRegistrationPayload.sessionKey == nil ? "unbound" : "bound"
                clickyShellServerSessionKey = shellRegistrationPayload.sessionKey
                clickyShellServerTrustState = isOpenClawGatewayRemote ? "trusted-remote" : "trusted-local"
                ClickyLogger.notice(.plugin, "Clicky shell registered summary=\(summary)")
                startClickyShellHeartbeatTimerIfNeeded()
                fetchClickyShellServerStatus()
            } catch {
                clickyShellRegistrationStatus = .failed(message: error.localizedDescription)
                ClickyLogger.error(.plugin, "Clicky shell registration failed error=\(error.localizedDescription)")
            }
        }
    }

    private func startClickyShellHeartbeatTimerIfNeeded() {
        clickyShellHeartbeatTimer?.invalidate()

        clickyShellHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.sendClickyShellHeartbeat()
            }
        }
    }

    private func sendClickyShellHeartbeat() async {
        guard shouldAttemptClickyShellRegistration else { return }

        do {
            try await openClawGatewayCompanionAgent.sendShellHeartbeat(
                gatewayURLString: openClawGatewayURL,
                explicitGatewayAuthToken: openClawGatewayAuthToken,
                shellIdentifier: clickyShellIdentifier
            )
            ClickyLogger.debug(.plugin, "Clicky shell heartbeat sent shellId=\(clickyShellIdentifier)")
        } catch {
            clickyShellRegistrationStatus = .failed(message: error.localizedDescription)
            ClickyLogger.error(.plugin, "Clicky shell heartbeat failed error=\(error.localizedDescription)")
            attemptClickyShellRegistration()
        }
    }

    private func fetchClickyShellServerStatus() {
        guard shouldAttemptClickyShellRegistration else { return }

        Task { @MainActor in
            do {
                let shellStatusSnapshot = try await openClawGatewayCompanionAgent.fetchShellStatus(
                    gatewayURLString: openClawGatewayURL,
                    explicitGatewayAuthToken: openClawGatewayAuthToken,
                    shellIdentifier: clickyShellIdentifier
                )

                clickyShellServerStatusSummary = shellStatusSnapshot.summary
                clickyShellServerFreshnessState = shellStatusSnapshot.freshnessState
                clickyShellServerSessionBindingState = shellStatusSnapshot.sessionBindingState
                clickyShellServerSessionKey = shellStatusSnapshot.sessionKey
                clickyShellServerTrustState = shellStatusSnapshot.trustState
            } catch {
                clickyShellServerStatusSummary = error.localizedDescription
            }
        }
    }

    private func bindClickyShellSession() {
        guard shouldAttemptClickyShellRegistration else { return }

        Task { @MainActor in
            do {
                let shellStatusSnapshot = try await openClawGatewayCompanionAgent.bindShellSession(
                    gatewayURLString: openClawGatewayURL,
                    explicitGatewayAuthToken: openClawGatewayAuthToken,
                    shellIdentifier: clickyShellIdentifier,
                    sessionKey: openClawSessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : openClawSessionKey
                )

                clickyShellServerStatusSummary = shellStatusSnapshot.summary
                clickyShellServerFreshnessState = shellStatusSnapshot.freshnessState
                clickyShellServerSessionBindingState = shellStatusSnapshot.sessionBindingState
                clickyShellServerSessionKey = shellStatusSnapshot.sessionKey
                clickyShellServerTrustState = shellStatusSnapshot.trustState
            } catch {
                clickyShellRegistrationStatus = .failed(message: error.localizedDescription)
            }
        }
    }

    /// User preference for whether the Clicky cursor should be shown.
    /// When toggled off, the overlay is hidden and push-to-talk is disabled.
    /// Persisted to UserDefaults so the choice survives app restarts.
    var isClickyCursorEnabled: Bool {
        get { preferences.isClickyCursorEnabled }
        set { preferences.isClickyCursorEnabled = newValue }
    }

    func setClickyCursorEnabled(_ enabled: Bool) {
        guard isClickyCursorEnabled != enabled else { return }
        isClickyCursorEnabled = enabled
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.transientHideTask?.cancel()
            self.transientHideTask = nil

            if enabled {
                self.overlayWindowManager.hasShownOverlayBefore = true
                self.overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
                self.isOverlayVisible = true
            } else {
                self.overlayWindowManager.hideOverlay()
                self.isOverlayVisible = false
            }
        }
    }

    /// Whether the user has completed onboarding at least once. Persisted
    /// to UserDefaults so the Start button only appears on first launch.
    var hasCompletedOnboarding: Bool {
        get { preferences.hasCompletedOnboarding }
        set { preferences.hasCompletedOnboarding = newValue }
    }

    func start() {
        ClickyUnifiedTelemetry.lifecycle.info("Companion start began")

        if !CompanionRuntimeConfiguration.isWorkerConfigured && selectedAgentBackend == .claude {
            selectedAgentBackend = .openClaw
            ClickyUnifiedTelemetry.lifecycle.info(
                "Agent backend fallback applied from=Claude to=OpenClaw reason=worker-unconfigured"
            )
        }

        restoreClickyLaunchSessionIfPossible()
        refreshAllPermissions()
        startPermissionPolling()
        bindVoiceStateObservation()
        bindAudioPowerLevel()
        bindShortcutTransitions()
        bindTutorialPlaybackShortcutTransitions()
        // Eagerly touch the Claude API so its TLS warmup handshake completes
        // well before the onboarding demo fires at ~40s into the video.
        if selectedAgentBackend == .claude {
            _ = claudeAPI
        }

        // When the worker is not configured we fall back to Apple Speech,
        // which needs a separate Speech Recognition permission. Request it
        // proactively so the user's first push-to-talk press doesn't get
        // consumed by a permission prompt and feel like a broken hotkey.
        if buddyDictationManager.needsInitialPermissionPrompt {
            Task { @MainActor in
                await buddyDictationManager.requestInitialPushToTalkPermissionsIfNeeded()
            }
        }

        refreshClickyShellRegistrationLifecycle()
        refreshOpenClawAgentIdentity()
        refreshCodexRuntimeStatus()

        // If the user already completed onboarding AND all permissions are
        // still granted, show the cursor overlay immediately. If permissions
        // were revoked (e.g. signing change), don't show the cursor — the
        // panel will show the permissions UI instead.
        if hasCompletedOnboarding && allPermissionsGranted && isClickyCursorEnabled {
            overlayWindowManager.hasShownOverlayBefore = true
            overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
            isOverlayVisible = true
        }

        ClickyUnifiedTelemetry.lifecycle.info(
            "Companion start completed backend=\(self.selectedAgentBackend.displayName, privacy: .public) permissions=\(self.allPermissionsGranted ? "ready" : "needs-attention", privacy: .public) onboarding=\(self.hasCompletedOnboarding ? "complete" : "pending", privacy: .public) overlay=\(self.isOverlayVisible ? "shown" : "hidden", privacy: .public)"
        )
    }

    /// Called by BlueCursorView after the buddy finishes its pointing
    /// animation and returns to cursor-following mode.
    /// Triggers the onboarding sequence — dismisses the panel and restarts
    /// the overlay so the welcome animation and intro video play.
    func triggerOnboarding() {
        // Post notification so the panel manager can dismiss the panel
        NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)

        // Mark onboarding as completed so the Start button won't appear
        // again on future launches — the cursor will auto-show instead
        hasCompletedOnboarding = true

        ClickyAnalytics.trackOnboardingStarted()

        // Play Besaid theme at 60% volume, fade out after 1m 30s
        startOnboardingMusic()

        // Show the overlay for the first time — isFirstAppearance triggers
        // the welcome animation and onboarding video
        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
        isOverlayVisible = true
    }

    /// Replays the onboarding experience from the "Watch Onboarding Again"
    /// footer link. Same flow as triggerOnboarding but the cursor overlay
    /// is already visible so we just restart the welcome animation and video.
    func replayOnboarding() {
        NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)
        ClickyAnalytics.trackOnboardingReplayed()
        startOnboardingMusic()
        // Tear down any existing overlays and recreate with isFirstAppearance = true
        overlayWindowManager.hasShownOverlayBefore = false
        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
        isOverlayVisible = true
    }

    private func stopOnboardingMusic() {
        onboardingMusicFadeTimer?.invalidate()
        onboardingMusicFadeTimer = nil
        onboardingMusicPlayer?.stop()
        onboardingMusicPlayer = nil
        onboardingPromptTask?.cancel()
        onboardingPromptTask = nil
    }

    private func startOnboardingMusic() {
        stopOnboardingMusic()
        guard let musicURL = Bundle.main.url(forResource: "ff", withExtension: "mp3") else {
            print("⚠️ Clicky: ff.mp3 not found in bundle")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: musicURL)
            player.volume = 0.3
            player.play()
            self.onboardingMusicPlayer = player

            // After 1m 30s, fade the music out over 3s
            onboardingMusicFadeTimer = Timer.scheduledTimer(withTimeInterval: 90.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.fadeOutOnboardingMusic()
                }
            }
        } catch {
            print("⚠️ Clicky: Failed to play onboarding music: \(error)")
        }
    }

    private func fadeOutOnboardingMusic() {
        guard let player = onboardingMusicPlayer else { return }

        let fadeSteps = 30
        let fadeDuration: Double = 3.0
        let volumeDecrement = player.volume / Float(fadeSteps)
        let stepDurationNanoseconds = UInt64((fadeDuration / Double(fadeSteps)) * 1_000_000_000)

        onboardingMusicFadeTimer?.invalidate()
        onboardingMusicFadeTimer = nil

        Task { @MainActor [weak self] in
            guard let self else { return }

            for _ in 0..<fadeSteps {
                guard let currentPlayer = self.onboardingMusicPlayer, currentPlayer === player else {
                    return
                }

                currentPlayer.volume -= volumeDecrement
                try? await Task.sleep(nanoseconds: stepDurationNanoseconds)
            }

            guard let currentPlayer = self.onboardingMusicPlayer, currentPlayer === player else { return }
            currentPlayer.stop()
            self.onboardingMusicPlayer = nil
        }
    }

    func clearDetectedElementLocation() {
        pendingDetectedElementTargets.removeAll()
        pendingManagedPointNarrationSteps.removeAll()
        pointTargetArrivalContinuation?.resume()
        pointTargetArrivalContinuation = nil
        isManagedPointSequenceActive = false
        detectedElementScreenLocation = nil
        detectedElementDisplayFrame = nil
        detectedElementBubbleText = nil
    }

    func advanceDetectedElementLocation() {
        guard !pendingDetectedElementTargets.isEmpty else {
            clearDetectedElementLocation()
            return
        }

        let nextTarget = pendingDetectedElementTargets.removeFirst()
        detectedElementBubbleText = nextTarget.bubbleText
        detectedElementDisplayFrame = nextTarget.displayFrame
        detectedElementScreenLocation = nextTarget.screenLocation
        ClickyAnalytics.trackElementPointed(elementLabel: nextTarget.elementLabel)
    }

    private func queueDetectedElementTargets(_ targets: [QueuedPointingTarget]) {
        pendingDetectedElementTargets = Array(targets.dropFirst())

        guard let firstTarget = targets.first else {
            clearDetectedElementLocation()
            return
        }

        detectedElementBubbleText = firstTarget.bubbleText
        detectedElementDisplayFrame = firstTarget.displayFrame
        detectedElementScreenLocation = firstTarget.screenLocation
        ClickyAnalytics.trackElementPointed(elementLabel: firstTarget.elementLabel)
    }

    var hasPendingDetectedElementTargets: Bool {
        !pendingDetectedElementTargets.isEmpty
    }

    var isManagingPointSequence: Bool {
        isManagedPointSequenceActive
    }

    func notifyManagedPointTargetArrived() {
        pointTargetArrivalContinuation?.resume()
        pointTargetArrivalContinuation = nil
    }

    private func waitForManagedPointTargetArrival() async {
        await withCheckedContinuation { continuation in
            pointTargetArrivalContinuation = continuation
        }
    }

    private func requestManagedPointSequenceReturn() {
        isManagedPointSequenceActive = false
        managedPointSequenceReturnToken += 1
    }

    private func bubbleTextForPoint(_ point: ClickyAssistantResponsePoint) -> String {
        let trimmedLabel = point.label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBubbleText = point.bubbleText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let genericBubbleTexts = Set([
            "screen",
            "display",
            "controls",
            "control",
            "wheel",
            "panel",
            "seat",
            "seats",
            "light",
        ])

        if trimmedBubbleText.isEmpty {
            return trimmedLabel
        }

        if genericBubbleTexts.contains(trimmedBubbleText.lowercased()),
           !trimmedLabel.isEmpty {
            return friendlyBubbleDisplayText(from: trimmedLabel)
        }

        if trimmedBubbleText.isEmpty {
            return friendlyBubbleDisplayText(from: trimmedLabel)
        }

        return friendlyBubbleDisplayText(from: trimmedBubbleText)
    }

    private func transcriptWantsNarratedWalkthrough(_ transcript: String) -> Bool {
        let normalizedTranscript = transcript.lowercased()
        let walkthroughSignals = [
            "walk me through",
            "walk-through",
            "walkthrough",
            "walk through",
            "give me a walkthrough",
            "give me a walk-through",
            "talk about a few features",
            "point them out",
            "few features",
            "tour",
            "breakdown",
            "overview",
            "what do they do",
            "how to use them",
            "how to use",
            "how climate controls work",
            "what are these buttons",
            "interior",
        ]

        return walkthroughSignals.contains { normalizedTranscript.contains($0) }
    }

    private func resolvedPointingTargets(
        from parsedTargets: [ParsedPointingTarget],
        screenCaptures: [CompanionScreenCapture]
    ) -> [QueuedPointingTarget] {
        parsedTargets.compactMap { parsedTarget in
            guard let targetScreenCapture = targetScreenCapture(
                for: parsedTarget.screenNumber,
                screenCaptures: screenCaptures
            ) else {
                return nil
            }

            let globalLocation = globalLocation(
                for: parsedTarget.coordinate,
                in: targetScreenCapture
            )

            return QueuedPointingTarget(
                screenLocation: globalLocation,
                displayFrame: targetScreenCapture.displayFrame,
                elementLabel: parsedTarget.elementLabel,
                bubbleText: parsedTarget.bubbleText
            )
        }
    }

    private func parsedPointingTargets(
        from responsePoints: [ClickyAssistantResponsePoint]
    ) -> [ParsedPointingTarget] {
        responsePoints.map { responsePoint in
            ParsedPointingTarget(
                coordinate: CGPoint(x: responsePoint.x, y: responsePoint.y),
                elementLabel: responsePoint.label,
                screenNumber: responsePoint.screenNumber,
                bubbleText: bubbleTextForPoint(responsePoint)
            )
        }
    }

    private func managedPointNarrationSteps(
        from responsePoints: [ClickyAssistantResponsePoint]
    ) -> [ManagedPointNarrationStep] {
        let explicitSteps: [ManagedPointNarrationStep] = responsePoints.compactMap { responsePoint -> ManagedPointNarrationStep? in
            let trimmedExplanation = responsePoint.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedExplanation.isEmpty else { return nil }
            return ManagedPointNarrationStep(spokenText: trimmedExplanation)
        }

        if explicitSteps.count == responsePoints.count {
            return explicitSteps
        }

        return responsePoints.map { responsePoint in
            ManagedPointNarrationStep(
                spokenText: fallbackNarrationText(for: responsePoint)
            )
        }
    }

    private func waitForSpeechPlaybackToFinishIfNeeded() async {
        await elevenLabsTTSClient.waitUntilPlaybackFinishes()
    }

    private func playManagedPointSequence(
        introText: String,
        responsePoints: [ClickyAssistantResponsePoint],
        resolvedTargets: [QueuedPointingTarget]
    ) async {
        let narrationSteps = managedPointNarrationSteps(from: responsePoints)
        guard !narrationSteps.isEmpty, narrationSteps.count == resolvedTargets.count else {
            return
        }

        let hasExplicitPerPointNarration = responsePoints.allSatisfy { responsePoint in
            let trimmedExplanation = responsePoint.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !trimmedExplanation.isEmpty
        }

        if hasExplicitPerPointNarration,
           !introText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let playbackOutcome = await playSpeechText(
                introText,
                purpose: .assistantResponse
            )
            if playbackOutcome.finalProviderDisplayName == "Unavailable" {
                return
            }
            await waitForSpeechPlaybackToFinishIfNeeded()
        }

        isManagedPointSequenceActive = true
        pendingManagedPointNarrationSteps = Array(narrationSteps.dropFirst())
        queueDetectedElementTargets(resolvedTargets)

        for (index, narrationStep) in narrationSteps.enumerated() {
            await waitForManagedPointTargetArrival()

            let playbackOutcome = await playSpeechText(
                narrationStep.spokenText,
                purpose: .assistantResponse
            )
            if playbackOutcome.finalProviderDisplayName == "Unavailable" {
                requestManagedPointSequenceReturn()
                return
            }
            await waitForSpeechPlaybackToFinishIfNeeded()

            if index < narrationSteps.count - 1 {
                advanceDetectedElementLocation()
            } else {
                requestManagedPointSequenceReturn()
            }
        }
    }

    private func fallbackNarrationText(for point: ClickyAssistantResponsePoint) -> String {
        let label = point.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch label {
        case let value where value.contains("climate control"):
            return "this whole panel is the climate control section."
        case let value where value.contains("driver temperature"):
            return "this adjusts the driver temperature."
        case let value where value.contains("passenger temperature"):
            return "this adjusts the passenger temperature."
        case let value where value.contains("fan speed"):
            return "these controls change the fan speed."
        case let value where value.contains("hazard"):
            return "this is the hazard light button."
        case let value where value.contains("front defogger"):
            return "this clears the front windshield."
        case let value where value.contains("rear defogger"):
            return "this clears the rear window."
        case let value where value.contains("air recirculation"):
            return "this recirculates the air inside the cabin."
        case let value where value.contains("airflow"):
            return "this changes where the air blows."
        case let value where value == "sync":
            return "this syncs both sides together."
        case let value where value == "ac":
            return "this turns the cooling on or off."
        case let value where value.contains("auto mode"):
            return "this lets the car manage the climate automatically."
        case let value where value.contains("panoramic sunroof"):
            return "this is the panoramic sunroof."
        case let value where value.contains("infotainment screen"):
            return "this is the infotainment screen."
        case let value where value.contains("center air vents"):
            return "these are the center air vents."
        case let value where value.contains("steering wheel"):
            return "this is the steering wheel."
        case let value where value.contains("driver display"):
            return "this is the driver display."
        case let value where value.contains("horn"):
            return "this center pad is the horn."
        case let value where value.contains("phone button"):
            return "this button handles calls."
        case let value where value.contains("voice assistant button"):
            return "this button triggers the voice assistant."
        case let value where value.contains("left steering buttons"):
            return "this cluster handles media and phone controls."
        case let value where value.contains("call and voice controls"):
            return "these buttons handle calls and voice assistant."
        case let value where value.contains("volume and track controls"):
            return "these buttons adjust volume and tracks."
        case let value where value.contains("mode button"):
            return "this usually switches mode or source."
        case let value where value.contains("back or hangup"):
            return "this is usually back or hang up."
        case let value where value.contains("right steering buttons"):
            return "this cluster handles driving and display controls."
        case let value where value.contains("cruise control"):
            return "these are the cruise control buttons."
        case let value where value.contains("speed set resume"):
            return "this is usually for set and resume."
        case let value where value.contains("display navigation"):
            return "this moves through the driver display."
        case let value where value.contains("driver instrument display"):
            return "this is the driver instrument display."
        case let value where value.contains("gearshift"):
            return "this is the gearshift."
        case let value where value.contains("ambient lighting"):
            return "this is the ambient lighting strip."
        case let value where value.contains("front seats"):
            return "these are the front seats."
        default:
            return "this is the \(label)."
        }
    }

    private func friendlyBubbleDisplayText(from sourceText: String) -> String {
        let trimmedSourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSourceText.isEmpty else { return sourceText }

        let replacements: [String: String] = [
            "ac": "A/C",
            "recirc": "Recirculation",
            "driver temp": "Driver Temp",
            "passenger temp": "Passenger Temp",
            "auto": "Auto Mode",
            "climate": "Climate Panel",
            "fan": "Fan Speed",
            "screen": "Center Screen",
            "wheel": "Steering Wheel",
            "light": "Ambient Light",
            "voice": "Voice Assist",
            "calls": "Call Control",
            "display": "Driver Display",
            "cruise": "Cruise Control",
            "back": "Back / End",
            "mode": "Source Mode",
            "media": "Media Control",
            "set resume": "Set / Resume",
            "hazard": "Hazard Lights",
            "front defog": "Front Defog",
            "rear defog": "Rear Defog",
            "airflow": "Airflow Mode",
        ]

        let loweredSourceText = trimmedSourceText.lowercased()
        if let replacement = replacements[loweredSourceText] {
            return replacement
        }

        return trimmedSourceText
            .split(separator: " ")
            .map { word in
                let loweredWord = word.lowercased()
                if loweredWord == "ac" {
                    return "A/C"
                }
                return loweredWord.prefix(1).uppercased() + loweredWord.dropFirst()
            }
            .joined(separator: " ")
    }

    private func targetScreenCapture(
        for screenNumber: Int?,
        screenCaptures: [CompanionScreenCapture]
    ) -> CompanionScreenCapture? {
        if let screenNumber,
           screenNumber >= 1 && screenNumber <= screenCaptures.count {
            return screenCaptures[screenNumber - 1]
        }

        return screenCaptures.first(where: { $0.isCursorScreen })
    }

    private func globalLocation(
        for pointCoordinate: CGPoint,
        in screenCapture: CompanionScreenCapture
    ) -> CGPoint {
        let screenshotWidth = CGFloat(screenCapture.screenshotWidthInPixels)
        let screenshotHeight = CGFloat(screenCapture.screenshotHeightInPixels)
        let displayWidth = CGFloat(screenCapture.displayWidthInPoints)
        let displayHeight = CGFloat(screenCapture.displayHeightInPoints)
        let displayFrame = screenCapture.displayFrame

        let clampedX = max(0, min(pointCoordinate.x, screenshotWidth))
        let clampedY = max(0, min(pointCoordinate.y, screenshotHeight))
        let displayLocalX = clampedX * (displayWidth / screenshotWidth)
        let displayLocalY = clampedY * (displayHeight / screenshotHeight)
        let appKitY = displayHeight - displayLocalY

        return CGPoint(
            x: displayLocalX + displayFrame.origin.x,
            y: appKitY + displayFrame.origin.y
        )
    }

    func startTutorialImportFromPanel() {
        let trimmedURL = tutorialImportURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            tutorialImportStatusMessage = "Paste a YouTube URL to begin."
            return
        }

        guard let storedSession = ClickyAuthSessionStore.load() else {
            tutorialImportStatusMessage = "Sign in to import tutorials."
            return
        }

        guard let url = URL(string: trimmedURL),
              let host = url.host?.lowercased(),
              ["youtube.com", "www.youtube.com", "youtu.be", "music.youtube.com"].contains(host) else {
            tutorialImportStatusMessage = "That doesn’t look like a valid YouTube URL."
            return
        }

        tutorialImportTask?.cancel()
        isTutorialImportRunning = true
        tutorialImportStatusMessage = "Importing tutorial…"

        var draft = TutorialImportDraft(sourceURL: trimmedURL, status: .extracting)
        currentTutorialImportDraft = draft

        tutorialImportTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let client = TutorialExtractionClient(
                    baseURL: clickyBackendBaseURL,
                    sessionToken: storedSession.sessionToken
                )
                let startResponse = try await client.startExtraction(sourceURL: trimmedURL)
                draft.videoID = startResponse.videoID
                draft.extractionJobID = startResponse.jobID
                draft.updatedAt = Date()
                self.currentTutorialImportDraft = draft
                self.tutorialImportStatusMessage = "Extracting tutorial structure…"

                let snapshot = try await self.pollTutorialExtractionJob(
                    client: client,
                    jobID: startResponse.jobID
                )

                guard snapshot.status == "success" else {
                    throw TutorialExtractionClientError.unexpectedStatus(
                        code: 500,
                        message: snapshot.error ?? "Tutorial extraction failed."
                    )
                }

                let evidenceBundle = try await client.fetchEvidence(videoID: startResponse.videoID)
                draft.videoID = evidenceBundle.videoID
                draft.title = evidenceBundle.source.title
                draft.embedURL = evidenceBundle.source.embedURL
                draft.channelName = evidenceBundle.source.channel
                draft.durationSeconds = evidenceBundle.source.durationSeconds
                draft.thumbnailURL = evidenceBundle.source.thumbnailURL
                draft.evidenceBundle = evidenceBundle
                draft.status = .extracted
                draft.updatedAt = Date()
                self.currentTutorialImportDraft = draft
                self.tutorialImportStatusMessage = "Compiling tutorial steps…"

                draft.status = .compiling
                draft.updatedAt = Date()
                self.currentTutorialImportDraft = draft

                let compiledLessonDraft = try await self.compileTutorialLessonDraft(
                    evidenceBundle: evidenceBundle
                )
                draft.compiledLessonDraft = compiledLessonDraft
                draft.status = .ready
                draft.updatedAt = Date()
                self.currentTutorialImportDraft = draft
                self.tutorialSessionState = TutorialSessionState(
                    draftID: draft.id,
                    lessonDraft: compiledLessonDraft,
                    evidenceBundle: evidenceBundle,
                    currentStepIndex: 0,
                    isActive: false
                )
                self.tutorialConversationHistory = []
                self.isTutorialImportRunning = false
                self.tutorialImportStatusMessage = "Tutorial ready."
            } catch {
                draft.status = .failed
                draft.extractionError = error.localizedDescription
                draft.updatedAt = Date()
                self.currentTutorialImportDraft = draft
                self.isTutorialImportRunning = false
                self.tutorialImportStatusMessage = error.localizedDescription
            }
        }
    }

    func startTutorialLessonFromReadyState() {
        guard var tutorialSessionState else { return }
        guard let lessonDraft = currentTutorialImportDraft?.compiledLessonDraft else { return }
        guard lessonDraft.steps.indices.contains(tutorialSessionState.currentStepIndex) else { return }

        tutorialSessionState.isActive = true
        self.tutorialSessionState = tutorialSessionState

        let currentStep = lessonDraft.steps[tutorialSessionState.currentStepIndex]
        let promptTimestamp = currentStep.sourceVideoPromptTimestamp
            ?? tutorialSessionState.evidenceBundle.structureMarkers.first?.visualAnchorTimestamps.first

        startTutorialPlayback(
            sourceURL: tutorialSessionState.evidenceBundle.source.url,
            embedURL: tutorialSessionState.evidenceBundle.source.embedURL,
            step: currentStep,
            bubbleText: "\(currentStep.title). \(currentStep.instruction)",
            promptTimestampSeconds: promptTimestamp,
            autoPlay: true
        )
    }

    func advanceTutorialLessonFromPanel() {
        guard var tutorialSessionState else { return }
        let lessonDraft = tutorialSessionState.lessonDraft
        guard tutorialSessionState.currentStepIndex + 1 < lessonDraft.steps.count else { return }

        tutorialSessionState.currentStepIndex += 1
        tutorialSessionState.isActive = true
        self.tutorialSessionState = tutorialSessionState

        let nextStep = lessonDraft.steps[tutorialSessionState.currentStepIndex]
        updateTutorialPlaybackState(step: nextStep, isPlaying: true)
    }

    func rewindTutorialLessonFromPanel() {
        guard var tutorialSessionState else { return }
        let lessonDraft = tutorialSessionState.lessonDraft
        guard tutorialSessionState.currentStepIndex > 0 else { return }

        tutorialSessionState.currentStepIndex -= 1
        tutorialSessionState.isActive = true
        self.tutorialSessionState = tutorialSessionState

        let currentStep = lessonDraft.steps[tutorialSessionState.currentStepIndex]
        updateTutorialPlaybackState(step: currentStep, isPlaying: true)
    }

    func repeatTutorialLessonStepFromPanel() {
        guard let tutorialSessionState else { return }
        let lessonDraft = tutorialSessionState.lessonDraft
        guard lessonDraft.steps.indices.contains(tutorialSessionState.currentStepIndex) else { return }

        let currentStep = lessonDraft.steps[tutorialSessionState.currentStepIndex]
        updateTutorialPlaybackState(step: currentStep, isPlaying: true)
    }

    func retryTutorialImportFromPanel() {
        startTutorialImportFromPanel()
    }

    private func pollTutorialExtractionJob(
        client: TutorialExtractionClient,
        jobID: String
    ) async throws -> TutorialExtractionJobSnapshot {
        while true {
            try Task.checkCancellation()
            let snapshot = try await client.fetchJob(jobID: jobID)
            if snapshot.status == "success" || snapshot.status == "error" {
                return snapshot
            }
            try await Task.sleep(for: .seconds(1))
        }
    }

    private func compileTutorialLessonDraft(
        evidenceBundle: TutorialEvidenceBundle
    ) async throws -> TutorialLessonDraft {
        struct TutorialLessonDraftEnvelope: Decodable {
            let title: String
            let summary: String
            let steps: [TutorialLessonDraftStep]
        }

        struct TutorialLessonDraftStep: Decodable {
            let title: String
            let instruction: String
            let verificationHint: String?
            let sourceStartSeconds: Double?
            let sourceEndSeconds: Double?
            let sourceVideoPromptTimestamp: Int?
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let evidenceJSONData = try encoder.encode(evidenceBundle)
        let evidenceJSONString = String(decoding: evidenceJSONData, as: UTF8.self)

        let systemPrompt = """
        You are compiling a desktop software tutorial for Clicky.

        Return JSON only. No markdown. No prose outside JSON.

        Produce:
        {
          "title": string,
          "summary": string,
          "steps": [
            {
              "title": string,
              "instruction": string,
              "verificationHint": string | null,
              "sourceStartSeconds": number | null,
              "sourceEndSeconds": number | null,
              "sourceVideoPromptTimestamp": number | null
            }
          ]
        }

        Rules:
        - write for a learner following along on their own desktop
        - make each step concrete and actionable
        - prefer six to ten meaningful steps
        - keep titles short
        - keep instructions conversational but clear
        - use the evidence bundle only
        - if structure markers exist, use them to shape the lesson
        - sourceVideoPromptTimestamp should usually point to the most relevant moment for that step
        """

        let userPrompt = """
        Turn this extracted YouTube tutorial evidence into a guided desktop lesson for Clicky.

        Evidence bundle:
        \(evidenceJSONString)
        """

        let request = ClickyAssistantTurnRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            conversationHistory: [],
            imageAttachments: [],
            focusContext: nil
        )

        let response = try await assistantTurnExecutor.execute(
            ClickyAssistantTurnPlan(
                backend: selectedAgentBackend,
                systemPrompt: systemPrompt,
                request: request
            ),
            onTextChunk: { _ in }
        )

        let responseText = response.text
        let normalizedJSONText = Self.extractJSONObject(from: responseText)
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(
            TutorialLessonDraftEnvelope.self,
            from: Data(normalizedJSONText.utf8)
        )

        return TutorialLessonDraft(
            title: envelope.title,
            summary: envelope.summary,
            steps: envelope.steps.map { step in
                TutorialLessonStep(
                    title: step.title,
                    instruction: step.instruction,
                    verificationHint: step.verificationHint,
                    sourceTimeRange: {
                        guard let start = step.sourceStartSeconds,
                              let end = step.sourceEndSeconds else { return nil }
                        return TutorialLessonTimeRange(startSeconds: start, endSeconds: end)
                    }(),
                    sourceVideoPromptTimestamp: step.sourceVideoPromptTimestamp
                )
            },
            createdAt: Date()
        )
    }

    private static func extractJSONObject(from responseText: String) -> String {
        guard let startIndex = responseText.firstIndex(of: "{"),
              let endIndex = responseText.lastIndex(of: "}") else {
            return responseText
        }

        return String(responseText[startIndex...endIndex])
    }

    func startTutorialPlayback(
        sourceURL: String,
        embedURL: String,
        step: TutorialLessonStep? = nil,
        bubbleText: String? = nil,
        promptTimestampSeconds: Int? = nil,
        autoPlay: Bool = true
    ) {
        tutorialPlaybackState = TutorialPlaybackBindingState(
            sourceURL: sourceURL,
            embedURL: embedURL,
            currentStepID: step?.id,
            currentStepTitle: step?.title,
            bubbleText: bubbleText ?? "Space play/pause  Left back 10s  Right forward 10s  Esc close",
            isPlaying: autoPlay,
            isVisible: true,
            surfaceMode: .inlineVideoWithBubble,
            resumeBehavior: .resumeInlineVideoAfterPointing,
            preferredInlinePlayerWidth: 330,
            preferredInlinePlayerHeight: 186,
            lastPromptTimestampSeconds: promptTimestampSeconds,
            showsKeyboardShortcutsHint: true
        )
        tutorialPlaybackBubbleOpacity = 1.0
        if autoPlay {
            sendTutorialPlaybackCommand(.play)
        }
    }

    private func updateTutorialPlaybackState(step: TutorialLessonStep, isPlaying: Bool) {
        if tutorialPlaybackState == nil {
            guard let tutorialSessionState else { return }
            startTutorialPlayback(
                sourceURL: tutorialSessionState.evidenceBundle.source.url,
                embedURL: tutorialSessionState.evidenceBundle.source.embedURL,
                step: step,
                bubbleText: "\(step.title). \(step.instruction)",
                promptTimestampSeconds: step.sourceVideoPromptTimestamp,
                autoPlay: isPlaying
            )
            return
        }

        tutorialPlaybackState?.currentStepID = step.id
        tutorialPlaybackState?.currentStepTitle = step.title
        tutorialPlaybackState?.bubbleText = "\(step.title). \(step.instruction)"
        tutorialPlaybackState?.surfaceMode = .inlineVideoWithBubble
        tutorialPlaybackState?.lastPromptTimestampSeconds = step.sourceVideoPromptTimestamp
        tutorialPlaybackState?.isPlaying = isPlaying
        tutorialPlaybackBubbleOpacity = 1.0

        if isPlaying {
            sendTutorialPlaybackCommand(.play)
        }
    }

    func updateTutorialPlaybackBubble(_ text: String?) {
        guard var state = tutorialPlaybackState else { return }
        state.showsKeyboardShortcutsHint = false
        state.bubbleText = text
        state.surfaceMode = text == nil ? .inlineVideo : .inlineVideoWithBubble
        tutorialPlaybackState = state
        tutorialPlaybackBubbleOpacity = text == nil ? 0.0 : 1.0
    }

    func pauseTutorialPlaybackForPointing() {
        guard var state = tutorialPlaybackState else { return }
        state.surfaceMode = .pointerGuidance
        tutorialPlaybackState = state
        tutorialPlaybackBubbleOpacity = 0.0
        sendTutorialPlaybackCommand(.pause)
    }

    func resumeTutorialPlaybackAfterPointingIfNeeded() {
        guard var state = tutorialPlaybackState else { return }
        guard state.resumeBehavior == .resumeInlineVideoAfterPointing else { return }

        state.surfaceMode = state.bubbleText == nil ? .inlineVideo : .inlineVideoWithBubble
        tutorialPlaybackState = state
        tutorialPlaybackBubbleOpacity = state.bubbleText == nil ? 0.0 : 1.0
        if state.isPlaying {
            sendTutorialPlaybackCommand(.play)
        }
    }

    func stopTutorialPlayback() {
        tutorialPlaybackBubbleOpacity = 0.0
        tutorialPlaybackState = nil
        sendTutorialPlaybackCommand(.dismiss)
    }

    func handleTutorialPlaybackKeyboardCommand(_ command: TutorialPlaybackCommand) {
        guard var state = tutorialPlaybackState, state.isVisible else { return }

        switch command {
        case .play:
            state.isPlaying = true
        case .pause:
            state.isPlaying = false
        case .togglePlayPause:
            state.isPlaying.toggle()
        case .seekBackward, .seekForward:
            break
        case .dismiss:
            tutorialPlaybackState = nil
            tutorialPlaybackBubbleOpacity = 0.0
        }

        if command != .dismiss {
            if state.showsKeyboardShortcutsHint {
                state.showsKeyboardShortcutsHint = false
                if let currentStepTitle = state.currentStepTitle,
                   !currentStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.bubbleText = currentStepTitle
                    state.surfaceMode = .inlineVideoWithBubble
                } else if state.bubbleText?.contains("Space play/pause") == true {
                    state.bubbleText = nil
                    state.surfaceMode = .inlineVideo
                }
            }
            tutorialPlaybackState = state
        }

        sendTutorialPlaybackCommand(command)
    }

    private func sendTutorialPlaybackCommand(_ command: TutorialPlaybackCommand) {
        tutorialPlaybackLastCommand = command
        tutorialPlaybackCommandNonce += 1
    }

    func stop() {
        globalPushToTalkShortcutMonitor.stop()
        buddyDictationManager.cancelCurrentDictation()
        overlayWindowManager.hideOverlay()
        stopTutorialPlayback()
        transientHideTask?.cancel()
        quietLaunchEntitlementRefreshTask?.cancel()
        quietLaunchEntitlementRefreshTask = nil
        clickyShellHeartbeatTimer?.invalidate()
        clickyShellHeartbeatTimer = nil

        currentResponseTask?.cancel()
        currentResponseTask = nil
        shortcutTransitionCancellable?.cancel()
        voiceStateCancellable?.cancel()
        audioPowerCancellable?.cancel()
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = nil
    }

    private var clickyBackendAuthClient: ClickyBackendAuthClient {
        ClickyBackendAuthClient(baseURL: clickyBackendBaseURL)
    }

    private func makeLaunchEntitlementSnapshot(
        from payload: ClickyBackendEntitlementPayload
    ) -> ClickyLaunchEntitlementSnapshot {
        ClickyLaunchEntitlementSnapshot(
            productKey: payload.productKey,
            status: payload.status,
            hasAccess: payload.hasAccess,
            gracePeriodEndsAt: payload.gracePeriodEndsAt
        )
    }

    private func makeLaunchTrialSnapshot(
        from payload: ClickyBackendTrialPayload
    ) -> ClickyLaunchTrialSnapshot {
        ClickyLaunchTrialSnapshot(
            status: payload.status,
            initialCredits: payload.initialCredits,
            remainingCredits: payload.remainingCredits,
            setupCompletedAt: payload.setupCompletedAt,
            trialActivatedAt: payload.trialActivatedAt,
            lastCreditConsumedAt: payload.lastCreditConsumedAt,
            welcomePromptDeliveredAt: payload.welcomePromptDeliveredAt,
            paywallActivatedAt: payload.paywallActivatedAt
        )
    }

    private func updatedLaunchSessionSnapshot(
        from storedSession: ClickyAuthSessionSnapshot,
        userID: String? = nil,
        email: String? = nil,
        entitlement: ClickyLaunchEntitlementSnapshot? = nil,
        trial: ClickyLaunchTrialSnapshot? = nil
    ) -> ClickyAuthSessionSnapshot {
        ClickyAuthSessionSnapshot(
            sessionToken: storedSession.sessionToken,
            userID: userID ?? storedSession.userID,
            email: email ?? storedSession.email,
            name: storedSession.name,
            image: storedSession.image,
            entitlement: entitlement ?? storedSession.entitlement,
            trial: trial ?? storedSession.trial
        )
    }

    private func launchAuthStateName(_ state: ClickyLaunchAuthState) -> String {
        switch state {
        case .signedOut:
            return "signed-out"
        case .restoring:
            return "restoring"
        case .signingIn:
            return "signing-in"
        case .signedIn:
            return "signed-in"
        case .failed:
            return "failed"
        }
    }

    private func launchBillingStateName(_ state: ClickyLaunchBillingState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .openingCheckout:
            return "opening-checkout"
        case .waitingForCompletion:
            return "waiting-for-completion"
        case .canceled:
            return "canceled"
        case .completed:
            return "completed"
        case .failed:
            return "failed"
        }
    }

    private func launchTrialStateName(_ state: ClickyLaunchTrialState) -> String {
        switch state {
        case .inactive:
            return "inactive"
        case .active:
            return "active"
        case .armed:
            return "armed"
        case .paywalled:
            return "paywalled"
        case .unlocked:
            return "unlocked"
        case .failed:
            return "failed"
        }
    }

    private func setLaunchAuthState(_ newState: ClickyLaunchAuthState, reason: String) {
        let previousState = clickyLaunchAuthState
        clickyLaunchAuthState = newState

        guard previousState != newState else { return }

        ClickyUnifiedTelemetry.launchAuth.info(
            "Launch auth state state=\(self.launchAuthStateName(newState), privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    private func entitlementGraceEndDate(
        _ entitlement: ClickyLaunchEntitlementSnapshot
    ) -> Date? {
        guard let gracePeriodEndsAt = entitlement.gracePeriodEndsAt,
              !gracePeriodEndsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return ISO8601DateFormatter().date(from: gracePeriodEndsAt)
    }

    private func launchEntitlementHasEffectiveAccess(
        _ entitlement: ClickyLaunchEntitlementSnapshot
    ) -> Bool {
        guard entitlement.hasAccess else {
            return false
        }

        guard let graceEndDate = entitlementGraceEndDate(entitlement) else {
            return true
        }

        return graceEndDate > Date()
    }

    private func launchEntitlementRequiresRepurchase(
        _ entitlement: ClickyLaunchEntitlementSnapshot
    ) -> Bool {
        let normalizedStatus = entitlement.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !launchEntitlementHasEffectiveAccess(entitlement) else {
            return false
        }

        return normalizedStatus == "refunded" || normalizedStatus == "revoked"
    }

    private func launchEntitlementGraceExpired(
        _ entitlement: ClickyLaunchEntitlementSnapshot
    ) -> Bool {
        entitlement.hasAccess && !launchEntitlementHasEffectiveAccess(entitlement)
    }

    private func setLaunchBillingState(_ newState: ClickyLaunchBillingState, reason: String) {
        let previousState = clickyLaunchBillingState
        clickyLaunchBillingState = newState

        guard previousState != newState else { return }

        ClickyUnifiedTelemetry.billing.info(
            "Billing state state=\(self.launchBillingStateName(newState), privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    private func setLaunchTrialState(_ newState: ClickyLaunchTrialState, reason: String) {
        let previousState = clickyLaunchTrialState
        clickyLaunchTrialState = newState

        guard previousState != newState else { return }

        ClickyUnifiedTelemetry.billing.info(
            "Launch trial state state=\(self.launchTrialStateName(newState), privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    private func persistLaunchSessionSnapshot(_ snapshot: ClickyAuthSessionSnapshot, reason: String) throws {
        try ClickyAuthSessionStore.save(snapshot)
        setLaunchAuthState(.signedIn(email: snapshot.email), reason: reason)
        clickyLaunchProfileName = snapshot.name ?? ""
        clickyLaunchProfileImageURL = snapshot.image ?? ""
        clickyLaunchEntitlementStatusLabel = formatEntitlementStatus(snapshot.entitlement)
        setLaunchTrialState(formatLaunchTrialState(
            snapshot.trial,
            hasAccess: launchEntitlementHasEffectiveAccess(snapshot.entitlement)
        ), reason: reason)
    }

    private func loadLaunchEntitlement(
        sessionToken: String,
        mode: ClickyLaunchEntitlementSyncMode
    ) async throws -> ClickyBackendEntitlementPayload {
        switch mode {
        case .current:
            return try await clickyBackendAuthClient.fetchCurrentEntitlement(
                sessionToken: sessionToken
            ).entitlement
        case .refresh:
            return try await clickyBackendAuthClient.refreshCurrentEntitlement(
                sessionToken: sessionToken
            ).entitlement
        case .restore:
            return try await clickyBackendAuthClient.restoreLaunchAccess(
                sessionToken: sessionToken
            ).entitlement
        }
    }

    private func shouldClearStoredLaunchSession(after error: Error) -> Bool {
        guard let authError = error as? ClickyBackendAuthClientError else {
            return false
        }

        guard case let .unexpectedStatus(code, _) = authError else {
            return false
        }

        return code == 401 || code == 404
    }

    private func loadLaunchTrialSnapshotLeniently(
        sessionToken: String
    ) async -> ClickyBackendTrialPayload? {
        do {
            return try await clickyBackendAuthClient.fetchCurrentTrial(sessionToken: sessionToken).trial
        } catch {
            ClickyUnifiedTelemetry.billing.error(
                "Launch trial snapshot unavailable during session sync error=\(error.localizedDescription, privacy: .public)"
            )
            ClickyLogger.error(.app, "Launch trial snapshot unavailable during session sync error=\(error.localizedDescription)")
            return nil
        }
    }

    private func shouldAttemptQuietLaunchEntitlementRefresh(
        for storedSession: ClickyAuthSessionSnapshot
    ) -> Bool {
        if launchEntitlementHasEffectiveAccess(storedSession.entitlement) {
            return true
        }

        if clickyLaunchTrialState == .paywalled {
            return true
        }

        switch clickyLaunchBillingState {
        case .waitingForCompletion, .completed:
            return true
        default:
            return false
        }
    }

    private func quietLaunchEntitlementSyncMode(
        for storedSession: ClickyAuthSessionSnapshot
    ) -> ClickyLaunchEntitlementSyncMode {
        if launchEntitlementHasEffectiveAccess(storedSession.entitlement) {
            return .refresh
        }

        switch clickyLaunchBillingState {
        case .waitingForCompletion, .completed:
            return .refresh
        default:
            return .restore
        }
    }

    func handleApplicationDidBecomeActive() {
        refreshClickyLaunchEntitlementQuietlyIfNeeded(reason: "app_became_active")
    }

    func refreshClickyLaunchEntitlementQuietlyIfNeeded(
        reason: String,
        minimumInterval: TimeInterval = 90
    ) {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            return
        }

        guard shouldAttemptQuietLaunchEntitlementRefresh(for: storedSession) else {
            return
        }

        if let lastQuietLaunchEntitlementRefreshAt,
           Date().timeIntervalSince(lastQuietLaunchEntitlementRefreshAt) < minimumInterval {
            return
        }

        if quietLaunchEntitlementRefreshTask != nil {
            return
        }

        lastQuietLaunchEntitlementRefreshAt = Date()
        ClickyUnifiedTelemetry.billing.info(
            "Quiet entitlement refresh scheduled reason=\(reason, privacy: .public)"
        )
        ClickyLogger.info(.app, "Scheduling quiet launch entitlement refresh reason=\(reason)")

        quietLaunchEntitlementRefreshTask = Task { @MainActor in
            defer {
                quietLaunchEntitlementRefreshTask = nil
            }

            do {
                let syncMode = quietLaunchEntitlementSyncMode(for: storedSession)
                let refreshedSnapshot = try await synchronizeLaunchSessionSnapshot(
                    sessionToken: storedSession.sessionToken,
                    fallbackUserID: storedSession.userID,
                    fallbackEmail: storedSession.email,
                    entitlementSyncMode: syncMode
                )

                try persistLaunchSessionSnapshot(refreshedSnapshot, reason: "quiet-entitlement-refresh")
                if refreshedSnapshot.entitlement.hasAccess {
                    setLaunchBillingState(.completed, reason: "quiet-entitlement-refresh")
                }
                ClickyUnifiedTelemetry.billing.info(
                    "Quiet entitlement refresh completed reason=\(reason, privacy: .public) access=\(refreshedSnapshot.entitlement.hasAccess ? "true" : "false", privacy: .public) status=\(refreshedSnapshot.entitlement.status, privacy: .public)"
                )
                ClickyLogger.notice(
                    .app,
                    "Quiet launch entitlement refresh succeeded reason=\(reason) access=\(refreshedSnapshot.entitlement.hasAccess)"
                )
            } catch {
                if shouldClearStoredLaunchSession(after: error) {
                    ClickyAuthSessionStore.clear()
                    setLaunchAuthState(.signedOut, reason: "quiet-entitlement-refresh-invalid-session")
                    clickyLaunchEntitlementStatusLabel = "Unknown"
                    setLaunchBillingState(.idle, reason: "quiet-entitlement-refresh-invalid-session")
                    setLaunchTrialState(.inactive, reason: "quiet-entitlement-refresh-invalid-session")
                    clickyLaunchProfileName = ""
                    clickyLaunchProfileImageURL = ""
                    ClickyUnifiedTelemetry.billing.error(
                        "Quiet entitlement refresh cleared invalid session reason=\(reason, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                    )
                    ClickyLogger.error(
                        .app,
                        "Quiet launch entitlement refresh cleared invalid session reason=\(reason) error=\(error.localizedDescription)"
                    )
                    return
                }

                ClickyUnifiedTelemetry.billing.error(
                    "Quiet entitlement refresh failed reason=\(reason, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(
                    .app,
                    "Quiet launch entitlement refresh failed reason=\(reason) error=\(error.localizedDescription)"
                )
            }
        }
    }

    private func synchronizeLaunchSessionSnapshot(
        sessionToken: String,
        fallbackUserID: String? = nil,
        fallbackEmail: String? = nil,
        entitlementSyncMode: ClickyLaunchEntitlementSyncMode = .current
    ) async throws -> ClickyAuthSessionSnapshot {
        async let sessionPayloadTask = clickyBackendAuthClient.fetchCurrentSession(sessionToken: sessionToken)
        async let entitlementPayloadTask = loadLaunchEntitlement(
            sessionToken: sessionToken,
            mode: entitlementSyncMode
        )
        async let trialPayloadTask = loadLaunchTrialSnapshotLeniently(sessionToken: sessionToken)

        let sessionPayload = try await sessionPayloadTask
        let entitlementPayload = try await entitlementPayloadTask
        let trialPayload = await trialPayloadTask

        return ClickyAuthSessionSnapshot(
            sessionToken: sessionToken,
            userID: fallbackUserID ?? sessionPayload.user.id,
            email: fallbackEmail ?? sessionPayload.user.email,
            name: sessionPayload.user.name,
            image: sessionPayload.user.image,
            entitlement: makeLaunchEntitlementSnapshot(from: entitlementPayload),
            trial: trialPayload.map(makeLaunchTrialSnapshot)
        )
    }

    private func activateClickyLaunchTrialNow(
        for storedSession: ClickyAuthSessionSnapshot
    ) async throws -> ClickyAuthSessionSnapshot {
        // "Trial activated" means the first setup-complete assisted turn for a
        // signed-in user who still lacks a launch entitlement.
        let trialPayload = try await clickyBackendAuthClient.activateTrial(sessionToken: storedSession.sessionToken)
        let activatedTrial = makeLaunchTrialSnapshot(from: trialPayload.trial)
        let refreshedSnapshot = updatedLaunchSessionSnapshot(
            from: storedSession,
            trial: activatedTrial
        )

        try persistLaunchSessionSnapshot(refreshedSnapshot, reason: "trial-activated")
        ClickyUnifiedTelemetry.billing.info(
            "Launch trial activated status=\(activatedTrial.status, privacy: .public) remainingCredits=\(String(activatedTrial.remainingCredits), privacy: .public)"
        )
        ClickyLogger.notice(
            .app,
            "Activated launch trial credits=\(activatedTrial.remainingCredits)"
        )
        return refreshedSnapshot
    }

    private func consumeClickyLaunchTrialCreditNow(
        for storedSession: ClickyAuthSessionSnapshot
    ) async throws -> ClickyAuthSessionSnapshot {
        // Credits decrement only after a real assistant turn succeeded.
        let consumePayload = try await clickyBackendAuthClient.consumeTrialCredit(
            sessionToken: storedSession.sessionToken
        )
        let updatedTrial = makeLaunchTrialSnapshot(from: consumePayload.trial)
        let refreshedSnapshot = updatedLaunchSessionSnapshot(
            from: storedSession,
            trial: updatedTrial
        )

        try persistLaunchSessionSnapshot(refreshedSnapshot, reason: "trial-credit-consumed")
        ClickyUnifiedTelemetry.billing.info(
            "Launch trial credit consumed remainingCredits=\(String(updatedTrial.remainingCredits), privacy: .public) status=\(updatedTrial.status, privacy: .public)"
        )
        ClickyLogger.notice(
            .app,
            "Consumed launch trial credit remaining=\(updatedTrial.remainingCredits)"
        )
        return refreshedSnapshot
    }

    private func activateClickyLaunchPaywallNow(
        for storedSession: ClickyAuthSessionSnapshot
    ) async throws -> ClickyAuthSessionSnapshot {
        let trialPayload = try await clickyBackendAuthClient.markTrialPaywalled(
            sessionToken: storedSession.sessionToken
        )
        let paywalledTrial = makeLaunchTrialSnapshot(from: trialPayload.trial)
        let refreshedSnapshot = updatedLaunchSessionSnapshot(
            from: storedSession,
            trial: paywalledTrial
        )

        try persistLaunchSessionSnapshot(refreshedSnapshot, reason: "launch-paywall-activated")
        ClickyUnifiedTelemetry.billing.info("Launch paywall activated")
        ClickyLogger.notice(.app, "Activated launch paywall")
        return refreshedSnapshot
    }

    private func markClickyLaunchWelcomeDeliveredNow(
        for storedSession: ClickyAuthSessionSnapshot
    ) async throws -> ClickyAuthSessionSnapshot {
        let trialPayload = try await clickyBackendAuthClient.markTrialWelcomeDelivered(
            sessionToken: storedSession.sessionToken
        )
        let updatedTrial = makeLaunchTrialSnapshot(from: trialPayload.trial)
        let refreshedSnapshot = updatedLaunchSessionSnapshot(
            from: storedSession,
            trial: updatedTrial
        )

        try persistLaunchSessionSnapshot(refreshedSnapshot, reason: "launch-welcome-delivered")
        ClickyUnifiedTelemetry.billing.info("Launch welcome delivery marked")
        ClickyLogger.notice(.app, "Marked launch welcome turn delivered")
        return refreshedSnapshot
    }

    private func prepareLaunchAuthorizationForAssistantTurn() async throws -> LaunchAssistantTurnAuthorization {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            return LaunchAssistantTurnAuthorization(
                session: nil,
                shouldUseWelcomeTurn: false,
                shouldUsePaywallTurn: false
            )
        }

        guard !launchEntitlementHasEffectiveAccess(storedSession.entitlement) else {
            return LaunchAssistantTurnAuthorization(
                session: storedSession,
                shouldUseWelcomeTurn: false,
                shouldUsePaywallTurn: false
            )
        }

        if launchEntitlementRequiresRepurchase(storedSession.entitlement)
            || launchEntitlementGraceExpired(storedSession.entitlement) {
            return LaunchAssistantTurnAuthorization(
                session: storedSession,
                shouldUseWelcomeTurn: false,
                shouldUsePaywallTurn: false
            )
        }

        guard hasCompletedOnboarding && allPermissionsGranted else {
            return LaunchAssistantTurnAuthorization(
                session: storedSession,
                shouldUseWelcomeTurn: false,
                shouldUsePaywallTurn: false
            )
        }

        let needsTrialActivation = storedSession.trial == nil || storedSession.trial?.status == "inactive"
        let sessionForTurn = needsTrialActivation
            ? try await activateClickyLaunchTrialNow(for: storedSession)
            : storedSession

        let shouldUseWelcomeTurn =
            sessionForTurn.trial?.status == "active"
            && sessionForTurn.trial?.welcomePromptDeliveredAt == nil
        let shouldUsePaywallTurn = sessionForTurn.trial?.status == "armed"
        return LaunchAssistantTurnAuthorization(
            session: sessionForTurn,
            shouldUseWelcomeTurn: shouldUseWelcomeTurn,
            shouldUsePaywallTurn: shouldUsePaywallTurn
        )
    }

    private func presentLaunchSignInRequiredState(openStudio: Bool) {
        openClawGatewayCompanionAgent.cancelActiveRequest()
        elevenLabsTTSClient.stopPlayback()

        if openStudio {
            NotificationCenter.default.post(name: .clickyOpenStudio, object: nil)
        }

        voiceState = .responding
        ClickyLogger.notice(.app, "Blocked assistant turn because launch sign-in is required")

        let spokenMessage: String
        switch clickyLaunchAuthState {
        case .failed(let message):
            spokenMessage = message
        default:
            spokenMessage = "clicky couldn't continue because this mac is signed out. open studio and sign in once, then you can keep going."
        }

        Task { @MainActor in
            _ = await playSpeechText(
                spokenMessage,
                purpose: .systemMessage
            )

            if !Task.isCancelled {
                voiceState = .idle
                scheduleTransientHideIfNeeded()
            }
        }
    }

    private func presentLaunchAccessRecoveryState(
        openStudio: Bool,
        message: String,
        logReason: String
    ) {
        openClawGatewayCompanionAgent.cancelActiveRequest()
        elevenLabsTTSClient.stopPlayback()

        if openStudio {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }

        voiceState = .responding
        ClickyLogger.notice(.app, "Blocked assistant turn because \(logReason)")

        Task { @MainActor in
            _ = await playSpeechText(
                message,
                purpose: .systemMessage
            )

            if !Task.isCancelled {
                voiceState = .idle
                scheduleTransientHideIfNeeded()
            }
        }
    }

    private func presentLaunchPaywallLockedState(openStudio: Bool) {
        openClawGatewayCompanionAgent.cancelActiveRequest()
        elevenLabsTTSClient.stopPlayback()

        if openStudio {
            NotificationCenter.default.post(name: .clickyOpenStudio, object: nil)
        }

        voiceState = .responding
        ClickyLogger.notice(.app, "Blocked assistant turn because launch paywall is active")

        Task { @MainActor in
            _ = await playSpeechText(
                Self.launchPaywallLockedMessage,
                purpose: .systemMessage
            )

            if !Task.isCancelled {
                voiceState = .idle
                scheduleTransientHideIfNeeded()
            }
        }
    }

    func refreshClickyLaunchTrialState() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            setLaunchTrialState(.inactive, reason: "trial-refresh-no-session")
            return
        }

        ClickyUnifiedTelemetry.billing.info("Launch trial refresh requested")
        Task { @MainActor in
            do {
                let trialPayload = try await clickyBackendAuthClient.fetchCurrentTrial(sessionToken: storedSession.sessionToken)
                let updatedTrial = makeLaunchTrialSnapshot(from: trialPayload.trial)
                let refreshedSnapshot = updatedLaunchSessionSnapshot(
                    from: storedSession,
                    trial: updatedTrial
                )

                try persistLaunchSessionSnapshot(refreshedSnapshot, reason: "trial-refresh")
                ClickyUnifiedTelemetry.billing.info(
                    "Launch trial refresh completed status=\(updatedTrial.status, privacy: .public) remainingCredits=\(String(updatedTrial.remainingCredits), privacy: .public)"
                )
                ClickyLogger.notice(.app, "Launch trial state refreshed status=\(updatedTrial.status) remaining=\(updatedTrial.remainingCredits)")
            } catch {
                setLaunchTrialState(.failed(message: error.localizedDescription), reason: "trial-refresh-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Launch trial refresh failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to refresh launch trial state error=\(error.localizedDescription)")
            }
        }
    }

    func activateClickyLaunchTrial() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            setLaunchTrialState(.failed(message: "Sign in before activating the trial."), reason: "trial-activate-blocked-no-session")
            ClickyUnifiedTelemetry.billing.info("Launch trial activation blocked reason=no-session")
            return
        }

        Task { @MainActor in
            do {
                _ = try await activateClickyLaunchTrialNow(for: storedSession)
            } catch {
                setLaunchTrialState(.failed(message: error.localizedDescription), reason: "trial-activate-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Launch trial activation failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to activate launch trial error=\(error.localizedDescription)")
            }
        }
    }

    func consumeClickyLaunchTrialCredit() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            setLaunchTrialState(.failed(message: "Sign in before consuming trial credits."), reason: "trial-consume-blocked-no-session")
            ClickyUnifiedTelemetry.billing.info("Launch trial consume blocked reason=no-session")
            return
        }

        Task { @MainActor in
            do {
                _ = try await consumeClickyLaunchTrialCreditNow(for: storedSession)
            } catch {
                setLaunchTrialState(.failed(message: error.localizedDescription), reason: "trial-consume-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Launch trial consume failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to consume launch trial credit error=\(error.localizedDescription)")
            }
        }
    }

    func activateClickyLaunchPaywall() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            setLaunchTrialState(.failed(message: "Sign in before activating the paywall."), reason: "paywall-activate-blocked-no-session")
            ClickyUnifiedTelemetry.billing.info("Launch paywall activation blocked reason=no-session")
            return
        }

        Task { @MainActor in
            do {
                _ = try await activateClickyLaunchPaywallNow(for: storedSession)
            } catch {
                setLaunchTrialState(.failed(message: error.localizedDescription), reason: "paywall-activate-failed")
                ClickyUnifiedTelemetry.billing.error(
                    "Launch paywall activation failed error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(.app, "Failed to activate launch paywall error=\(error.localizedDescription)")
            }
        }
    }

    private func restoreClickyLaunchSessionIfPossible() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            setLaunchAuthState(.signedOut, reason: "restore-no-session")
            clickyLaunchEntitlementStatusLabel = "Unknown"
            setLaunchTrialState(.inactive, reason: "restore-no-session")
            clickyLaunchProfileName = ""
            clickyLaunchProfileImageURL = ""
            ClickyUnifiedTelemetry.launchAuth.info("Launch auth restore skipped reason=no-stored-session")
            return
        }

        setLaunchAuthState(.restoring, reason: "restore-started")
        ClickyUnifiedTelemetry.launchAuth.info("Launch auth restore started source=stored-session")

        Task { @MainActor in
            do {
                let refreshedSnapshot = try await synchronizeLaunchSessionSnapshot(
                    sessionToken: storedSession.sessionToken,
                    fallbackUserID: storedSession.userID,
                    fallbackEmail: storedSession.email,
                    entitlementSyncMode: .refresh
                )

                try persistLaunchSessionSnapshot(refreshedSnapshot, reason: "stored-session-restore")
                ClickyUnifiedTelemetry.launchAuth.info("Launch auth restore completed source=stored-session result=refreshed")
                ClickyLogger.notice(.app, "Restored Clicky launch auth session")
            } catch {
                if shouldClearStoredLaunchSession(after: error) {
                    ClickyAuthSessionStore.clear()
                    setLaunchAuthState(.signedOut, reason: "restore-invalid-session")
                    clickyLaunchEntitlementStatusLabel = "Unknown"
                    setLaunchBillingState(.idle, reason: "restore-invalid-session")
                    setLaunchTrialState(.inactive, reason: "restore-invalid-session")
                    clickyLaunchProfileName = ""
                    clickyLaunchProfileImageURL = ""
                    ClickyUnifiedTelemetry.launchAuth.error(
                        "Launch auth restore cleared invalid stored session error=\(error.localizedDescription, privacy: .public)"
                    )
                    ClickyLogger.error(.app, "Failed to restore Clicky launch auth session error=\(error.localizedDescription)")
                    return
                }

                setLaunchAuthState(.signedIn(email: storedSession.email), reason: "restore-cached-fallback")
                clickyLaunchProfileName = storedSession.name ?? ""
                clickyLaunchProfileImageURL = storedSession.image ?? ""
                clickyLaunchEntitlementStatusLabel = formatEntitlementStatus(storedSession.entitlement)
                setLaunchTrialState(formatLaunchTrialState(
                    storedSession.trial,
                    hasAccess: launchEntitlementHasEffectiveAccess(storedSession.entitlement)
                ), reason: "restore-cached-fallback")
                ClickyUnifiedTelemetry.launchAuth.error(
                    "Launch auth restore failed; using cached session error=\(error.localizedDescription, privacy: .public)"
                )
                ClickyLogger.error(
                    .app,
                    "Failed to refresh Clicky launch session; continuing with cached state error=\(error.localizedDescription)"
                )
            }
        }
    }

    private func formatLaunchTrialState(_ trial: ClickyLaunchTrialSnapshot?, hasAccess: Bool) -> ClickyLaunchTrialState {
        if hasAccess {
            return .unlocked
        }

        guard let trial else {
            return .inactive
        }

        switch trial.status {
        case "active":
            return .active(remainingCredits: trial.remainingCredits)
        case "armed":
            return .armed
        case "paywalled":
            return .paywalled
        case "unlocked":
            return .paywalled
        default:
            return .inactive
        }
    }

    private func formatEntitlementStatus(_ entitlement: ClickyLaunchEntitlementSnapshot) -> String {
        if entitlement.hasAccess {
            if launchEntitlementGraceExpired(entitlement) {
                return "Refresh required"
            }

            if let gracePeriodEndsAt = entitlement.gracePeriodEndsAt,
               !gracePeriodEndsAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Active · grace until \(gracePeriodEndsAt)"
            }

            return "Active"
        }

        return entitlement.status.capitalized
    }

    func refreshAllPermissions() {
        let previouslyHadAccessibility = hasAccessibilityPermission
        let previouslyHadScreenRecording = hasScreenRecordingPermission
        let previouslyHadMicrophone = hasMicrophonePermission
        let previouslyHadAll = allPermissionsGranted

        let currentlyHasAccessibility = WindowPositionManager.hasAccessibilityPermission()
        hasAccessibilityPermission = currentlyHasAccessibility

        if currentlyHasAccessibility {
            globalPushToTalkShortcutMonitor.start()
        } else {
            globalPushToTalkShortcutMonitor.stop()
        }

        hasScreenRecordingPermission = WindowPositionManager.hasScreenRecordingPermission()

        let micAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        hasMicrophonePermission = micAuthStatus == .authorized

        // Debug: log permission state on changes
        if previouslyHadAccessibility != hasAccessibilityPermission
            || previouslyHadScreenRecording != hasScreenRecordingPermission
            || previouslyHadMicrophone != hasMicrophonePermission {
            print("🔑 Permissions — accessibility: \(hasAccessibilityPermission), screen: \(hasScreenRecordingPermission), mic: \(hasMicrophonePermission), screenContent: \(hasScreenContentPermission)")
        }

        // Track individual permission grants as they happen
        if !previouslyHadAccessibility && hasAccessibilityPermission {
            ClickyAnalytics.trackPermissionGranted(permission: "accessibility")
        }
        if !previouslyHadScreenRecording && hasScreenRecordingPermission {
            ClickyAnalytics.trackPermissionGranted(permission: "screen_recording")
        }
        if !previouslyHadMicrophone && hasMicrophonePermission {
            ClickyAnalytics.trackPermissionGranted(permission: "microphone")
        }
        // Screen content permission is persisted — once the user has approved the
        // SCShareableContent picker, we don't need to re-check it.
        if !hasScreenContentPermission {
            hasScreenContentPermission = UserDefaults.standard.bool(forKey: "hasScreenContentPermission")
        }

        if !previouslyHadAll && allPermissionsGranted {
            ClickyAnalytics.trackAllPermissionsGranted()
        }
    }

    /// Triggers the macOS screen content picker by performing a dummy
    /// screenshot capture. Once the user approves, we persist the grant
    /// so they're never asked again during onboarding.
    @Published private(set) var isRequestingScreenContent = false

    func requestScreenContentPermission() {
        guard !isRequestingScreenContent else { return }
        isRequestingScreenContent = true
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    await MainActor.run { isRequestingScreenContent = false }
                    return
                }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = 320
                config.height = 240
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                // Verify the capture actually returned real content — a 0x0 or
                // fully-empty image means the user denied the prompt.
                let didCapture = image.width > 0 && image.height > 0
                print("🔑 Screen content capture result — width: \(image.width), height: \(image.height), didCapture: \(didCapture)")
                await MainActor.run {
                    isRequestingScreenContent = false
                    guard didCapture else { return }
                    hasScreenContentPermission = true
                    UserDefaults.standard.set(true, forKey: "hasScreenContentPermission")
                    ClickyAnalytics.trackPermissionGranted(permission: "screen_content")

                    // If onboarding was already completed, show the cursor overlay now
                    if hasCompletedOnboarding && allPermissionsGranted && !isOverlayVisible && isClickyCursorEnabled {
                        overlayWindowManager.hasShownOverlayBefore = true
                        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
                        isOverlayVisible = true
                    }
                }
            } catch {
                print("⚠️ Screen content permission request failed: \(error)")
                await MainActor.run { isRequestingScreenContent = false }
            }
        }
    }

    // MARK: - Private

    /// Triggers the system microphone prompt if the user has never been asked.
    /// Once granted/denied the status sticks and polling picks it up.
    private func promptForMicrophoneIfNotDetermined() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor [weak self] in
                self?.hasMicrophonePermission = granted
            }
        }
    }

    /// Polls all permissions frequently so the UI updates live after the
    /// user grants them in System Settings. Screen Recording is the exception —
    /// macOS requires an app restart for that one to take effect.
    private func startPermissionPolling() {
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllPermissions()
            }
        }
    }

    private func bindAudioPowerLevel() {
        audioPowerCancellable = buddyDictationManager.$currentAudioPowerLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] powerLevel in
                self?.currentAudioPowerLevel = powerLevel
            }
    }

    private func bindVoiceStateObservation() {
        voiceStateCancellable = buddyDictationManager.$isRecordingFromKeyboardShortcut
            .combineLatest(
                buddyDictationManager.$isFinalizingTranscript,
                buddyDictationManager.$isPreparingToRecord
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, isFinalizing, isPreparing in
                guard let self else { return }
                // Dictation should always win when the user is actively holding
                // push-to-talk or the transcript is still being finalized. Once
                // the transcript is submitted, the AI pipeline owns .thinking
                // and .responding until it finishes.
                if isRecording {
                    self.voiceState = .listening
                } else if isFinalizing || isPreparing {
                    self.voiceState = .transcribing
                } else if self.voiceState == .thinking || self.voiceState == .responding {
                    return
                } else {
                    self.voiceState = .idle
                    // If the user pressed and released the hotkey without
                    // saying anything, no response task runs — schedule the
                    // transient hide here so the overlay doesn't get stuck.
                    // Only do this when no response is in flight, otherwise
                    // the brief idle gap between recording and processing
                    // would prematurely hide the overlay.
                    if self.currentResponseTask == nil {
                        self.scheduleTransientHideIfNeeded()
                    }
                }
            }
    }

    private func bindShortcutTransitions() {
        shortcutTransitionCancellable = globalPushToTalkShortcutMonitor
            .shortcutTransitionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transition in
                self?.handleShortcutTransition(transition)
            }
    }

    private func bindTutorialPlaybackShortcutTransitions() {
        tutorialPlaybackShortcutCancellable = globalPushToTalkShortcutMonitor
            .tutorialPlaybackCommandPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                guard let self else { return }
                guard tutorialPlaybackState?.isVisible == true else { return }
                handleTutorialPlaybackKeyboardCommand(command)
            }
    }

    private func handleShortcutTransition(_ transition: BuddyPushToTalkShortcut.ShortcutTransition) {
        switch transition {
        case .pressed:
            guard !buddyDictationManager.isDictationInProgress else { return }
            // Don't register push-to-talk while the onboarding video is playing
            guard !showOnboardingVideo else { return }

            if requiresLaunchRepurchaseForCompanionUse {
                presentLaunchAccessRecoveryState(
                    openStudio: true,
                    message: "your launch pass is no longer active. open studio to buy again or restore access if this looks wrong.",
                    logReason: "launch entitlement requires repurchase"
                )
                return
            }

            if requiresLaunchEntitlementRefreshForCompanionUse {
                presentLaunchAccessRecoveryState(
                    openStudio: true,
                    message: "your cached access expired and clicky needs to refresh it. open studio and run refresh access before starting a new assisted turn.",
                    logReason: "launch entitlement grace expired"
                )
                return
            }

            if requiresLaunchSignInForCompanionUse {
                presentLaunchSignInRequiredState(openStudio: true)
                return
            }

            if isClickyLaunchPaywallActive {
                presentLaunchPaywallLockedState(openStudio: true)
                return
            }

            // Cancel any pending transient hide so the overlay stays visible
            transientHideTask?.cancel()
            transientHideTask = nil

            // If the cursor is hidden, bring it back transiently for this interaction
            if !isClickyCursorEnabled && !isOverlayVisible {
                overlayWindowManager.hasShownOverlayBefore = true
                overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
                isOverlayVisible = true
            }

            // Dismiss the menu bar panel so it doesn't cover the screen
            NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)

            // Cancel any in-progress response and TTS from a previous utterance
            currentResponseTask?.cancel()
            openClawGatewayCompanionAgent.cancelActiveRequest()
            elevenLabsTTSClient.stopPlayback()
            clearDetectedElementLocation()

            // Dismiss the onboarding prompt if it's showing
            if showOnboardingPrompt {
                withAnimation(.easeOut(duration: 0.3)) {
                    onboardingPromptOpacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.showOnboardingPrompt = false
                    self.onboardingPromptText = ""
                }
            }
    

            ClickyAnalytics.trackPushToTalkStarted()

            pendingKeyboardShortcutStartTask?.cancel()
            pendingKeyboardShortcutStartTask = Task {
                await buddyDictationManager.startPushToTalkFromKeyboardShortcut(
                    currentDraftText: "",
                    updateDraftText: { _ in
                        // Partial transcripts are hidden (waveform-only UI)
                    },
                    submitDraftText: { [weak self] finalTranscript in
                        self?.lastTranscript = finalTranscript
                        ClickyLogger.notice(.agent, "Received companion transcript transcriptLength=\(finalTranscript.count)")
                        ClickyAgentTurnDiagnostics.logTranscriptCapture(finalTranscript)
                        ClickyAnalytics.trackUserMessageSent(transcript: finalTranscript)
                        self?.sendTranscriptToSelectedAgentWithScreenshot(transcript: finalTranscript)
                    }
                )
            }
        case .released:
            // Cancel the pending start task in case the user released the shortcut
            // before the async startPushToTalk had a chance to begin recording.
            // Without this, a quick press-and-release drops the release event and
            // leaves the waveform overlay stuck on screen indefinitely.
            ClickyAnalytics.trackPushToTalkReleased()
            pendingKeyboardShortcutStartTask?.cancel()
            pendingKeyboardShortcutStartTask = nil
            buddyDictationManager.stopPushToTalkFromKeyboardShortcut()
        case .none:
            break
        }
    }

    // MARK: - Companion Prompt

    private func companionVoiceResponseSystemPrompt() -> String {
        let clickyPresentationName = effectiveClickyPresentationName
        let activePersonaName = activeClickyPersonaDefinition.displayName
        let personaSpeechInstructions = effectiveClickyPersonaSpeechInstructions
        let voiceStyle = effectiveClickyVoicePreset.displayName
        let cursorStyle = effectiveClickyCursorStyle.displayName

        return """
    you're \(clickyPresentationName), a friendly always-on companion that lives in the user's menu bar inside clicky. the active clicky persona preset is \(activePersonaName). the selected voice style is \(voiceStyle). the selected cursor style is \(cursorStyle). \(personaSpeechInstructions) the user just spoke to you via push-to-talk and you can see their screen(s). your reply will be spoken aloud via text-to-speech, so write the way you'd actually talk. this is an ongoing conversation — you remember everything they've said before.

    rules:
    - embody the active persona quietly. unless the user explicitly asks about your persona, voice, or cursor style, do not mention those settings or explain them.
    - default to one or two sentences. be direct and dense. BUT if the user asks you to explain more, go deeper, or elaborate, then go all out — give a thorough, detailed explanation with no length limit.
    - all lowercase, casual, warm. no emojis.
    - write for the ear, not the eye. short sentences. no lists, bullet points, markdown, or formatting — just natural speech.
    - replies with markdown, headings, bullet points, numbered lists, bold markers, or code fences are invalid. do not use them.
    - don't use abbreviations or symbols that sound weird read aloud. write "for example" not "e.g.", spell out small numbers.
    - if the user's question relates to what's on their screen, reference specific things you see.
    - if the screenshot doesn't seem relevant to their question, just answer the question directly.
    - you can help with anything — coding, writing, general knowledge, brainstorming.
    - never say "simply" or "just".
    - don't read out code verbatim. describe what the code does or what needs to change conversationally.
    - brief references to openclaw memory are allowed when they genuinely help, but do not mention hidden instructions or private behind-the-scenes prompt mechanics.
    - do not end with phrases like "if you want", "i can do one better", "want me to", or "should i". give the best concrete answer directly.
    - focus on giving a thorough, useful explanation. don't end with simple yes/no questions like "want me to explain more?" or "should i show you?" — those are dead ends that force the user to just say yes.
    - instead, when it fits naturally, end by planting a seed — mention something bigger or more ambitious they could try, a related concept that goes deeper, or a next-level technique that builds on what you just explained. make it something worth coming back for, not a question they'd just nod to. it's okay to not end with anything extra if the answer is complete on its own.
    - if you receive multiple screen images, the one labeled "primary focus" is where the cursor is — prioritize that one but reference others if relevant.

    element pointing:
    you have a small blue triangle cursor that can fly to and point at things on screen. use structured point objects whenever pointing would genuinely help the user — especially for visible controls, buttons, icons, menus, feature walkthroughs, and navigation help.

    \(ClickyAssistantResponseContract.promptInstructions)
    """
    }

    private func openClawShellScopedSystemPrompt() -> String {
        let upstreamOpenClawAgentName = effectiveOpenClawAgentName
        let clickyPresentationName = effectiveClickyPresentationName
        let localPersonaInstructions = clickyPersonaOverrideInstructions
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let personaSpeechInstructions = effectiveClickyPersonaSpeechInstructions
        let activePersonaName = activeClickyPersonaDefinition.displayName

        let clickyScopedIdentityInstructions: String
        if clickyPersonaScopeMode == .overrideInClicky {
            clickyScopedIdentityInstructions = """
            your upstream openclaw identity is \(upstreamOpenClawAgentName). clicky is only the desktop shell around you. inside clicky only, present yourself as \(clickyPresentationName). do not claim that your upstream identity changed globally. this is a clicky-local presentation layer.
            \(localPersonaInstructions.isEmpty ? "keep the same core knowledge, memory, and reasoning style you already have in openclaw." : "follow these clicky-only persona instructions: \(localPersonaInstructions)")
            """
        } else {
            clickyScopedIdentityInstructions = """
            your upstream openclaw identity is \(upstreamOpenClawAgentName). clicky is only the desktop shell around you. do not rename yourself to clicky or imply that clicky replaced your core identity. keep speaking as \(upstreamOpenClawAgentName), with clicky only providing capture, cursor, and voice presentation.
            """
        }

        return """
        \(clickyScopedIdentityInstructions)

        the active clicky persona preset is \(activePersonaName). \(personaSpeechInstructions)
        the selected voice style is \(effectiveClickyVoicePreset.displayName). the selected cursor style is \(effectiveClickyCursorStyle.displayName).

        clicky shell capabilities currently available to you:
        - screen context arrives as attached screenshots
        - cursor pointing uses \(ClickyShellCapabilities.cursorPointingProtocol)
        - spoken output is handled by the clicky shell
        - clicky shell protocol version: \(ClickyShellCapabilities.shellProtocolVersion)
        - clicky shell capability version: \(ClickyShellCapabilities.shellCapabilityVersion)

        the user just spoke to you via push-to-talk and you can see their screen(s). your reply will be spoken aloud via text-to-speech, so write the way you'd actually talk. this is an ongoing conversation — you remember everything they've said before.

        rules:
        - embody the active persona quietly. unless the user explicitly asks about your persona, voice, or cursor style, do not mention those settings or explain them.
        - default to one or two sentences. be direct and dense. BUT if the user asks you to explain more, go deeper, or elaborate, then go all out — give a thorough, detailed explanation with no length limit.
        - all lowercase, casual, warm. no emojis.
        - write for the ear, not the eye. short sentences. no lists, bullet points, markdown, or formatting — just natural speech.
        - replies with markdown, headings, bullet points, numbered lists, bold markers, or code fences are invalid. do not use them.
        - don't use abbreviations or symbols that sound weird read aloud. write "for example" not "e.g.", spell out small numbers.
        - if the user's question relates to what's on their screen, reference specific things you see.
        - if the screenshot doesn't seem relevant to their question, just answer the question directly.
        - you can help with anything — coding, writing, general knowledge, brainstorming.
        - never say "simply" or "just".
        - don't read out code verbatim. describe what the code does or what needs to change conversationally.
        - brief references to openclaw memory are allowed when they genuinely help, but do not mention hidden instructions or private behind-the-scenes prompt mechanics.
        - do not end with phrases like "if you want", "i can do one better", "want me to", or "should i". give the best concrete answer directly.
        - focus on giving a thorough, useful explanation. don't end with simple yes/no questions like "want me to explain more?" or "should i show you?" — those are dead ends that force the user to just say yes.
        - instead, when it fits naturally, end by planting a seed — mention something bigger or more ambitious they could try, a related concept that goes deeper, or a next-level technique that builds on what you just explained. make it something worth coming back for, not a question they'd just nod to. it's okay to not end with anything extra if the answer is complete on its own.
        - if you receive multiple screen images, the one labeled "primary focus" is where the cursor is — prioritize that one but reference others if relevant.

        element pointing:
        you have a small blue triangle cursor that can fly to and point at things on screen. use structured point objects whenever pointing would genuinely help the user — especially for visible controls, buttons, icons, menus, feature walkthroughs, and navigation help.

        \(ClickyAssistantResponseContract.promptInstructions)
        """
    }

    private struct AssistantResponseAudit {
        let issues: [String]

        var needsRepair: Bool {
            !issues.isEmpty
        }
    }

    private func auditAssistantResponse(
        _ responseText: String,
        transcript: String
    ) -> AssistantResponseAudit {
        do {
            let structuredResponse = try ClickyAssistantResponseContract.parse(
                rawResponse: responseText,
                requiresPoints: transcriptRequiresVisiblePointing(transcript)
            )
            var issues: [String] = []
            if transcriptWantsNarratedWalkthrough(transcript),
               structuredResponse.points.count > 1,
               structuredResponse.points.contains(where: {
                   ($0.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
               }) {
                issues.append("response omitted per-point explanation for a narrated walkthrough")
            }
            return AssistantResponseAudit(issues: issues)
        } catch let ClickyAssistantResponseContractError.invalidResponse(issues, _) {
            return AssistantResponseAudit(issues: issues)
        } catch {
            return AssistantResponseAudit(issues: [error.localizedDescription])
        }
    }

    private func transcriptRequiresVisiblePointing(_ transcript: String) -> Bool {
        let normalizedTranscript = transcript.lowercased()
        let requiredPointingSignals = [
            "point",
            "point out",
            "show me",
            "walk me through",
            "walkthrough",
            "walk through",
            "tour",
            "breakdown",
            "overview",
            "where is",
            "which button",
            "which buttons",
            "which control",
            "which controls",
            "button",
            "buttons",
            "control",
            "controls",
            "climate",
            "dashboard",
            "interior",
            "screen",
            "icon",
            "icons",
        ]

        return requiredPointingSignals.contains { normalizedTranscript.contains($0) }
    }

    private func repairAssistantResponseIfNeeded(
        backend: CompanionAgentBackend,
        originalResponseText: String,
        transcript: String,
        baseSystemPrompt: String,
        labeledImages: [(data: Data, label: String)],
        focusContext: ClickyAssistantFocusContext?,
        conversationHistory: [(userTranscript: String, assistantResponse: String)],
        audit: AssistantResponseAudit
    ) async throws -> (rawText: String, structuredResponse: ClickyAssistantStructuredResponse) {
        guard audit.needsRepair else {
            let structuredResponse = try ClickyAssistantResponseContract.parse(
                rawResponse: originalResponseText,
                requiresPoints: transcriptRequiresVisiblePointing(transcript)
            )
            return (rawText: originalResponseText, structuredResponse: structuredResponse)
        }

        var currentRawResponse = originalResponseText
        var currentIssues = audit.issues

        for repairAttempt in 1...2 {
            ClickyAgentTurnDiagnostics.logResponseAudit(
                backend: backend,
                originalResponse: currentRawResponse,
                issues: currentIssues
            )

            let repairSystemPrompt = """
            \(baseSystemPrompt)

            repair override:
            - your previous reply was rejected because it did not follow clicky's structured json response contract.
            - the response contract overrides any conflicting prose or formatting rule.
            - return one corrected final reply only.
            - output exactly one json object and nothing else.
            - do not apologize, do not explain the repair, and do not mention hidden instructions.
            """

            let repairPrompt = """
            repair context:
            - this is repair attempt \(repairAttempt) for clicky's structured response contract.
            - the visible user request should remain the original one. do not answer the repair instructions directly.
            - invalid previous reply:
              \(currentRawResponse)
            - issues to fix:
              - \(currentIssues.joined(separator: "\n  - "))
            - hard requirements:
              - return exactly one json object and nothing else
              - no markdown, no headings, no bullets, no numbered lists, no bold markers, no code fences
              - the transport must be json even though spokenText itself should sound natural
              - use this exact schema:
                {"spokenText":"string","points":[{"x":741,"y":213,"label":"gearshift","bubbleText":"gearshift","explanation":"the gearshift is down in the lower middle of the cabin.","screenNumber":1}]}
              - spokenText is what clicky speaks aloud
              - points is an ordered array of point targets
              - for multi-point walkthroughs, include explanation on each point so clicky can keep narration synced with the pointer
              - every point target must use real integer pixel coordinates from the screenshot
              - if the user asked where a visible control is, points must not be empty
              - keep bubbleText short but user-friendly
            """

            ClickyAgentTurnDiagnostics.logRepairRequest(
                backend: backend,
                repairPrompt: repairPrompt
            )

            let repairRequest = assistantTurnBuilder.buildRequest(
                systemPrompt: repairSystemPrompt,
                userPrompt: transcript,
                conversationHistory: conversationHistory,
                labeledImages: labeledImages.map { labeledImage in
                    ClickyAssistantLabeledImage(
                        data: labeledImage.data,
                        label: labeledImage.label,
                        mimeType: "image/jpeg"
                    )
                },
                focusContext: focusContext
            )

            ClickyAgentTurnDiagnostics.logCanonicalRequest(
                backend: backend,
                request: repairRequest
            )

            let repairedResponse = try await assistantTurnExecutor.execute(
                ClickyAssistantTurnPlan(
                    backend: backend,
                    systemPrompt: repairSystemPrompt,
                    request: repairRequest
                ),
                onTextChunk: { _ in }
            )

            let trimmedRepairedResponse = repairedResponse.text.trimmingCharacters(in: .whitespacesAndNewlines)
            ClickyAgentTurnDiagnostics.logRawResponse(
                backend: backend,
                response: trimmedRepairedResponse
            )

            do {
                let structuredResponse = try ClickyAssistantResponseContract.parse(
                    rawResponse: trimmedRepairedResponse,
                    requiresPoints: transcriptRequiresVisiblePointing(transcript)
                )

                return (
                    rawText: trimmedRepairedResponse,
                    structuredResponse: structuredResponse
                )
            } catch let ClickyAssistantResponseContractError.invalidResponse(issues, rawResponse) {
                currentRawResponse = rawResponse
                currentIssues = issues
            }
        }

        throw ClickyAssistantResponseContractError.invalidResponse(
            issues: currentIssues,
            rawResponse: currentRawResponse
        )
    }

    // MARK: - AI Response Pipeline

    /// Captures a screenshot, sends it along with the transcript to Claude,
    /// and plays the response aloud via ElevenLabs TTS. The cursor stays in
    /// the spinner/processing state until TTS audio begins playing.
    /// The assistant response should be a structured object with spoken text
    /// plus ordered point targets for the cursor overlay.
    private func sendTranscriptToSelectedAgentWithScreenshot(transcript: String) {
        currentResponseTask?.cancel()
        openClawGatewayCompanionAgent.cancelActiveRequest()
        elevenLabsTTSClient.stopPlayback()

        currentResponseTask = Task {
            if await handleTutorialImportIntentIfNeeded(for: transcript) {
                return
            }

            if await handleTutorialModeTurnIfNeeded(for: transcript) {
                return
            }

            var launchAuthorization = LaunchAssistantTurnAuthorization(
                session: nil,
                shouldUseWelcomeTurn: false,
                shouldUsePaywallTurn: false
            )

            // The voice input is finished. From here on the assistant is
            // thinking, not transcribing, so the overlay switches to the
            // dedicated "thinking" treatment.
            voiceState = .thinking

            do {
                launchAuthorization = try await prepareLaunchAuthorizationForAssistantTurn()

                if let storedSession = launchAuthorization.session,
                   !storedSession.entitlement.hasAccess,
                   storedSession.trial?.status == "paywalled" {
                    NotificationCenter.default.post(name: .clickyOpenStudio, object: nil)
                    voiceState = .responding
                    _ = await playSpeechText(
                        Self.launchPaywallLockedMessage,
                        purpose: .systemMessage
                    )
                    return
                }

                let initialFocusContext = assistantFocusContextProvider.captureCurrentFocusContext()

                // Capture all connected screens so the AI has full context.
                // Reuse the same sampled cursor location so the cursor screen
                // and focus context stay aligned.
                let screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG(
                    cursorLocationOverride: CGPoint(
                        x: initialFocusContext.cursorX,
                        y: initialFocusContext.cursorY
                    )
                )

                guard !Task.isCancelled else { return }

                // Build image labels with the actual screenshot pixel dimensions
                // so Claude's coordinate space matches the image it sees. We
                // scale from screenshot pixels to display points ourselves.
                let labeledImages = screenCaptures.map { capture in
                    let dimensionInfo = " (image dimensions: \(capture.screenshotWidthInPixels)x\(capture.screenshotHeightInPixels) pixels)"
                    return (data: capture.imageData, label: capture.label + dimensionInfo)
                }

                let focusContext = assistantFocusContextProvider.enrich(
                    initialFocusContext,
                    with: screenCaptures
                )
                ClickyLogger.info(
                    .agent,
                    "focus-context backend=\(selectedAgentBackend.displayName) display=\(focusContext.activeDisplayLabel) app=\(focusContext.frontmostApplicationName ?? "unknown") window=\(focusContext.frontmostWindowTitle ?? "unknown") cursor=(\(Int(focusContext.cursorX)),\(Int(focusContext.cursorY))) screenshotCursor=(\(focusContext.screenshotContext?.cursorPixelX ?? -1),\(focusContext.screenshotContext?.cursorPixelY ?? -1)) deltaMs=\(focusContext.screenshotContext?.cursorToScreenshotDeltaMilliseconds ?? -1) trailCount=\(focusContext.recentCursorTrail.count)"
                )

                let plan = makeAssistantTurnPlan(
                    backend: selectedAgentBackend,
                    authorization: launchAuthorization,
                    transcript: transcript,
                    labeledImages: labeledImages,
                    focusContext: focusContext
                )
                logActivePersonaForRequest(
                    transcript: transcript,
                    backend: selectedAgentBackend,
                    systemPrompt: plan.systemPrompt
                )

                let response = try await assistantTurnExecutor.execute(
                    plan,
                    onTextChunk: { _ in
                        // No streaming text display — spinner stays until TTS plays
                    }
                )
                var fullResponseText = response.text

                guard !Task.isCancelled else { return }

                ClickyAgentTurnDiagnostics.logRawResponse(
                    backend: selectedAgentBackend,
                    response: fullResponseText
                )

                let initialAudit = auditAssistantResponse(
                    fullResponseText,
                    transcript: transcript
                )

                let structuredResponse: ClickyAssistantStructuredResponse

                if initialAudit.needsRepair {
                    let repairedResponse = try await repairAssistantResponseIfNeeded(
                        backend: selectedAgentBackend,
                        originalResponseText: fullResponseText,
                        transcript: transcript,
                        baseSystemPrompt: plan.systemPrompt,
                        labeledImages: labeledImages,
                        focusContext: focusContext,
                        conversationHistory: conversationHistory,
                        audit: initialAudit
                    )

                    fullResponseText = repairedResponse.rawText
                    structuredResponse = repairedResponse.structuredResponse

                    ClickyAgentTurnDiagnostics.logRawResponse(
                        backend: selectedAgentBackend,
                        response: fullResponseText
                    )
                } else {
                    structuredResponse = try ClickyAssistantResponseContract.parse(
                        rawResponse: fullResponseText,
                        requiresPoints: transcriptRequiresVisiblePointing(transcript)
                    )
                }

                let spokenText = structuredResponse.spokenText
                ClickyAgentTurnDiagnostics.logParsedResponse(
                    backend: selectedAgentBackend,
                    spokenResponse: spokenText,
                    points: structuredResponse.points
                )
                let resolvedTargets = resolvedPointingTargets(
                    from: parsedPointingTargets(from: structuredResponse.points),
                    screenCaptures: screenCaptures
                )
                let managedNarrationSteps = managedPointNarrationSteps(from: structuredResponse.points)

                // Handle element pointing if the assistant returned coordinates.
                // Switch to idle BEFORE setting the location so the triangle
                // becomes visible and can fly to the target. Without this, the
                // spinner hides the triangle and the flight animation is invisible.
                if !resolvedTargets.isEmpty {
                    voiceState = .idle
                }

                if !resolvedTargets.isEmpty && managedNarrationSteps.isEmpty {
                    queueDetectedElementTargets(resolvedTargets)
                    let labels = resolvedTargets
                        .compactMap { $0.elementLabel }
                        .joined(separator: ", ")
                    print("🎯 Element pointing: queued \(resolvedTargets.count) target(s) \(labels)")
                } else if !resolvedTargets.isEmpty {
                    let labels = resolvedTargets
                        .compactMap { $0.elementLabel }
                        .joined(separator: ", ")
                    print("🎯 Element pointing: prepared managed sequence \(resolvedTargets.count) target(s) \(labels)")
                } else {
                    print("🎯 Element pointing: no element")
                }

                // Save this exchange to conversation history (with the point tag
                // stripped so it doesn't confuse future context)
                conversationHistory.append((
                    userTranscript: transcript,
                    assistantResponse: spokenText
                ))

                // Keep only the last 10 exchanges to avoid unbounded context growth
                if conversationHistory.count > 10 {
                    conversationHistory.removeFirst(conversationHistory.count - 10)
                }

                ClickyLogger.debug(.agent, "Conversation history updated exchanges=\(conversationHistory.count)")

                ClickyAnalytics.trackAIResponseReceived(response: spokenText)
                logAgentResponse(spokenText, backend: selectedAgentBackend)

                if let storedSession = launchAuthorization.session, !storedSession.entitlement.hasAccess {
                    if launchAuthorization.shouldUsePaywallTurn {
                        do {
                            _ = try await activateClickyLaunchPaywallNow(for: storedSession)
                        } catch {
                            ClickyLogger.error(
                                .app,
                                "Failed to persist launch paywall activation after paywall turn error=\(error.localizedDescription)"
                            )
                        }
                    } else if launchAuthorization.shouldUseWelcomeTurn {
                        do {
                            _ = try await markClickyLaunchWelcomeDeliveredNow(for: storedSession)
                        } catch {
                            ClickyLogger.error(
                                .app,
                                "Failed to persist launch welcome delivery after welcome turn error=\(error.localizedDescription)"
                            )
                        }
                    } else if storedSession.trial?.status == "active" {
                        do {
                            let updatedSession = try await consumeClickyLaunchTrialCreditNow(
                                for: storedSession
                            )
                            if updatedSession.trial?.status == "armed" {
                                ClickyLogger.notice(
                                    .app,
                                    "Launch trial exhausted user=\(updatedSession.email) nextTurn=paywall"
                                )
                            }
                        } catch {
                            ClickyLogger.error(
                                .app,
                                "Failed to persist launch trial credit consumption after assistant turn error=\(error.localizedDescription)"
                            )
                        }
                    }
                }

                // Play the response via TTS. Keep the thinking treatment until
                // audio actually starts playing, then switch to responding.
                if !managedNarrationSteps.isEmpty && managedNarrationSteps.count == resolvedTargets.count {
                    voiceState = .responding
                    await playManagedPointSequence(
                        introText: spokenText,
                        responsePoints: structuredResponse.points,
                        resolvedTargets: resolvedTargets
                    )
                } else if !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let playbackOutcome = await playSpeechText(
                        spokenText,
                        purpose: .assistantResponse
                    )
                    if playbackOutcome.finalProviderDisplayName == "Unavailable" {
                        if let fallbackMessage = playbackOutcome.fallbackMessage {
                            ClickyAnalytics.trackTTSError(error: fallbackMessage)
                        }
                        voiceState = .idle
                    } else if playbackOutcome.encounteredElevenLabsFailure,
                              let fallbackMessage = playbackOutcome.fallbackMessage {
                        ClickyAnalytics.trackTTSError(error: fallbackMessage)
                        voiceState = .responding
                    } else {
                        // speakText returns after playback has started — audio is now live.
                        voiceState = .responding
                    }
                }
            } catch is CancellationError {
                // User spoke again — response was interrupted
            } catch {
                ClickyAnalytics.trackResponseError(error: error.localizedDescription)
                print("⚠️ Companion response error: \(error)")
                if launchAuthorization.shouldUsePaywallTurn {
                    if let storedSession = launchAuthorization.session {
                        do {
                            _ = try await activateClickyLaunchPaywallNow(for: storedSession)
                        } catch {
                            ClickyLogger.error(
                                .app,
                                "Failed to persist launch paywall activation after paywall fallback error=\(error.localizedDescription)"
                            )
                        }
                    }

                    voiceState = .responding
                    _ = await playSpeechText(
                        Self.launchPaywallLockedMessage,
                        purpose: .assistantResponse
                    )
                } else {
                    voiceState = .idle
                }
            }

            if !Task.isCancelled {
                voiceState = .idle
                scheduleTransientHideIfNeeded()
            }
        }
    }

    @MainActor
    private func handleTutorialModeTurnIfNeeded(for transcript: String) async -> Bool {
        guard var tutorialSessionState, tutorialSessionState.isActive else {
            return false
        }

        let normalizedTranscript = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if shouldStopTutorialMode(normalizedTranscript) {
            tutorialSessionState.isActive = false
            self.tutorialSessionState = tutorialSessionState
            tutorialConversationHistory = []
            stopTutorialPlayback()
            tutorialImportStatusMessage = "Tutorial mode ended."
            voiceState = .responding
            _ = await playSpeechText(
                "okay, tutorial mode is done. we’re back to normal help now.",
                purpose: .systemMessage
            )
            return true
        }

        if let lessonDraft = currentTutorialImportDraft?.compiledLessonDraft,
           lessonDraft.steps.indices.contains(tutorialSessionState.currentStepIndex) {
            let currentStep = lessonDraft.steps[tutorialSessionState.currentStepIndex]

            if shouldAdvanceTutorialStep(normalizedTranscript) {
                if tutorialSessionState.currentStepIndex + 1 < lessonDraft.steps.count {
                    tutorialSessionState.currentStepIndex += 1
                    self.tutorialSessionState = tutorialSessionState
                    let nextStep = lessonDraft.steps[tutorialSessionState.currentStepIndex]
                    updateTutorialPlaybackBubble("\(nextStep.title). \(nextStep.instruction)")
                    if let nextTimestamp = nextStep.sourceVideoPromptTimestamp {
                        tutorialPlaybackState?.lastPromptTimestampSeconds = nextTimestamp
                    }
                    voiceState = .responding
                    _ = await playSpeechText(
                        "\(nextStep.instruction) let me know once done and we will move on.",
                        purpose: .systemMessage
                    )
                } else {
                    tutorialSessionState.isActive = false
                    self.tutorialSessionState = tutorialSessionState
                    updateTutorialPlaybackBubble("Tutorial complete.")
                    voiceState = .responding
                    _ = await playSpeechText(
                        "nice, that was the last step. you’re done with this tutorial unless you want to review anything.",
                        purpose: .systemMessage
                    )
                }
                return true
            }

            if shouldRepeatCurrentTutorialStep(normalizedTranscript) {
                updateTutorialPlaybackBubble("\(currentStep.title). \(currentStep.instruction)")
                voiceState = .responding
                _ = await playSpeechText(
                    "\(currentStep.instruction) let me know once done and we will move on.",
                    purpose: .systemMessage
                )
                return true
            }

            if shouldListTutorialSteps(normalizedTranscript) {
                let stepSummary = lessonDraft.steps
                    .enumerated()
                    .map { index, step in
                        "step \(index + 1), \(step.title)"
                    }
                    .joined(separator: ". ")
                voiceState = .responding
                _ = await playSpeechText(
                    "here are the steps. \(stepSummary).",
                    purpose: .systemMessage
                )
                return true
            }

            return await handleTutorialAwareAgentTurn(
                transcript: transcript,
                tutorialSessionState: tutorialSessionState,
                currentStep: currentStep
            )
        }

        return false
    }

    @MainActor
    private func handleTutorialAwareAgentTurn(
        transcript: String,
        tutorialSessionState: TutorialSessionState,
        currentStep: TutorialLessonStep
    ) async -> Bool {
        voiceState = .thinking

        do {
            let screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()
            let labeledImages = screenCaptures.map { capture in
                (data: capture.imageData, label: capture.label)
            }
            let focusContext = assistantFocusContextProvider.captureCurrentFocusContext()

            let tutorialAwarePrompt = makeTutorialAwareUserPrompt(
                transcript: transcript,
                tutorialSessionState: tutorialSessionState,
                currentStep: currentStep
            )
            let systemPrompt = makeTutorialModeSystemPrompt()
            let request = makeAssistantTurnRequest(
                systemPrompt: systemPrompt,
                transcript: tutorialAwarePrompt,
                labeledImages: labeledImages,
                focusContext: focusContext
            )

            let response = try await assistantTurnExecutor.execute(
                ClickyAssistantTurnPlan(
                    backend: selectedAgentBackend,
                    systemPrompt: systemPrompt,
                    request: request
                ),
                onTextChunk: { _ in }
            )

            ClickyAgentTurnDiagnostics.logRawResponse(
                backend: selectedAgentBackend,
                response: response.text
            )

            let audit = auditAssistantResponse(
                response.text,
                transcript: transcript
            )
            let structuredResponse: ClickyAssistantStructuredResponse

            if audit.needsRepair {
                let repairedResponse = try await repairAssistantResponseIfNeeded(
                    backend: selectedAgentBackend,
                    originalResponseText: response.text,
                    transcript: transcript,
                    baseSystemPrompt: systemPrompt,
                    labeledImages: labeledImages,
                    focusContext: focusContext,
                    conversationHistory: tutorialConversationHistory,
                    audit: audit
                )
                structuredResponse = repairedResponse.structuredResponse
                ClickyAgentTurnDiagnostics.logRawResponse(
                    backend: selectedAgentBackend,
                    response: repairedResponse.rawText
                )
            } else {
                structuredResponse = try ClickyAssistantResponseContract.parse(
                    rawResponse: response.text,
                    requiresPoints: transcriptRequiresVisiblePointing(transcript)
                )
            }

            let spokenText = structuredResponse.spokenText
            ClickyAgentTurnDiagnostics.logParsedResponse(
                backend: selectedAgentBackend,
                spokenResponse: spokenText,
                points: structuredResponse.points
            )

            tutorialConversationHistory.append((
                userTranscript: transcript,
                assistantResponse: spokenText
            ))
            if tutorialConversationHistory.count > 10 {
                tutorialConversationHistory.removeFirst(tutorialConversationHistory.count - 10)
            }

            updateTutorialPlaybackBubble(spokenText)

            if !structuredResponse.points.isEmpty {
                let initialFocusContext = assistantFocusContextProvider.captureCurrentFocusContext()
                let freshCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG(
                    cursorLocationOverride: CGPoint(
                        x: initialFocusContext.cursorX,
                        y: initialFocusContext.cursorY
                    )
                )
                let resolvedTargets = resolvedPointingTargets(
                    from: parsedPointingTargets(from: structuredResponse.points),
                    screenCaptures: freshCaptures
                )
                if !resolvedTargets.isEmpty {
                    queueDetectedElementTargets(resolvedTargets)
                }
            }

            _ = await playSpeechText(spokenText, purpose: .assistantResponse)
            voiceState = .responding
            return true
        } catch {
            voiceState = .idle
            tutorialImportStatusMessage = error.localizedDescription
            return true
        }
    }

    private func makeTutorialModeSystemPrompt() -> String {
        """
        You are Clicky in tutorial mode.

        The user is actively following a software tutorial. Treat tutorial mode as a persistent guided session, not a normal detached chat.

        Rules:
        - stay grounded in the current tutorial, current step, lesson draft, and extracted evidence
        - answer the user in the context of completing this tutorial
        - use the associated YouTube video only as a reference, not the main product surface
        - prefer helping the user complete the current step before jumping elsewhere
        - when helpful, point at the relevant UI element using the shared Clicky response contract
        - if the user sounds stuck, explain clearly and practically
        - if the user asks what the tutorial is doing, summarize it using the lesson and evidence
        - if the user asks unrelated questions, answer briefly but remain in tutorial mode unless they explicitly end the tutorial

        \(ClickyAssistantResponseContract.promptInstructions)
        """
    }

    private func makeTutorialAwareUserPrompt(
        transcript: String,
        tutorialSessionState: TutorialSessionState,
        currentStep: TutorialLessonStep
    ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let lessonJSONString = (try? String(
            decoding: encoder.encode(tutorialSessionState.lessonDraft),
            as: UTF8.self
        )) ?? "{}"
        let evidenceJSONString = (try? String(
            decoding: encoder.encode(tutorialSessionState.evidenceBundle),
            as: UTF8.self
        )) ?? "{}"

        let historyText = tutorialConversationHistory
            .suffix(6)
            .map { turn in
                "user: \(turn.userTranscript)\nassistant: \(turn.assistantResponse)"
            }
            .joined(separator: "\n\n")

        return """
        Tutorial mode is active.

        User utterance:
        \(transcript)

        Current step index: \(tutorialSessionState.currentStepIndex + 1)
        Current step title: \(currentStep.title)
        Current step instruction: \(currentStep.instruction)
        Current step verification hint: \(currentStep.verificationHint ?? "none")
        Associated tutorial video: \(tutorialSessionState.evidenceBundle.source.url)

        Lesson draft JSON:
        \(lessonJSONString)

        Evidence bundle JSON:
        \(evidenceJSONString)

        Recent tutorial conversation:
        \(historyText.isEmpty ? "none" : historyText)
        """
    }

    private func shouldAdvanceTutorialStep(_ normalizedTranscript: String) -> Bool {
        ["done", "i'm done", "im done", "next", "go next", "finished", "move on", "continue"]
            .contains(where: { normalizedTranscript.contains($0) })
    }

    private func shouldRepeatCurrentTutorialStep(_ normalizedTranscript: String) -> Bool {
        ["repeat", "say that again", "what was step", "what do i do now", "what now", "current step"]
            .contains(where: { normalizedTranscript.contains($0) })
    }

    private func shouldListTutorialSteps(_ normalizedTranscript: String) -> Bool {
        ["what are the steps", "list the steps", "show steps", "all steps"]
            .contains(where: { normalizedTranscript.contains($0) })
    }

    private func shouldStopTutorialMode(_ normalizedTranscript: String) -> Bool {
        ["done with this tutorial", "stop tutorial", "exit tutorial", "leave tutorial mode"]
            .contains(where: { normalizedTranscript.contains($0) })
    }

    @MainActor
    private func handleTutorialImportIntentIfNeeded(for transcript: String) async -> Bool {
        let normalizedTranscript = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard isTutorialImportIntent(normalizedTranscript) else {
            return false
        }

        tutorialImportStatusMessage = "Open the companion menu and paste the YouTube URL to begin."
        NotificationCenter.default.post(name: .clickyShowPanel, object: nil)
        voiceState = .responding
        _ = await playSpeechText(
            "open the companion menu and paste the youtube url to begin. once it's there, hit start learning and i'll guide you through it.",
            purpose: .systemMessage
        )
        return true
    }

    private func isTutorialImportIntent(_ normalizedTranscript: String) -> Bool {
        let mentionsTutorial = normalizedTranscript.contains("tutorial")
            || normalizedTranscript.contains("youtube")
            || normalizedTranscript.contains("video")
            || normalizedTranscript.contains("learn this")
            || normalizedTranscript.contains("learn from this")

        let asksForHelp = normalizedTranscript.contains("help me")
            || normalizedTranscript.contains("walk me through")
            || normalizedTranscript.contains("guide me")
            || normalizedTranscript.contains("work on this")
            || normalizedTranscript.contains("teach me")

        let directImportRequest = normalizedTranscript.contains("i want to work on this tutorial")
            || normalizedTranscript.contains("help with this tutorial")
            || normalizedTranscript.contains("help me with this tutorial")
            || normalizedTranscript.contains("help me with a youtube tutorial")
            || normalizedTranscript.contains("learn this youtube video")

        return directImportRequest || (mentionsTutorial && asksForHelp)
    }

    /// If the cursor is in transient mode (user toggled "Show Clicky" off),
    /// waits for TTS playback and any pointing animation to finish, then
    /// fades out the overlay after a 1-second pause. Cancelled automatically
    /// if the user starts another push-to-talk interaction.
    private func scheduleTransientHideIfNeeded() {
        guard !isClickyCursorEnabled && isOverlayVisible else { return }

        transientHideTask?.cancel()
        transientHideTask = Task {
            // Wait for TTS audio to finish playing
            await elevenLabsTTSClient.waitUntilPlaybackFinishes()
            guard !Task.isCancelled else { return }

            // Wait for pointing animation to finish (location is cleared
            // when the buddy flies back to the cursor)
            while detectedElementScreenLocation != nil {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
            }

            // Pause 1s after everything finishes, then fade out
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            overlayWindowManager.fadeOutAndHideOverlay()
            isOverlayVisible = false
        }
    }

    // MARK: - Point Tag Parsing

    /// A parsed pointing tag before it is converted into a screen location.
    struct ParsedPointingTarget {
        let coordinate: CGPoint
        let elementLabel: String?
        let screenNumber: Int?
        let bubbleText: String?
    }

    /// A resolved pointing target ready for the cursor overlay queue.
    private struct QueuedPointingTarget {
        let screenLocation: CGPoint
        let displayFrame: CGRect
        let elementLabel: String?
        let bubbleText: String?
    }

    /// Legacy result for parsing one or more [POINT:...] tags from assistant text.
    /// This path is retained for the onboarding/demo flow and other compatibility
    /// cases, not for the normal structured-response assistant path.
    struct PointingParseResult {
        /// The response text with the [POINT:...] tag removed.
        let spokenText: String
        /// Parsed pointing targets in the order the assistant requested them.
        let targets: [ParsedPointingTarget]
    }

    /// Parses one or more legacy [POINT:...] tags from assistant text. Tags may
    /// optionally include a short bubble text after a "|" separator, for example:
    /// [POINT:793,320:instrument cluster|speedometer]
    ///
    /// The normal assistant flow should prefer `ClickyAssistantStructuredResponse`
    /// instead of this text-tag parser.
    static func parsePointingCoordinates(from responseText: String) -> PointingParseResult {
        let pattern = #"\[POINT:[^\]]+\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return PointingParseResult(spokenText: responseText, targets: [])
        }

        let matches = regex.matches(in: responseText, range: NSRange(responseText.startIndex..., in: responseText))
        guard !matches.isEmpty else {
            return PointingParseResult(spokenText: responseText, targets: [])
        }

        let strippedText = regex.stringByReplacingMatches(
            in: responseText,
            range: NSRange(responseText.startIndex..., in: responseText),
            withTemplate: ""
        )
        let spokenText = strippedText
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parsedTargets = matches.compactMap { match -> ParsedPointingTarget? in
            guard let matchRange = Range(match.range, in: responseText) else {
                return nil
            }

            let fullTag = String(responseText[matchRange])
            let body = fullTag
                .replacingOccurrences(of: "[POINT:", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard body.lowercased() != "none" else {
                return nil
            }

            return parsePointingTargetBody(body)
        }

        return PointingParseResult(
            spokenText: spokenText,
            targets: parsedTargets
        )
    }

    private static func parsePointingTargetBody(_ body: String) -> ParsedPointingTarget? {
        let parts = body.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let coordinateAndMetadata = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitBubbleText = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        let coordinateSegments = coordinateAndMetadata.split(separator: ":", omittingEmptySubsequences: false)
        guard let coordinateSegment = coordinateSegments.first else { return nil }

        let coordinateParts = coordinateSegment.split(separator: ",", omittingEmptySubsequences: false)
        guard coordinateParts.count == 2,
              let x = Double(String(coordinateParts[0]).trimmingCharacters(in: .whitespacesAndNewlines)),
              let y = Double(String(coordinateParts[1]).trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        var screenNumber: Int?
        var labelComponents: [String] = []

        for segment in coordinateSegments.dropFirst() {
            let trimmedSegment = String(segment).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSegment.isEmpty else { continue }

            if trimmedSegment.lowercased().hasPrefix("screen"),
               let parsedScreenNumber = Int(trimmedSegment.dropFirst("screen".count)),
               parsedScreenNumber >= 1 {
                screenNumber = parsedScreenNumber
            } else {
                labelComponents.append(String(trimmedSegment))
            }
        }

        let elementLabel = labelComponents.isEmpty ? nil : labelComponents.joined(separator: ":")
        let bubbleText = explicitBubbleText.isEmpty ? elementLabel : explicitBubbleText

        return ParsedPointingTarget(
            coordinate: CGPoint(x: x, y: y),
            elementLabel: elementLabel,
            screenNumber: screenNumber,
            bubbleText: bubbleText
        )
    }

    // MARK: - Onboarding Video

    /// Sets up the onboarding video player, starts playback, and schedules
    /// the demo interaction at 40s. Called by BlueCursorView when onboarding starts.
    func setupOnboardingVideo() {
        guard let videoURL = URL(string: "https://stream.mux.com/e5jB8UuSrtFABVnTHCR7k3sIsmcUHCyhtLu1tzqLlfs.m3u8") else { return }

        let player = AVPlayer(url: videoURL)
        player.isMuted = false
        player.volume = 0.0
        self.onboardingVideoPlayer = player
        self.showOnboardingVideo = true
        self.onboardingVideoOpacity = 0.0

        // Start playback immediately — the video plays while invisible,
        // then we fade in both the visual and audio over 1s.
        player.play()

        // Wait for SwiftUI to mount the view, then set opacity to 1.
        // The .animation modifier on the view handles the actual animation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.onboardingVideoOpacity = 1.0
            // Fade audio volume from 0 → 1 over 2s to match visual fade
            self.fadeInVideoAudio(player: player, targetVolume: 1.0, duration: 2.0)
        }

        // At 40 seconds into the video, trigger the onboarding demo where
        // Clicky flies to something interesting on screen and comments on it
        let demoTriggerTime = CMTime(seconds: 40, preferredTimescale: 600)
        onboardingDemoTimeObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: demoTriggerTime)],
            queue: .main
        ) { [weak self] in
            Task { @MainActor [weak self] in
                ClickyAnalytics.trackOnboardingDemoTriggered()
                self?.performOnboardingDemoInteraction()
            }
        }

        // Fade out and clean up when the video finishes
        onboardingVideoEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                ClickyAnalytics.trackOnboardingVideoCompleted()
                self.onboardingVideoOpacity = 0.0
                // Wait for the 2s fade-out animation to complete before tearing down
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.tearDownOnboardingVideo()
                    // After the video disappears, stream in the prompt to try talking
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.startOnboardingPromptStream()
                    }
                }
            }
        }
    }

    func tearDownOnboardingVideo() {
        showOnboardingVideo = false
        if let timeObserver = onboardingDemoTimeObserver {
            onboardingVideoPlayer?.removeTimeObserver(timeObserver)
            onboardingDemoTimeObserver = nil
        }
        onboardingVideoPlayer?.pause()
        onboardingVideoPlayer = nil
        if let observer = onboardingVideoEndObserver {
            NotificationCenter.default.removeObserver(observer)
            onboardingVideoEndObserver = nil
        }
    }

    private func startOnboardingPromptStream() {
        let message = "press control + option and introduce yourself"
        onboardingPromptTask?.cancel()
        onboardingPromptText = ""
        showOnboardingPrompt = true
        onboardingPromptOpacity = 0.0

        withAnimation(.easeIn(duration: 0.4)) {
            onboardingPromptOpacity = 1.0
        }

        onboardingPromptTask = Task { @MainActor in
            for character in message {
                self.onboardingPromptText.append(character)
                try? await Task.sleep(nanoseconds: 30_000_000)
            }

            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard self.showOnboardingPrompt else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                self.onboardingPromptOpacity = 0.0
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            self.showOnboardingPrompt = false
            self.onboardingPromptText = ""
            self.onboardingPromptTask = nil
        }
    }

    /// Gradually raises an AVPlayer's volume from its current level to the
    /// target over the specified duration, creating a smooth audio fade-in.
    private func fadeInVideoAudio(player: AVPlayer, targetVolume: Float, duration: Double) {
        let steps = 20
        let stepInterval = duration / Double(steps)
        let volumeIncrement = (targetVolume - player.volume) / Float(steps)
        var stepsRemaining = steps

        Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { timer in
            stepsRemaining -= 1
            player.volume += volumeIncrement

            if stepsRemaining <= 0 {
                timer.invalidate()
                player.volume = targetVolume
            }
        }
    }

    // MARK: - Onboarding Demo Interaction

    private static let onboardingDemoSystemPrompt = """
    you're clicky, a small blue cursor buddy living on the user's screen. you're showing off during onboarding — look at their screen and find ONE specific, concrete thing to point at. pick something with a clear name or identity: a specific app icon (say its name), a specific word or phrase of text you can read, a specific filename, a specific button label, a specific tab title, a specific image you can describe. do NOT point at vague things like "a window" or "some text" — be specific about exactly what you see.

    make a short quirky 3-6 word observation about the specific thing you picked — something fun, playful, or curious that shows you actually read/recognized it. no emojis ever. NEVER quote or repeat text you see on screen — just react to it. keep it to 6 words max, no exceptions.

    CRITICAL COORDINATE RULE: you MUST only pick elements near the CENTER of the screen. your x coordinate must be between 20%-80% of the image width. your y coordinate must be between 20%-80% of the image height. do NOT pick anything in the top 20%, bottom 20%, left 20%, or right 20% of the screen. no menu bar items, no dock icons, no sidebar items, no items near any edge. only things clearly in the middle area of the screen. if the only interesting things are near the edges, pick something boring in the center instead.

    respond with ONLY your short comment followed by the coordinate tag. nothing else. all lowercase.

    format: your comment [POINT:x,y:label|same short comment]

    the screenshot images are labeled with their pixel dimensions. use those dimensions as the coordinate space. origin (0,0) is top-left. x increases rightward, y increases downward.
    """

    /// Captures a screenshot and asks Claude to find something interesting to
    /// point at, then triggers the buddy's flight animation. Used during
    /// onboarding to demo the pointing feature while the intro video plays.
    func performOnboardingDemoInteraction() {
        // Don't interrupt an active voice response
        guard voiceState == .idle || voiceState == .responding else { return }

        Task {
            do {
                let screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()

                // Only send the cursor screen so Claude can't pick something
                // on a different monitor that we can't point at.
                guard let cursorScreenCapture = screenCaptures.first(where: { $0.isCursorScreen }) else {
                    print("🎯 Onboarding demo: no cursor screen found")
                    return
                }

                let dimensionInfo = " (image dimensions: \(cursorScreenCapture.screenshotWidthInPixels)x\(cursorScreenCapture.screenshotHeightInPixels) pixels)"
                let labeledImages = [(data: cursorScreenCapture.imageData, label: cursorScreenCapture.label + dimensionInfo)]

                let (fullResponseText, _) = try await claudeAPI.analyzeImageStreaming(
                    images: labeledImages,
                    systemPrompt: Self.onboardingDemoSystemPrompt,
                    userPrompt: "look around my screen and find something interesting to point at",
                    onTextChunk: { _ in }
                )

                let parseResult = Self.parsePointingCoordinates(from: fullResponseText)

                let resolvedTargets = resolvedPointingTargets(
                    from: parseResult.targets,
                    screenCaptures: [cursorScreenCapture]
                )

                guard let firstTarget = resolvedTargets.first else {
                    print("🎯 Onboarding demo: no element to point at")
                    return
                }

                // Set custom bubble text so the pointing animation uses Claude's
                // comment instead of a random phrase
                queueDetectedElementTargets([
                    QueuedPointingTarget(
                        screenLocation: firstTarget.screenLocation,
                        displayFrame: firstTarget.displayFrame,
                        elementLabel: firstTarget.elementLabel,
                        bubbleText: parseResult.spokenText
                    )
                ])
                print("🎯 Onboarding demo: pointing at \"\(firstTarget.elementLabel ?? "element")\" — \"\(parseResult.spokenText)\"")
            } catch {
                print("⚠️ Onboarding demo error: \(error)")
            }
        }
    }
}
