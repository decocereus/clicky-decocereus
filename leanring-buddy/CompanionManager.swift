//
//  CompanionManager.swift
//  leanring-buddy
//
//  Central state manager for the companion voice mode. Owns the push-to-talk
//  pipeline (dictation manager + global shortcut monitor + overlay) and
//  exposes observable voice state for the panel UI.
//

import AVFoundation
import Combine
import Foundation
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
    case assistantResponse = "assistant-response"

    var logLabel: String { rawValue }
}

private struct ClickySpeechPlaybackOutcome {
    let finalProviderDisplayName: String
    let fallbackMessage: String?
    let encounteredElevenLabsFailure: Bool
}

@MainActor
final class CompanionManager: ObservableObject {
    @Published private(set) var voiceState: CompanionVoiceState = .idle
    @Published private(set) var lastTranscript: String?
    @Published private(set) var currentAudioPowerLevel: CGFloat = 0
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var hasScreenRecordingPermission = false
    @Published private(set) var hasMicrophonePermission = false
    @Published private(set) var hasScreenContentPermission = false

    /// Screen location (global AppKit coords) of a detected UI element the
    /// buddy should fly to and point at. Parsed from Claude's response;
    /// observed by BlueCursorView to trigger the flight animation.
    @Published var detectedElementScreenLocation: CGPoint?
    /// The display frame (global AppKit coords) of the screen the detected
    /// element is on, so BlueCursorView knows which screen overlay should animate.
    @Published var detectedElementDisplayFrame: CGRect?
    /// Custom speech bubble text for the pointing animation. When set,
    /// BlueCursorView uses this instead of a random pointer phrase.
    @Published var detectedElementBubbleText: String?

    // MARK: - Onboarding Video State (shared across all screen overlays)

    @Published var onboardingVideoPlayer: AVPlayer?
    @Published var showOnboardingVideo: Bool = false
    @Published var onboardingVideoOpacity: Double = 0.0
    private var onboardingVideoEndObserver: NSObjectProtocol?
    private var onboardingDemoTimeObserver: Any?

    // MARK: - Onboarding Prompt Bubble

    /// Text streamed character-by-character on the cursor after the onboarding video ends.
    @Published var onboardingPromptText: String = ""
    @Published var onboardingPromptOpacity: Double = 0.0
    @Published var showOnboardingPrompt: Bool = false

    // MARK: - Onboarding Music

    private var onboardingMusicPlayer: AVAudioPlayer?
    private var onboardingMusicFadeTimer: Timer?

    let buddyDictationManager = BuddyDictationManager()
    let globalPushToTalkShortcutMonitor = GlobalPushToTalkShortcutMonitor()
    let overlayWindowManager = OverlayWindowManager()
    // Response text is now displayed inline on the cursor overlay via
    // streamingResponseText, so no separate response overlay manager is needed.

    private lazy var claudeAPI: ClaudeAPI = {
        return ClaudeAPI(proxyURL: "\(CompanionRuntimeConfiguration.workerBaseURL)/chat", model: selectedModel)
    }()

    private let openClawGatewayCompanionAgent = OpenClawGatewayCompanionAgent()

    private lazy var elevenLabsTTSClient: ElevenLabsTTSClient = {
        return ElevenLabsTTSClient(proxyURL: "\(CompanionRuntimeConfiguration.workerBaseURL)/tts")
    }()

    /// Conversation history so Claude remembers prior exchanges within a session.
    /// Each entry is the user's transcript and Claude's response.
    private var conversationHistory: [(userTranscript: String, assistantResponse: String)] = []

    /// The currently running AI response task, if any. Cancelled when the user
    /// speaks again so a new response can begin immediately.
    private var currentResponseTask: Task<Void, Never>?

    private var shortcutTransitionCancellable: AnyCancellable?
    private var voiceStateCancellable: AnyCancellable?
    private var audioPowerCancellable: AnyCancellable?
    private var accessibilityCheckTimer: Timer?
    private var pendingKeyboardShortcutStartTask: Task<Void, Never>?
    private var clickyShellHeartbeatTimer: Timer?
    /// Scheduled hide for transient cursor mode — cancelled if the user
    /// speaks again before the delay elapses.
    private var transientHideTask: Task<Void, Never>?

    /// True when all three required permissions (accessibility, screen recording,
    /// microphone) are granted. Used by the panel to show a single "all good" state.
    var allPermissionsGranted: Bool {
        hasAccessibilityPermission && hasScreenRecordingPermission && hasMicrophonePermission && hasScreenContentPermission
    }

    /// Whether the blue cursor overlay is currently visible on screen.
    /// Used by the panel to show accurate status text ("Active" vs "Ready").
    @Published private(set) var isOverlayVisible: Bool = false

    /// The Claude model used for voice responses. Persisted to UserDefaults.
    @Published var selectedModel: String = UserDefaults.standard.string(forKey: "selectedClaudeModel") ?? "claude-sonnet-4-6"

    /// The active agent backend driving the companion response pipeline.
    /// Claude remains the default, but OpenClaw can be selected for local
    /// Gateway-backed agent runs.
    @Published var selectedAgentBackend: CompanionAgentBackend = CompanionAgentBackend(
        rawValue: UserDefaults.standard.string(forKey: "selectedCompanionAgentBackend") ?? ""
    ) ?? (CompanionRuntimeConfiguration.isWorkerConfigured ? .claude : .openClaw) {
        didSet {
            UserDefaults.standard.set(selectedAgentBackend.rawValue, forKey: "selectedCompanionAgentBackend")
        }
    }

    /// Connection details for the OpenClaw Gateway backend. These are kept
    /// lightweight for the first integration pass so the app can target a
    /// local Gateway quickly while still allowing remote/tunneled setups.
    @Published var openClawGatewayURL: String = UserDefaults.standard.string(forKey: "openClawGatewayURL") ?? "ws://127.0.0.1:18789" {
        didSet {
            UserDefaults.standard.set(openClawGatewayURL, forKey: "openClawGatewayURL")
            openClawConnectionStatus = .idle
            refreshClickyShellRegistrationLifecycle()
            refreshOpenClawAgentIdentity()
        }
    }

    @Published var openClawAgentIdentifier: String = UserDefaults.standard.string(forKey: "openClawAgentIdentifier") ?? "" {
        didSet {
            UserDefaults.standard.set(openClawAgentIdentifier, forKey: "openClawAgentIdentifier")
            refreshOpenClawAgentIdentity()
        }
    }

    @Published var openClawAgentName: String = UserDefaults.standard.string(forKey: "openClawAgentName") ?? "" {
        didSet {
            UserDefaults.standard.set(openClawAgentName, forKey: "openClawAgentName")
        }
    }

    @Published var openClawGatewayAuthToken: String = UserDefaults.standard.string(forKey: "openClawGatewayAuthToken") ?? "" {
        didSet {
            UserDefaults.standard.set(openClawGatewayAuthToken, forKey: "openClawGatewayAuthToken")
            openClawConnectionStatus = .idle
            refreshClickyShellRegistrationLifecycle()
            refreshOpenClawAgentIdentity()
        }
    }

    @Published var openClawSessionKey: String = UserDefaults.standard.string(forKey: "openClawSessionKey") ?? "clicky-companion" {
        didSet {
            UserDefaults.standard.set(openClawSessionKey, forKey: "openClawSessionKey")
            openClawConnectionStatus = .idle
            if case .registered = clickyShellRegistrationStatus {
                bindClickyShellSession()
            } else {
                refreshClickyShellRegistrationLifecycle()
            }
            refreshOpenClawAgentIdentity()
        }
    }

    @Published private(set) var openClawConnectionStatus: OpenClawConnectionStatus = .idle
    @Published private(set) var clickyShellRegistrationStatus: ClickyShellRegistrationStatus = .idle
    @Published private(set) var clickyShellServerFreshnessState: String?
    @Published private(set) var clickyShellServerStatusSummary: String?
    @Published private(set) var clickyShellServerSessionBindingState: String?
    @Published private(set) var clickyShellServerSessionKey: String?
    @Published private(set) var clickyShellServerTrustState: String?
    @Published private(set) var inferredOpenClawAgentIdentityAvatar: String?
    @Published private(set) var inferredOpenClawAgentIdentityName: String?
    @Published private(set) var inferredOpenClawAgentIdentityEmoji: String?
    @Published private(set) var inferredOpenClawAgentIdentifier: String?

    @Published var clickyPersonaScopeMode: ClickyPersonaScopeMode = ClickyPersonaScopeMode(
        rawValue: UserDefaults.standard.string(forKey: "clickyPersonaScopeMode") ?? ""
    ) ?? .useOpenClawIdentity {
        didSet {
            UserDefaults.standard.set(clickyPersonaScopeMode.rawValue, forKey: "clickyPersonaScopeMode")
            refreshClickyShellRegistrationLifecycle()
        }
    }

    @Published var clickyPersonaOverrideName: String = UserDefaults.standard.string(forKey: "clickyPersonaOverrideName") ?? "" {
        didSet {
            UserDefaults.standard.set(clickyPersonaOverrideName, forKey: "clickyPersonaOverrideName")
            refreshClickyShellRegistrationLifecycle()
        }
    }

    @Published var clickyPersonaOverrideInstructions: String = UserDefaults.standard.string(forKey: "clickyPersonaOverrideInstructions") ?? "" {
        didSet {
            UserDefaults.standard.set(clickyPersonaOverrideInstructions, forKey: "clickyPersonaOverrideInstructions")
            refreshClickyShellRegistrationLifecycle()
        }
    }

    @Published var clickyPersonaPreset: ClickyPersonaPreset = ClickyPersonaPreset(
        rawValue: UserDefaults.standard.string(forKey: "clickyPersonaPreset") ?? ""
    ) ?? .guide {
        didSet {
            UserDefaults.standard.set(clickyPersonaPreset.rawValue, forKey: "clickyPersonaPreset")
            refreshClickyShellRegistrationLifecycle()
        }
    }

    @Published var clickyPersonaToneInstructions: String = UserDefaults.standard.string(forKey: "clickyPersonaToneInstructions") ?? "" {
        didSet {
            UserDefaults.standard.set(clickyPersonaToneInstructions, forKey: "clickyPersonaToneInstructions")
            refreshClickyShellRegistrationLifecycle()
        }
    }

    @Published var clickyVoicePreset: ClickyVoicePreset = ClickyVoicePreset(
        rawValue: UserDefaults.standard.string(forKey: "clickyVoicePreset") ?? ""
    ) ?? .balanced {
        didSet {
            UserDefaults.standard.set(clickyVoicePreset.rawValue, forKey: "clickyVoicePreset")
        }
    }

    @Published var clickyCursorStyle: ClickyCursorStyle = ClickyCursorStyle(
        rawValue: UserDefaults.standard.string(forKey: "clickyCursorStyle") ?? ""
    ) ?? .classic {
        didSet {
            UserDefaults.standard.set(clickyCursorStyle.rawValue, forKey: "clickyCursorStyle")
        }
    }

    @Published var clickySpeechProviderMode: ClickySpeechProviderMode = ClickySpeechProviderMode(
        rawValue: UserDefaults.standard.string(forKey: "clickySpeechProviderMode") ?? ""
    ) ?? .system {
        didSet {
            UserDefaults.standard.set(clickySpeechProviderMode.rawValue, forKey: "clickySpeechProviderMode")
            speechPreviewStatus = .idle
            lastSpeechFallbackMessage = nil
            ClickyLogger.notice(.audio, "Speech provider selected provider=\(clickySpeechProviderMode.displayName)")
        }
    }

    @Published var elevenLabsAPIKeyDraft: String = ClickySecrets.load(account: "elevenlabs_api_key") ?? ""
    @Published var elevenLabsImportVoiceIDDraft: String = ""
    @Published private(set) var elevenLabsAvailableVoices: [ElevenLabsVoiceOption] = []
    @Published private(set) var elevenLabsVoiceFetchStatus: ElevenLabsVoiceFetchStatus = .idle
    @Published private(set) var elevenLabsVoiceImportStatus: ElevenLabsVoiceImportStatus = .idle
    @Published private(set) var speechPreviewStatus: ClickySpeechPreviewStatus = .idle
    @Published private(set) var lastSpeechFallbackMessage: String?
    @Published private(set) var clickyLaunchAuthState: ClickyLaunchAuthState = .signedOut
    @Published private(set) var clickyLaunchEntitlementStatusLabel: String = "Unknown"
    @Published var clickyBackendBaseURL: String = UserDefaults.standard.string(forKey: "clickyBackendBaseURL") ?? CompanionRuntimeConfiguration.defaultBackendBaseURL {
        didSet {
            UserDefaults.standard.set(clickyBackendBaseURL, forKey: "clickyBackendBaseURL")
        }
    }
    @Published var elevenLabsSelectedVoiceID: String = UserDefaults.standard.string(forKey: "elevenLabsSelectedVoiceID") ?? "" {
        didSet {
            UserDefaults.standard.set(elevenLabsSelectedVoiceID, forKey: "elevenLabsSelectedVoiceID")
        }
    }
    @Published var elevenLabsSelectedVoiceName: String = UserDefaults.standard.string(forKey: "elevenLabsSelectedVoiceName") ?? "" {
        didSet {
            UserDefaults.standard.set(elevenLabsSelectedVoiceName, forKey: "elevenLabsSelectedVoiceName")
        }
    }

    @Published var clickyThemePreset: ClickyThemePreset = ClickyThemePreset(
        rawValue: UserDefaults.standard.string(forKey: "clickyThemePreset") ?? ""
    ) ?? .dark {
        didSet {
            UserDefaults.standard.set(clickyThemePreset.rawValue, forKey: "clickyThemePreset")
        }
    }

    var activeClickyTheme: ClickyTheme {
        clickyThemePreset.theme
    }

    var clickyBackendStatusLabel: String {
        let trimmedURL = clickyBackendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedURL.isEmpty ? "Not configured" : trimmedURL
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

    var hasStoredElevenLabsAPIKey: Bool {
        !(ClickySecrets.load(account: "elevenlabs_api_key") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var activeClickyPersonaDefinition: ClickyPersonaDefinition {
        clickyPersonaPreset.definition
    }

    var activeClickyPersonaSummary: String {
        activeClickyPersonaDefinition.summary
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
        selectedModel = model
        UserDefaults.standard.set(model, forKey: "selectedClaudeModel")
        claudeAPI.model = model
    }

    func startClickyLaunchSignIn() {
        clickyLaunchAuthState = .signingIn
        ClickyLogger.notice(.app, "Starting Clicky launch sign-in")

        Task { @MainActor in
            do {
                let payload = try await clickyBackendAuthClient.startNativeSignIn()
                guard let browserURL = URL(string: payload.browserURL) else {
                    throw ClickyBackendAuthClientError.invalidBackendURL
                }

                NSWorkspace.shared.open(browserURL)
            } catch {
                clickyLaunchAuthState = .failed(message: error.localizedDescription)
                ClickyLogger.error(.app, "Failed to start Clicky launch sign-in error=\(error.localizedDescription)")
            }
        }
    }

    func signOutClickyLaunchSession() {
        ClickyAuthSessionStore.clear()
        clickyLaunchAuthState = .signedOut
        clickyLaunchEntitlementStatusLabel = "Unknown"
        ClickyLogger.notice(.app, "Cleared Clicky launch auth session")
    }

    func handleClickyLaunchAuthCallback(url: URL) {
        guard url.scheme?.lowercased() == "clicky",
              url.host?.lowercased() == "auth",
              url.path == "/callback" else {
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let exchangeCode = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !exchangeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clickyLaunchAuthState = .failed(message: ClickyBackendAuthClientError.missingExchangeCode.localizedDescription)
            return
        }

        clickyLaunchAuthState = .signingIn

        Task { @MainActor in
            do {
                let exchangePayload = try await clickyBackendAuthClient.exchangeNativeCode(exchangeCode)
                let sessionPayload = try await clickyBackendAuthClient.fetchCurrentSession(sessionToken: exchangePayload.sessionToken)
                let entitlementSnapshot = ClickyLaunchEntitlementSnapshot(
                    productKey: exchangePayload.entitlement.productKey,
                    status: exchangePayload.entitlement.status,
                    hasAccess: exchangePayload.entitlement.hasAccess,
                    gracePeriodEndsAt: exchangePayload.entitlement.gracePeriodEndsAt
                )
                let snapshot = ClickyAuthSessionSnapshot(
                    sessionToken: exchangePayload.sessionToken,
                    userID: exchangePayload.userID,
                    email: sessionPayload.user.email,
                    entitlement: entitlementSnapshot
                )

                try ClickyAuthSessionStore.save(snapshot)
                clickyLaunchAuthState = .signedIn(email: snapshot.email)
                clickyLaunchEntitlementStatusLabel = formatEntitlementStatus(snapshot.entitlement)
                ClickyLogger.notice(.app, "Completed Clicky launch auth exchange user=\(snapshot.email)")
            } catch {
                clickyLaunchAuthState = .failed(message: error.localizedDescription)
                clickyLaunchEntitlementStatusLabel = "Unknown"
                ClickyLogger.error(.app, "Failed to complete Clicky launch auth exchange error=\(error.localizedDescription)")
            }
        }
    }

    func setSelectedAgentBackend(_ selectedAgentBackend: CompanionAgentBackend) {
        self.selectedAgentBackend = selectedAgentBackend
        refreshClickyShellRegistrationLifecycle()
        refreshOpenClawAgentIdentity()
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
        if clickyPersonaScopeMode == .overrideInClicky {
            let overrideName = clickyPersonaOverrideName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !overrideName.isEmpty {
                return overrideName
            }
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
        let transcriptPreview = Self.truncatedForLog(transcript, limit: 120)
        let promptPreview = Self.truncatedForLog(systemPrompt, limit: 220)
        ClickyLogger.notice(
            .agent,
            "request backend=\(backend.displayName) persona=\(activeClickyPersonaLabel) display=\(effectiveClickyPresentationName) voice=\(effectiveClickyVoicePreset.displayName) cursor=\(effectiveClickyCursorStyle.displayName) scope=\(clickyPersonaScopeLabel) transcript=\(transcriptPreview)"
        )
        ClickyLogger.debug(
            .agent,
            "prompt-preview backend=\(backend.displayName) persona=\(activeClickyPersonaLabel) text=\(promptPreview)"
        )
    }

    private func logAgentResponse(_ response: String, backend: CompanionAgentBackend) {
        let responsePreview = Self.truncatedForLog(response, limit: 300)
        ClickyLogger.notice(
            .agent,
            "response backend=\(backend.displayName) persona=\(activeClickyPersonaLabel) display=\(effectiveClickyPresentationName) voice=\(effectiveClickyVoicePreset.displayName) text=\(responsePreview)"
        )
    }

    private func playSpeechText(
        _ text: String,
        purpose: ClickySpeechPlaybackPurpose
    ) async -> ClickySpeechPlaybackOutcome {
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
                let fallbackMessage = "ElevenLabs could not play audio, so Clicky fell back to System Speech. \(error.localizedDescription)"
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

    private static func truncatedForLog(_ text: String, limit: Int) -> String {
        let singleLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard singleLine.count > limit else { return singleLine }
        return String(singleLine.prefix(limit)) + "..."
    }

    private static let speechPreviewSampleText = "hey, this is clicky. here is how your current voice sounds."

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
    @Published var isClickyCursorEnabled: Bool = UserDefaults.standard.object(forKey: "isClickyCursorEnabled") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "isClickyCursorEnabled")

    func setClickyCursorEnabled(_ enabled: Bool) {
        isClickyCursorEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "isClickyCursorEnabled")
        transientHideTask?.cancel()
        transientHideTask = nil

        if enabled {
            overlayWindowManager.hasShownOverlayBefore = true
            overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
            isOverlayVisible = true
        } else {
            overlayWindowManager.hideOverlay()
            isOverlayVisible = false
        }
    }

    /// Whether the user has completed onboarding at least once. Persisted
    /// to UserDefaults so the Start button only appears on first launch.
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    func start() {
        if !CompanionRuntimeConfiguration.isWorkerConfigured && selectedAgentBackend == .claude {
            selectedAgentBackend = .openClaw
        }

        restoreClickyLaunchSessionIfPossible()
        refreshAllPermissions()
        print("🔑 Clicky start — accessibility: \(hasAccessibilityPermission), screen: \(hasScreenRecordingPermission), mic: \(hasMicrophonePermission), screenContent: \(hasScreenContentPermission), onboarded: \(hasCompletedOnboarding)")
        startPermissionPolling()
        bindVoiceStateObservation()
        bindAudioPowerLevel()
        bindShortcutTransitions()
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

        // If the user already completed onboarding AND all permissions are
        // still granted, show the cursor overlay immediately. If permissions
        // were revoked (e.g. signing change), don't show the cursor — the
        // panel will show the permissions UI instead.
        if hasCompletedOnboarding && allPermissionsGranted && isClickyCursorEnabled {
            overlayWindowManager.hasShownOverlayBefore = true
            overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
            isOverlayVisible = true
        }
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
                self?.fadeOutOnboardingMusic()
            }
        } catch {
            print("⚠️ Clicky: Failed to play onboarding music: \(error)")
        }
    }

    private func fadeOutOnboardingMusic() {
        guard let player = onboardingMusicPlayer else { return }

        let fadeSteps = 30
        let fadeDuration: Double = 3.0
        let stepInterval = fadeDuration / Double(fadeSteps)
        let volumeDecrement = player.volume / Float(fadeSteps)
        var stepsRemaining = fadeSteps

        onboardingMusicFadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            stepsRemaining -= 1
            player.volume -= volumeDecrement

            if stepsRemaining <= 0 {
                timer.invalidate()
                player.stop()
                self?.onboardingMusicPlayer = nil
                self?.onboardingMusicFadeTimer = nil
            }
        }
    }

    func clearDetectedElementLocation() {
        detectedElementScreenLocation = nil
        detectedElementDisplayFrame = nil
        detectedElementBubbleText = nil
    }

    func stop() {
        globalPushToTalkShortcutMonitor.stop()
        buddyDictationManager.cancelCurrentDictation()
        overlayWindowManager.hideOverlay()
        transientHideTask?.cancel()
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

    private func restoreClickyLaunchSessionIfPossible() {
        guard let storedSession = ClickyAuthSessionStore.load() else {
            clickyLaunchAuthState = .signedOut
            clickyLaunchEntitlementStatusLabel = "Unknown"
            return
        }

        clickyLaunchAuthState = .restoring

        Task { @MainActor in
            do {
                let sessionPayload = try await clickyBackendAuthClient.fetchCurrentSession(sessionToken: storedSession.sessionToken)
                let entitlementPayload = try await clickyBackendAuthClient.fetchCurrentEntitlement(sessionToken: storedSession.sessionToken)
                let refreshedSnapshot = ClickyAuthSessionSnapshot(
                    sessionToken: storedSession.sessionToken,
                    userID: sessionPayload.user.id,
                    email: sessionPayload.user.email,
                    entitlement: ClickyLaunchEntitlementSnapshot(
                        productKey: entitlementPayload.entitlement.productKey,
                        status: entitlementPayload.entitlement.status,
                        hasAccess: entitlementPayload.entitlement.hasAccess,
                        gracePeriodEndsAt: entitlementPayload.entitlement.gracePeriodEndsAt
                    )
                )

                try ClickyAuthSessionStore.save(refreshedSnapshot)
                clickyLaunchAuthState = .signedIn(email: refreshedSnapshot.email)
                clickyLaunchEntitlementStatusLabel = formatEntitlementStatus(refreshedSnapshot.entitlement)
                ClickyLogger.notice(.app, "Restored Clicky launch auth session user=\(refreshedSnapshot.email)")
            } catch {
                ClickyAuthSessionStore.clear()
                clickyLaunchAuthState = .signedOut
                clickyLaunchEntitlementStatusLabel = "Unknown"
                ClickyLogger.error(.app, "Failed to restore Clicky launch auth session error=\(error.localizedDescription)")
            }
        }
    }

    private func formatEntitlementStatus(_ entitlement: ClickyLaunchEntitlementSnapshot) -> String {
        if entitlement.hasAccess {
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

    private func handleShortcutTransition(_ transition: BuddyPushToTalkShortcut.ShortcutTransition) {
        switch transition {
        case .pressed:
            guard !buddyDictationManager.isDictationInProgress else { return }
            // Don't register push-to-talk while the onboarding video is playing
            guard !showOnboardingVideo else { return }

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
                        print("🗣️ Companion received transcript: \(finalTranscript)")
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
    - don't use abbreviations or symbols that sound weird read aloud. write "for example" not "e.g.", spell out small numbers.
    - if the user's question relates to what's on their screen, reference specific things you see.
    - if the screenshot doesn't seem relevant to their question, just answer the question directly.
    - you can help with anything — coding, writing, general knowledge, brainstorming.
    - never say "simply" or "just".
    - don't read out code verbatim. describe what the code does or what needs to change conversationally.
    - focus on giving a thorough, useful explanation. don't end with simple yes/no questions like "want me to explain more?" or "should i show you?" — those are dead ends that force the user to just say yes.
    - instead, when it fits naturally, end by planting a seed — mention something bigger or more ambitious they could try, a related concept that goes deeper, or a next-level technique that builds on what you just explained. make it something worth coming back for, not a question they'd just nod to. it's okay to not end with anything extra if the answer is complete on its own.
    - if you receive multiple screen images, the one labeled "primary focus" is where the cursor is — prioritize that one but reference others if relevant.

    element pointing:
    you have a small blue triangle cursor that can fly to and point at things on screen. use it whenever pointing would genuinely help the user — if they're asking how to do something, looking for a menu, trying to find a button, or need help navigating an app, point at the relevant element. err on the side of pointing rather than not pointing, because it makes your help way more useful and concrete.

    don't point at things when it would be pointless — like if the user asks a general knowledge question, or the conversation has nothing to do with what's on screen, or you'd just be pointing at something obvious they're already looking at. but if there's a specific UI element, menu, button, or area on screen that's relevant to what you're helping with, point at it.

    when you point, append exactly one coordinate tag at the very end of your response, AFTER your spoken text. do not include coordinate numbers, point syntax, or screen numbers in the part that gets spoken aloud. keep all coordinates only inside the final tag. the screenshot images are labeled with their pixel dimensions. use those dimensions as the coordinate space. the origin (0,0) is the top-left corner of the image. x increases rightward, y increases downward.

    format: [POINT:x,y:label] where x,y are integer pixel coordinates in the screenshot's coordinate space, and label is a short 1-3 word description of the element (like "search bar" or "save button"). if the element is on the cursor's screen you can omit the screen number. if the element is on a DIFFERENT screen, append :screenN where N is the screen number from the image label (e.g. :screen2). this is important — without the screen number, the cursor will point at the wrong place.

    choose one best target only. never output multiple point tags. if pointing wouldn't help, append [POINT:none].

    examples:
    - user asks how to color grade in final cut: "you'll want to open the color inspector — it's right up in the top right area of the toolbar. click that and you'll get all the color wheels and curves. [POINT:1100,42:color inspector]"
    - user asks what html is: "html stands for hypertext markup language, it's basically the skeleton of every web page. curious how it connects to the css you're looking at? [POINT:none]"
    - user asks how to commit in xcode: "see that source control menu up top? click that and hit commit, or you can use command option c as a shortcut. [POINT:285,11:source control]"
    - element is on screen 2 (not where cursor is): "that's over on your other monitor — see the terminal window? [POINT:400,300:terminal:screen2]"
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
        - don't use abbreviations or symbols that sound weird read aloud. write "for example" not "e.g.", spell out small numbers.
        - if the user's question relates to what's on their screen, reference specific things you see.
        - if the screenshot doesn't seem relevant to their question, just answer the question directly.
        - you can help with anything — coding, writing, general knowledge, brainstorming.
        - never say "simply" or "just".
        - don't read out code verbatim. describe what the code does or what needs to change conversationally.
        - focus on giving a thorough, useful explanation. don't end with simple yes/no questions like "want me to explain more?" or "should i show you?" — those are dead ends that force the user to just say yes.
        - instead, when it fits naturally, end by planting a seed — mention something bigger or more ambitious they could try, a related concept that goes deeper, or a next-level technique that builds on what you just explained. make it something worth coming back for, not a question they'd just nod to. it's okay to not end with anything extra if the answer is complete on its own.
        - if you receive multiple screen images, the one labeled "primary focus" is where the cursor is — prioritize that one but reference others if relevant.

        element pointing:
        you have a small blue triangle cursor that can fly to and point at things on screen. use it whenever pointing would genuinely help the user — if they're asking how to do something, looking for a menu, trying to find a button, or need help navigating an app, point at the relevant element. err on the side of pointing rather than not pointing, because it makes your help way more useful and concrete.

        don't point at things when it would be pointless — like if the user asks a general knowledge question, or the conversation has nothing to do with what's on screen, or you'd just be pointing at something obvious they're already looking at. but if there's a specific UI element, menu, button, or area on screen that's relevant to what you're helping with, point at it.

        when you point, append exactly one coordinate tag at the very end of your response, AFTER your spoken text. do not include coordinate numbers, point syntax, or screen numbers in the part that gets spoken aloud. keep all coordinates only inside the final tag. the screenshot images are labeled with their pixel dimensions. use those dimensions as the coordinate space. the origin (0,0) is the top-left corner of the image. x increases rightward, y increases downward.

        format: [POINT:x,y:label] where x,y are integer pixel coordinates in the screenshot's coordinate space, and label is a short 1-3 word description of the element (like "search bar" or "save button"). if the element is on the cursor's screen you can omit the screen number. if the element is on a DIFFERENT screen, append :screenN where N is the screen number from the image label (e.g. :screen2). this is important — without the screen number, the cursor will point at the wrong place.

        choose one best target only. never output multiple point tags. if pointing wouldn't help, append [POINT:none].

        examples:
        - user asks how to color grade in final cut: "you'll want to open the color inspector — it's right up in the top right area of the toolbar. click that and you'll get all the color wheels and curves. [POINT:1100,42:color inspector]"
        - user asks what html is: "html stands for hypertext markup language, it's basically the skeleton of every web page. curious how it connects to the css you're looking at? [POINT:none]"
        - user asks how to commit in xcode: "see that source control menu up top? click that and hit commit, or you can use command option c as a shortcut. [POINT:285,11:source control]"
        - element is on screen 2 (not where cursor is): "that's over on your other monitor — see the terminal window? [POINT:400,300:terminal:screen2]"
        """
    }

    // MARK: - AI Response Pipeline

    /// Captures a screenshot, sends it along with the transcript to Claude,
    /// and plays the response aloud via ElevenLabs TTS. The cursor stays in
    /// the spinner/processing state until TTS audio begins playing.
    /// Claude's response may include a [POINT:x,y:label] tag which triggers
    /// the buddy to fly to that element on screen.
    private func sendTranscriptToSelectedAgentWithScreenshot(transcript: String) {
        currentResponseTask?.cancel()
        openClawGatewayCompanionAgent.cancelActiveRequest()
        elevenLabsTTSClient.stopPlayback()

        currentResponseTask = Task {
            // The voice input is finished. From here on the assistant is
            // thinking, not transcribing, so the overlay switches to the
            // dedicated "thinking" treatment.
            voiceState = .thinking

            do {
                // Capture all connected screens so the AI has full context
                let screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()

                guard !Task.isCancelled else { return }

                // Build image labels with the actual screenshot pixel dimensions
                // so Claude's coordinate space matches the image it sees. We
                // scale from screenshot pixels to display points ourselves.
                let labeledImages = screenCaptures.map { capture in
                    let dimensionInfo = " (image dimensions: \(capture.screenshotWidthInPixels)x\(capture.screenshotHeightInPixels) pixels)"
                    return (data: capture.imageData, label: capture.label + dimensionInfo)
                }

                let fullResponseText: String
                switch selectedAgentBackend {
                case .claude:
                    let systemPrompt = companionVoiceResponseSystemPrompt()
                    logActivePersonaForRequest(
                        transcript: transcript,
                        backend: .claude,
                        systemPrompt: systemPrompt
                    )

                    // Pass conversation history so Claude remembers prior exchanges
                    let historyForAPI = conversationHistory.map { entry in
                        (userPlaceholder: entry.userTranscript, assistantResponse: entry.assistantResponse)
                    }

                    let response = try await claudeAPI.analyzeImageStreaming(
                        images: labeledImages,
                        systemPrompt: systemPrompt,
                        conversationHistory: historyForAPI,
                        userPrompt: transcript,
                        onTextChunk: { _ in
                            // No streaming text display — spinner stays until TTS plays
                        }
                    )
                    fullResponseText = response.text
                case .openClaw:
                    let systemPrompt = openClawShellScopedSystemPrompt()
                    logActivePersonaForRequest(
                        transcript: transcript,
                        backend: .openClaw,
                        systemPrompt: systemPrompt
                    )

                    let imageAttachments = labeledImages.map { labeledImage in
                        OpenClawGatewayImageAttachment(
                            imageData: labeledImage.data,
                            label: labeledImage.label,
                            mimeType: "image/jpeg"
                        )
                    }

                    let response = try await openClawGatewayCompanionAgent.analyzeImageStreaming(
                        gatewayURLString: openClawGatewayURL,
                        explicitGatewayAuthToken: openClawGatewayAuthToken,
                        configuredAgentIdentifier: openClawAgentIdentifier,
                        configuredSessionKey: openClawSessionKey,
                        images: imageAttachments,
                        systemPrompt: systemPrompt,
                        userPrompt: transcript,
                        onTextChunk: { _ in
                            // No streaming text display — spinner stays until TTS plays
                        }
                    )
                    fullResponseText = response.text
                }

                guard !Task.isCancelled else { return }

                // Parse the [POINT:...] tag from Claude's response
                let parseResult = Self.parsePointingCoordinates(from: fullResponseText)
                let spokenText = parseResult.spokenText

                // Handle element pointing if Claude returned coordinates.
                // Switch to idle BEFORE setting the location so the triangle
                // becomes visible and can fly to the target. Without this, the
                // spinner hides the triangle and the flight animation is invisible.
                let hasPointCoordinate = parseResult.coordinate != nil
                if hasPointCoordinate {
                    voiceState = .idle
                }

                // Pick the screen capture matching Claude's screen number,
                // falling back to the cursor screen if not specified.
                let targetScreenCapture: CompanionScreenCapture? = {
                    if let screenNumber = parseResult.screenNumber,
                       screenNumber >= 1 && screenNumber <= screenCaptures.count {
                        return screenCaptures[screenNumber - 1]
                    }
                    return screenCaptures.first(where: { $0.isCursorScreen })
                }()

                if let pointCoordinate = parseResult.coordinate,
                   let targetScreenCapture {
                    // Claude's coordinates are in the screenshot's pixel space
                    // (top-left origin, e.g. 1280x831). Scale to the display's
                    // point space (e.g. 1512x982), then convert to AppKit global coords.
                    let screenshotWidth = CGFloat(targetScreenCapture.screenshotWidthInPixels)
                    let screenshotHeight = CGFloat(targetScreenCapture.screenshotHeightInPixels)
                    let displayWidth = CGFloat(targetScreenCapture.displayWidthInPoints)
                    let displayHeight = CGFloat(targetScreenCapture.displayHeightInPoints)
                    let displayFrame = targetScreenCapture.displayFrame

                    // Clamp to screenshot coordinate space
                    let clampedX = max(0, min(pointCoordinate.x, screenshotWidth))
                    let clampedY = max(0, min(pointCoordinate.y, screenshotHeight))

                    // Scale from screenshot pixels to display points
                    let displayLocalX = clampedX * (displayWidth / screenshotWidth)
                    let displayLocalY = clampedY * (displayHeight / screenshotHeight)

                    // Convert from top-left origin (screenshot) to bottom-left origin (AppKit)
                    let appKitY = displayHeight - displayLocalY

                    // Convert display-local coords to global screen coords
                    let globalLocation = CGPoint(
                        x: displayLocalX + displayFrame.origin.x,
                        y: appKitY + displayFrame.origin.y
                    )

                    detectedElementScreenLocation = globalLocation
                    detectedElementDisplayFrame = displayFrame
                    ClickyAnalytics.trackElementPointed(elementLabel: parseResult.elementLabel)
                    print("🎯 Element pointing: (\(Int(pointCoordinate.x)), \(Int(pointCoordinate.y))) → \"\(parseResult.elementLabel ?? "element")\"")
                } else {
                    print("🎯 Element pointing: \(parseResult.elementLabel ?? "no element")")
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

                print("🧠 Conversation history: \(conversationHistory.count) exchanges")

                ClickyAnalytics.trackAIResponseReceived(response: spokenText)
                logAgentResponse(spokenText, backend: selectedAgentBackend)

                // Play the response via TTS. Keep the thinking treatment until
                // audio actually starts playing, then switch to responding.
                if !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let playbackOutcome = await playSpeechText(
                        spokenText,
                        purpose: .assistantResponse
                    )
                    if playbackOutcome.finalProviderDisplayName == "Unavailable" {
                        if let fallbackMessage = playbackOutcome.fallbackMessage {
                            ClickyAnalytics.trackTTSError(error: fallbackMessage)
                        }
                        speakCreditsErrorFallback()
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
                speakCreditsErrorFallback()
            }

            if !Task.isCancelled {
                voiceState = .idle
                scheduleTransientHideIfNeeded()
            }
        }
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
            while elevenLabsTTSClient.isPlaying {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
            }

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

    /// Speaks a hardcoded error message using macOS system TTS when API
    /// credits run out. Uses NSSpeechSynthesizer so it works even when
    /// ElevenLabs is down.
    private func speakCreditsErrorFallback() {
        let utterance = "I'm all out of credits. Please DM Farza and tell him to bring me back to life."
        let synthesizer = NSSpeechSynthesizer()
        synthesizer.startSpeaking(utterance)
        voiceState = .responding
    }

    // MARK: - Point Tag Parsing

    /// Result of parsing a [POINT:...] tag from Claude's response.
    struct PointingParseResult {
        /// The response text with the [POINT:...] tag removed — this is what gets spoken.
        let spokenText: String
        /// The parsed pixel coordinate, or nil if Claude said "none" or no tag was found.
        let coordinate: CGPoint?
        /// Short label describing the element (e.g. "run button"), or "none".
        let elementLabel: String?
        /// Which screen the coordinate refers to (1-based), or nil to default to cursor screen.
        let screenNumber: Int?
    }

    /// Parses a [POINT:x,y:label:screenN] or [POINT:none] tag from the end of Claude's response.
    /// Returns the spoken text (tag removed) and the optional coordinate + label + screen number.
    static func parsePointingCoordinates(from responseText: String) -> PointingParseResult {
        // Match [POINT:none] or [POINT:123,456:label] or [POINT:123,456:label:screen2]
        // anywhere in the response so stray or duplicated tags never leak into
        // spoken output.
        let pattern = #"\[POINT:(?:none|(\d+)\s*,\s*(\d+)(?::([^\]:\s][^\]:]*?))?(?::screen(\d+))?)\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return PointingParseResult(spokenText: responseText, coordinate: nil, elementLabel: nil, screenNumber: nil)
        }

        let matches = regex.matches(in: responseText, range: NSRange(responseText.startIndex..., in: responseText))
        guard let match = matches.first else {
            // No tag found at all
            return PointingParseResult(spokenText: responseText, coordinate: nil, elementLabel: nil, screenNumber: nil)
        }

        // Remove every point tag from the spoken text so malformed multi-tag
        // replies do not read coordinates aloud.
        let strippedText = regex.stringByReplacingMatches(
            in: responseText,
            range: NSRange(responseText.startIndex..., in: responseText),
            withTemplate: ""
        )
        let spokenText = strippedText
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's [POINT:none]
        guard match.numberOfRanges >= 3,
              let xRange = Range(match.range(at: 1), in: responseText),
              let yRange = Range(match.range(at: 2), in: responseText),
              let x = Double(responseText[xRange]),
              let y = Double(responseText[yRange]) else {
            return PointingParseResult(spokenText: spokenText, coordinate: nil, elementLabel: "none", screenNumber: nil)
        }

        var elementLabel: String? = nil
        if match.numberOfRanges >= 4, let labelRange = Range(match.range(at: 3), in: responseText) {
            elementLabel = String(responseText[labelRange]).trimmingCharacters(in: .whitespaces)
        }

        var screenNumber: Int? = nil
        if match.numberOfRanges >= 5, let screenRange = Range(match.range(at: 4), in: responseText) {
            screenNumber = Int(responseText[screenRange])
        }

        return PointingParseResult(
            spokenText: spokenText,
            coordinate: CGPoint(x: x, y: y),
            elementLabel: elementLabel,
            screenNumber: screenNumber
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
            ClickyAnalytics.trackOnboardingDemoTriggered()
            self?.performOnboardingDemoInteraction()
        }

        // Fade out and clean up when the video finishes
        onboardingVideoEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
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
        onboardingPromptText = ""
        showOnboardingPrompt = true
        onboardingPromptOpacity = 0.0

        withAnimation(.easeIn(duration: 0.4)) {
            onboardingPromptOpacity = 1.0
        }

        var currentIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            guard currentIndex < message.count else {
                timer.invalidate()
                // Auto-dismiss after 10 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    guard self.showOnboardingPrompt else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.onboardingPromptOpacity = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.showOnboardingPrompt = false
                        self.onboardingPromptText = ""
                    }
                }
                return
            }
            let index = message.index(message.startIndex, offsetBy: currentIndex)
            self.onboardingPromptText.append(message[index])
            currentIndex += 1
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

    format: your comment [POINT:x,y:label]

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

                guard let pointCoordinate = parseResult.coordinate else {
                    print("🎯 Onboarding demo: no element to point at")
                    return
                }

                let screenshotWidth = CGFloat(cursorScreenCapture.screenshotWidthInPixels)
                let screenshotHeight = CGFloat(cursorScreenCapture.screenshotHeightInPixels)
                let displayWidth = CGFloat(cursorScreenCapture.displayWidthInPoints)
                let displayHeight = CGFloat(cursorScreenCapture.displayHeightInPoints)
                let displayFrame = cursorScreenCapture.displayFrame

                let clampedX = max(0, min(pointCoordinate.x, screenshotWidth))
                let clampedY = max(0, min(pointCoordinate.y, screenshotHeight))
                let displayLocalX = clampedX * (displayWidth / screenshotWidth)
                let displayLocalY = clampedY * (displayHeight / screenshotHeight)
                let appKitY = displayHeight - displayLocalY
                let globalLocation = CGPoint(
                    x: displayLocalX + displayFrame.origin.x,
                    y: appKitY + displayFrame.origin.y
                )

                // Set custom bubble text so the pointing animation uses Claude's
                // comment instead of a random phrase
                detectedElementBubbleText = parseResult.spokenText
                detectedElementScreenLocation = globalLocation
                detectedElementDisplayFrame = displayFrame
                print("🎯 Onboarding demo: pointing at \"\(parseResult.elementLabel ?? "element")\" — \"\(parseResult.spokenText)\"")
            } catch {
                print("⚠️ Onboarding demo error: \(error)")
            }
        }
    }
}
