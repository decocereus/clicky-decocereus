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

@MainActor
final class CompanionManager: ObservableObject {
    let surfaceController = ClickySurfaceController()

    // MARK: - Tutorial Playback State

    let tutorialController = ClickyTutorialController()

    // MARK: - Onboarding Music

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
    private lazy var openClawShellLifecycleController = ClickyOpenClawShellLifecycleController(
        gatewayAgent: openClawGatewayCompanionAgent,
        routingController: backendRoutingController,
        configurationProvider: { [weak self] in
            guard let self else {
                return ClickyOpenClawShellLifecycleConfiguration(
                    selectedBackend: .claude,
                    gatewayURL: "",
                    gatewayAuthToken: "",
                    isGatewayRemote: false,
                    isLocalPluginEnabled: false,
                    effectiveAgentName: "your OpenClaw agent",
                    effectivePresentationName: "Clicky",
                    personaScopeMode: .useOpenClawIdentity,
                    sessionKey: ""
                )
            }

            return ClickyOpenClawShellLifecycleConfiguration(
                selectedBackend: self.selectedAgentBackend,
                gatewayURL: self.openClawGatewayURL,
                gatewayAuthToken: self.openClawGatewayAuthToken,
                isGatewayRemote: self.isOpenClawGatewayRemote,
                isLocalPluginEnabled: self.clickyOpenClawPluginStatus == .enabled,
                effectiveAgentName: self.effectiveOpenClawAgentName,
                effectivePresentationName: self.effectiveClickyPresentationName,
                personaScopeMode: self.clickyPersonaScopeMode,
                sessionKey: self.openClawSessionKey
            )
        }
    )
    private lazy var openClawStudioCoordinator = ClickyOpenClawStudioCoordinator(
        preferences: preferences,
        backendRoutingController: backendRoutingController,
        gatewayAgent: openClawGatewayCompanionAgent,
        shellLifecycleController: openClawShellLifecycleController,
        selectedBackendProvider: { [weak self] in
            self?.selectedAgentBackend ?? .claude
        }
    )
    private lazy var settingsMutationCoordinator = ClickySettingsMutationCoordinator(
        preferences: preferences,
        backendRoutingController: backendRoutingController,
        claudeAPI: claudeAPI,
        openClawShellLifecycleController: openClawShellLifecycleController,
        refreshOpenClawAgentIdentity: { [weak self] in
            self?.refreshOpenClawAgentIdentity()
        },
        refreshCodexRuntimeStatus: { [weak self] in
            self?.refreshCodexRuntimeStatus()
        }
    )

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
                    shellIdentifier: self.openClawShellLifecycleController.shellIdentifier
                )
            }
        )
    }()

    private lazy var codexAssistantProvider: CodexAssistantProvider = {
        CodexAssistantProvider(runtimeClient: codexRuntimeClient)
    }()
    private lazy var codexRuntimeCoordinator = ClickyCodexRuntimeCoordinator(
        backendRoutingController: backendRoutingController,
        runtimeClient: codexRuntimeClient
    )
    private lazy var permissionCoordinator = ClickyPermissionCoordinator(
        surfaceController: surfaceController,
        shortcutMonitor: globalPushToTalkShortcutMonitor,
        onRequestingScreenContentChanged: { [weak self] isRequesting in
            self?.isRequestingScreenContent = isRequesting
        },
        onScreenContentGranted: { [weak self] in
            guard let self else { return }
            self.surfaceLifecycleCoordinator.showOverlayIfReady()
        }
    )
    private let onboardingMusicController = ClickyOnboardingMusicController()
    private lazy var surfaceLifecycleCoordinator = ClickySurfaceLifecycleCoordinator(
        preferences: preferences,
        surfaceController: surfaceController,
        overlayWindowManager: overlayWindowManager,
        onboardingMusicController: onboardingMusicController,
        allPermissionsGrantedProvider: { [weak self] in
            self?.allPermissionsGranted == true
        },
        cancelTransientHide: { [weak self] in
            self?.voiceSessionCoordinator.cancelTransientHide()
        },
        showOverlay: { [weak self] in
            guard let self else { return }
            self.overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
        }
    )

    private let assistantSystemPromptPlanner = ClickyAssistantSystemPromptPlanner()
    private let assistantFocusContextProvider = ClickyAssistantFocusContextProvider()
    private lazy var assistantBasePromptSource = ClickyAssistantBasePromptSource { [weak self] backend in
        guard let self else { return "" }
        switch backend {
        case .claude:
            return self.personaPromptCoordinator.companionVoiceResponseSystemPrompt()
        case .codex:
            return self.personaPromptCoordinator.companionVoiceResponseSystemPrompt()
        case .openClaw:
            return self.personaPromptCoordinator.openClawShellScopedSystemPrompt()
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
    private lazy var assistantResponseRepairer = ClickyAssistantResponseRepairer(
        assistantTurnExecutor: assistantTurnExecutor
    )
    private lazy var assistantResponseProcessor = ClickyAssistantResponseProcessor(
        repairer: assistantResponseRepairer
    )
    private lazy var assistantTurnContextBuilder = ClickyAssistantTurnContextBuilder(
        focusContextProvider: assistantFocusContextProvider,
        basePromptSource: assistantBasePromptSource,
        systemPromptPlanner: assistantSystemPromptPlanner
    )

    private lazy var elevenLabsTTSClient: ElevenLabsTTSClient = {
        return ElevenLabsTTSClient(proxyURL: "\(CompanionRuntimeConfiguration.workerBaseURL)/tts")
    }()

    /// Conversation history so Claude remembers prior exchanges within a session.
    /// Each entry is the user's transcript and Claude's response.
    private lazy var pointingSequenceController = ClickyPointingSequenceController(
        surfaceController: surfaceController
    )
    private lazy var onboardingDemoController = ClickyOnboardingDemoController(
        claudeAPI: claudeAPI,
        shouldRun: { [weak self] in
            guard let self else { return false }
            return self.surfaceController.voiceState == .idle || self.surfaceController.voiceState == .responding
        },
        queueTargets: { [weak self] targets in
            self?.queueDetectedElementTargets(targets)
        }
    )
    private lazy var onboardingVideoController = ClickyOnboardingVideoController(
        surfaceController: surfaceController,
        performDemoInteraction: { [weak self] in
            self?.performOnboardingDemoInteraction()
        }
    )
    private lazy var launchSessionService = ClickyLaunchSessionService(
        client: clickyBackendAuthClient,
        accessController: launchAccessController
    )
    private lazy var launchTurnGate = ClickyLaunchTurnGate(
        accessController: launchAccessController,
        sessionService: launchSessionService
    )
    private lazy var launchPostTurnRecorder = ClickyLaunchPostTurnRecorder(
        sessionService: launchSessionService
    )
    private lazy var launchFlowCoordinator = ClickyLaunchFlowCoordinator(
        authClient: clickyBackendAuthClient,
        accessController: launchAccessController,
        sessionService: launchSessionService
    )
    private lazy var launchRuntimeCoordinator = ClickyLaunchRuntimeCoordinator(
        accessController: launchAccessController,
        sessionService: launchSessionService,
        backendClientProvider: { [weak self] in
            self?.clickyBackendAuthClient ?? ClickyBackendAuthClient(baseURL: CompanionRuntimeConfiguration.defaultBackendBaseURL)
        }
    )
    private lazy var launchBlockedTurnPresenter = ClickyLaunchBlockedTurnPresenter(
        cancelActiveAssistantRequest: { [weak self] in
            self?.openClawGatewayCompanionAgent.cancelActiveRequest()
        },
        stopSpeechPlayback: { [weak self] in
            self?.elevenLabsTTSClient.stopPlayback()
        },
        setVoiceState: { [weak self] state in
            self?.surfaceController.voiceState = state
        },
        playSpeech: { [weak self] message, purpose in
            guard let self else { return }
            _ = await self.playSpeechText(message, purpose: purpose)
        },
        scheduleTransientHideIfNeeded: { [weak self] in
            self?.scheduleTransientHideIfNeeded()
        }
    )
    private lazy var tutorialPlaybackCoordinator = ClickyTutorialPlaybackCoordinator(
        tutorialController: tutorialController
    )
    lazy var speechProviderCoordinator = ClickySpeechProviderCoordinator(
        preferences: preferences,
        controller: speechProviderController,
        stopPlayback: { [weak self] in
            self?.elevenLabsTTSClient.stopPlayback()
        },
        playPreview: { [weak self] text in
            guard let self else {
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "Unavailable",
                    fallbackMessage: "Companion manager was released.",
                    encounteredElevenLabsFailure: false
                )
            }
            return await self.playSpeechText(text, purpose: .preview)
        }
    )
    private lazy var speechPlaybackCoordinator = ClickySpeechPlaybackCoordinator(
        preferences: preferences,
        controller: speechProviderController,
        ttsClient: elevenLabsTTSClient,
        speechRoutingProvider: { [weak self] in
            guard let self else {
                return ClickySpeechRouting(
                    selectedProvider: .system,
                    outputMode: .system,
                    selectedVoiceID: "",
                    selectedVoiceName: "",
                    configurationFallbackMessage: nil
                )
            }
            return self.speechProviderCoordinator.effectiveSpeechRouting
        },
        voicePresetProvider: { [weak self] in
            self?.effectiveClickyVoicePreset ?? .balanced
        }
    )
    private lazy var personaPromptCoordinator = ClickyPersonaPromptCoordinator(
        snapshotProvider: { [weak self] in
            guard let self else {
                return ClickyPersonaPromptSnapshot(
                    selectedBackend: .claude,
                    selectedModel: "",
                    codexConfiguredModelName: nil,
                    openClawAgentIdentifier: "",
                    inferredOpenClawAgentIdentifier: nil,
                    effectiveOpenClawAgentName: "your OpenClaw agent",
                    personaScopeMode: .useOpenClawIdentity,
                    personaOverrideName: "",
                    personaOverrideInstructions: "",
                    activePersonaDefinition: ClickyPersonaPreset.guide.definition,
                    voicePreset: .balanced,
                    cursorStyle: .classic,
                    customToneInstructions: ""
                )
            }

            return ClickyPersonaPromptSnapshot(
                selectedBackend: self.selectedAgentBackend,
                selectedModel: self.selectedModel,
                codexConfiguredModelName: self.backendRoutingController.codexConfiguredModelName,
                openClawAgentIdentifier: self.openClawAgentIdentifier,
                inferredOpenClawAgentIdentifier: self.backendRoutingController.inferredOpenClawAgentIdentifier,
                effectiveOpenClawAgentName: self.effectiveOpenClawAgentName,
                personaScopeMode: self.clickyPersonaScopeMode,
                personaOverrideName: self.clickyPersonaOverrideName,
                personaOverrideInstructions: self.clickyPersonaOverrideInstructions,
                activePersonaDefinition: self.activeClickyPersonaDefinition,
                voicePreset: self.effectiveClickyVoicePreset,
                cursorStyle: self.effectiveClickyCursorStyle,
                customToneInstructions: self.clickyPersonaToneInstructions
            )
        }
    )
    private lazy var assistantTurnCoordinator = ClickyAssistantTurnCoordinator(
        turnExecutor: assistantTurnExecutor,
        turnContextBuilder: assistantTurnContextBuilder,
        responseProcessor: assistantResponseProcessor,
        launchTurnGate: launchTurnGate,
        launchPostTurnRecorder: launchPostTurnRecorder,
        selectedBackendProvider: { [weak self] in
            self?.selectedAgentBackend ?? .claude
        },
        setVoiceState: { [weak self] state in
            self?.surfaceController.voiceState = state
        },
        playSpeech: { [weak self] text, purpose in
            guard let self else {
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "Unavailable",
                    fallbackMessage: "Companion manager was released.",
                    encounteredElevenLabsFailure: false
                )
            }
            return await self.playSpeechText(text, purpose: purpose)
        },
        playManagedPointSequence: { [weak self] introText, responsePoints, resolvedTargets in
            await self?.playManagedPointSequence(
                introText: introText,
                responsePoints: responsePoints,
                resolvedTargets: resolvedTargets
            )
        },
        queuePointingTargets: { [weak self] targets in
            self?.queueDetectedElementTargets(targets)
        },
        openStudio: {
            NotificationCenter.default.post(name: .clickyOpenStudio, object: nil)
        },
        scheduleTransientHideIfNeeded: { [weak self] in
            self?.scheduleTransientHideIfNeeded()
        },
        logActivePersonaForRequest: { [weak self] transcript, backend, systemPrompt in
            self?.personaPromptCoordinator.logActivePersonaForRequest(
                transcript: transcript,
                backend: backend,
                systemPrompt: systemPrompt
            )
        },
        logAgentResponse: { [weak self] response, backend in
            self?.personaPromptCoordinator.logAgentResponse(response, backend: backend)
        }
    )
    private lazy var assistantTurnTaskController = ClickyAssistantTurnTaskController(
        assistantTurnCoordinator: assistantTurnCoordinator,
        gatewayAgent: openClawGatewayCompanionAgent,
        ttsClient: elevenLabsTTSClient,
        handleTutorialImportIntent: { [weak self] transcript in
            await self?.handleTutorialImportIntentIfNeeded(for: transcript) ?? false
        },
        handleTutorialModeTurn: { [weak self] transcript in
            await self?.handleTutorialModeTurnIfNeeded(for: transcript) ?? false
        },
        hasCompletedOnboarding: { [weak self] in
            self?.hasCompletedOnboarding == true
        },
        allPermissionsGranted: { [weak self] in
            self?.allPermissionsGranted == true
        }
    )
    private lazy var tutorialLessonCompiler = ClickyTutorialLessonCompiler(
        assistantTurnExecutor: assistantTurnExecutor,
        selectedBackendProvider: { [weak self] in
            self?.selectedAgentBackend ?? .claude
        }
    )
    private lazy var tutorialImportCoordinator = ClickyTutorialImportCoordinator(
        tutorialController: tutorialController,
        backendURLProvider: { [weak self] in
            self?.clickyBackendBaseURL ?? ""
        },
        lessonCompiler: tutorialLessonCompiler,
        clearConversationHistory: { [weak self] in
            self?.tutorialModeCoordinator.clearConversationHistory()
        }
    )
    private lazy var tutorialModeCoordinator = ClickyTutorialModeCoordinator(
        tutorialController: tutorialController,
        playbackCoordinator: tutorialPlaybackCoordinator,
        assistantTurnExecutor: assistantTurnExecutor,
        assistantResponseRepairer: assistantResponseRepairer,
        focusContextProvider: assistantFocusContextProvider,
        selectedBackendProvider: { [weak self] in
            self?.selectedAgentBackend ?? .claude
        },
        setVoiceState: { [weak self] state in
            self?.surfaceController.voiceState = state
        },
        playSpeech: { [weak self] text, purpose in
            guard let self else { return }
            _ = await self.playSpeechText(text, purpose: purpose)
        },
        queuePointingTargets: { [weak self] targets in
            self?.queueDetectedElementTargets(targets)
        }
    )
    private lazy var voiceSessionCoordinator = ClickyVoiceSessionCoordinator(
        dictationManager: buddyDictationManager,
        shortcutMonitor: globalPushToTalkShortcutMonitor,
        surfaceController: surfaceController,
        overlayWindowManager: overlayWindowManager,
        ttsClient: elevenLabsTTSClient,
        isClickyCursorEnabled: { [weak self] in
            self?.isClickyCursorEnabled == true
        },
        canBeginPushToTalk: { [weak self] in
            self?.preparePushToTalkSessionIfAllowed() ?? false
        },
        isResponseTaskActive: { [weak self] in
            self?.assistantTurnTaskController.isActive == true
        },
        cancelActiveResponse: { [weak self] in
            self?.assistantTurnTaskController.cancel()
        },
        cancelActiveAssistantRequest: { [weak self] in
            self?.openClawGatewayCompanionAgent.cancelActiveRequest()
        },
        clearDetectedElementLocation: { [weak self] in
            self?.clearDetectedElementLocation()
        },
        detectedElementScreenLocation: { [weak self] in
            self?.surfaceController.detectedElementScreenLocation
        },
        showTransientOverlay: { [weak self] in
            guard let self else { return }
            self.overlayWindowManager.hasShownOverlayBefore = true
            self.overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
            self.surfaceController.isOverlayVisible = true
        },
        isTutorialPlaybackVisible: { [weak self] in
            self?.tutorialController.tutorialPlaybackState?.isVisible == true
        },
        handleTutorialPlaybackKeyboardCommand: { [weak self] command in
            self?.handleTutorialPlaybackKeyboardCommand(command)
        },
        dismissOnboardingPrompt: { [weak self] in
            self?.dismissOnboardingPromptIfNeeded()
        },
        submitTranscript: { [weak self] finalTranscript in
            self?.surfaceController.lastTranscript = finalTranscript
            self?.submitTranscriptToSelectedAgent(finalTranscript)
        }
    )

    private var preferencesObjectWillChangeCancellable: AnyCancellable?
    private var backendRoutingObjectWillChangeCancellable: AnyCancellable?
    private var launchAccessObjectWillChangeCancellable: AnyCancellable?
    private var tutorialObjectWillChangeCancellable: AnyCancellable?
    private var surfaceObjectWillChangeCancellable: AnyCancellable?
    private var speechProviderObjectWillChangeCancellable: AnyCancellable?

    @Published private(set) var isRequestingScreenContent = false

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
        permissionCoordinator.allPermissionsGranted
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

    var clickyPersonaScopeMode: ClickyPersonaScopeMode {
        get { preferences.clickyPersonaScopeMode }
        set {
            guard preferences.clickyPersonaScopeMode != newValue else { return }
            preferences.clickyPersonaScopeMode = newValue
            openClawShellLifecycleController.refreshLifecycle()
        }
    }

    var clickyPersonaOverrideName: String {
        get { preferences.clickyPersonaOverrideName }
        set {
            guard preferences.clickyPersonaOverrideName != newValue else { return }
            preferences.clickyPersonaOverrideName = newValue
            openClawShellLifecycleController.refreshLifecycle()
        }
    }

    var clickyPersonaOverrideInstructions: String {
        get { preferences.clickyPersonaOverrideInstructions }
        set {
            guard preferences.clickyPersonaOverrideInstructions != newValue else { return }
            preferences.clickyPersonaOverrideInstructions = newValue
            openClawShellLifecycleController.refreshLifecycle()
        }
    }

    var clickyPersonaPreset: ClickyPersonaPreset {
        get { preferences.clickyPersonaPreset }
        set {
            guard preferences.clickyPersonaPreset != newValue else { return }
            preferences.clickyPersonaPreset = newValue
            openClawShellLifecycleController.refreshLifecycle()
        }
    }

    var clickyPersonaToneInstructions: String {
        get { preferences.clickyPersonaToneInstructions }
        set {
            guard preferences.clickyPersonaToneInstructions != newValue else { return }
            preferences.clickyPersonaToneInstructions = newValue
            openClawShellLifecycleController.refreshLifecycle()
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
        ClickyLaunchPresentation.authStatusLabel(for: clickyLaunchAuthState)
    }

    var clickyLaunchBillingStatusLabel: String {
        ClickyLaunchPresentation.billingStatusLabel(for: clickyLaunchBillingState)
    }

    var clickyLaunchTrialStatusLabel: String {
        ClickyLaunchPresentation.trialStatusLabel(for: clickyLaunchTrialState)
    }

    var isClickyLaunchSignedIn: Bool {
        ClickyLaunchPresentation.isSignedIn(clickyLaunchAuthState)
    }

    var clickyLaunchDisplayName: String {
        ClickyLaunchPresentation.displayName(
            profileName: clickyLaunchProfileName,
            authState: clickyLaunchAuthState
        )
    }

    var clickyLaunchDisplayInitials: String {
        ClickyLaunchPresentation.initials(for: clickyLaunchDisplayName)
    }

    var hasUnlimitedClickyLaunchAccess: Bool {
        launchTurnGate.hasUnlimitedAccess()
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
        launchTurnGate.requiresRepurchaseForCompanionUse()
    }

    var requiresLaunchEntitlementRefreshForCompanionUse: Bool {
        launchTurnGate.requiresEntitlementRefreshForCompanionUse()
    }

    var requiresLaunchSignInForCompanionUse: Bool {
        launchTurnGate.requiresSignInForCompanionUse(
            hasCompletedOnboarding: hasCompletedOnboarding,
            allPermissionsGranted: allPermissionsGranted
        )
    }

    var isClickyLaunchPaywallActive: Bool {
        launchTurnGate.isPaywallActive()
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
        personaPromptCoordinator.effectiveSpeechInstructions
    }

    func setClickyPersonaPreset(_ preset: ClickyPersonaPreset) {
        settingsMutationCoordinator.setPersonaPreset(preset)
    }

    func saveElevenLabsAPIKey() {
        speechProviderCoordinator.saveAPIKey()
    }

    func deleteElevenLabsAPIKey() {
        speechProviderCoordinator.deleteAPIKey()
    }

    func refreshElevenLabsVoices() {
        speechProviderCoordinator.refreshVoices()
    }

    func selectElevenLabsVoice(_ voice: ElevenLabsVoiceOption) {
        speechProviderCoordinator.selectVoice(voice)
    }

    func importElevenLabsVoiceByID() {
        speechProviderCoordinator.importVoiceByID()
    }

    func previewCurrentSpeechOutput() {
        speechProviderCoordinator.previewCurrentOutput()
    }

    func setSelectedModel(_ model: String) {
        settingsMutationCoordinator.setSelectedModel(model)
    }

    func startClickyLaunchSignIn() {
        launchFlowCoordinator.startSignIn()
    }

    func signOutClickyLaunchSession() {
        launchFlowCoordinator.signOut()
    }

    func startClickyLaunchCheckout() {
        launchFlowCoordinator.startCheckout()
    }

    func refreshClickyLaunchEntitlement() {
        launchFlowCoordinator.refreshEntitlement()
    }

    func restoreClickyLaunchAccess() {
        launchFlowCoordinator.restoreAccess()
    }

    func handleClickyLaunchCallback(url: URL) {
        launchFlowCoordinator.handleCallback(url: url)
    }

    func setSelectedAgentBackend(_ selectedAgentBackend: CompanionAgentBackend) {
        settingsMutationCoordinator.setSelectedBackend(selectedAgentBackend)
    }

    func setClickySpeechProviderMode(_ mode: ClickySpeechProviderMode) {
        speechProviderCoordinator.setProviderMode(mode)
    }

    func setOpenClawGatewayURL(_ gatewayURL: String) {
        settingsMutationCoordinator.setOpenClawGatewayURL(gatewayURL)
    }

    func setOpenClawAgentIdentifier(_ agentIdentifier: String) {
        settingsMutationCoordinator.setOpenClawAgentIdentifier(agentIdentifier)
    }

    func setOpenClawGatewayAuthToken(_ authToken: String) {
        settingsMutationCoordinator.setOpenClawGatewayAuthToken(authToken)
    }

    func setOpenClawSessionKey(_ sessionKey: String) {
        settingsMutationCoordinator.setOpenClawSessionKey(sessionKey)
    }

    var openClawGatewayAuthSummary: String {
        openClawStudioCoordinator.gatewayAuthSummary
    }

    var isOpenClawGatewayRemote: Bool {
        openClawStudioCoordinator.isGatewayRemote
    }

    var clickyOpenClawPluginIdentifier: String {
        openClawStudioCoordinator.pluginIdentifier
    }

    var clickyOpenClawPluginStatus: ClickyOpenClawPluginStatus {
        openClawStudioCoordinator.pluginStatus
    }

    var clickyOpenClawPluginStatusLabel: String {
        openClawStudioCoordinator.pluginStatusLabel
    }

    var clickyOpenClawPluginInstallPathHint: String {
        openClawStudioCoordinator.pluginInstallPathHint
    }

    var clickyOpenClawPluginInstallCommand: String {
        openClawStudioCoordinator.pluginInstallCommand
    }

    var clickyOpenClawPluginEnableCommand: String {
        openClawStudioCoordinator.pluginEnableCommand
    }

    var clickyOpenClawRemoteReadinessSummary: String {
        openClawStudioCoordinator.remoteReadinessSummary
    }

    var clickyShellRegistrationStatusLabel: String {
        openClawStudioCoordinator.shellRegistrationStatusLabel
    }

    var clickyShellServerSessionKeyLabel: String {
        openClawStudioCoordinator.shellServerSessionKeyLabel
    }

    var clickyShellServerFreshnessLabel: String {
        openClawStudioCoordinator.shellServerFreshnessLabel
    }

    var clickyShellServerTrustLabel: String {
        openClawStudioCoordinator.shellServerTrustLabel
    }

    var clickyShellServerBindingLabel: String {
        openClawStudioCoordinator.shellServerBindingLabel
    }

    var effectiveOpenClawAgentName: String {
        openClawStudioCoordinator.effectiveAgentName
    }

    var inferredOpenClawAgentIdentityDisplayName: String {
        openClawStudioCoordinator.inferredIdentityDisplayName
    }

    var inferredOpenClawAgentIdentityEmojiLabel: String {
        openClawStudioCoordinator.inferredIdentityEmojiLabel
    }

    var inferredOpenClawAgentIdentityAvatarLabel: String {
        openClawStudioCoordinator.inferredIdentityAvatarLabel
    }

    var effectiveClickyPresentationName: String {
        personaPromptCoordinator.effectivePresentationName
    }

    var clickyPersonaScopeLabel: String {
        personaPromptCoordinator.personaScopeLabel
    }

    var activeClickyPersonaLabel: String {
        personaPromptCoordinator.activePersonaLabel
    }

    var selectedAssistantModelIdentityLabel: String {
        personaPromptCoordinator.selectedAssistantModelIdentityLabel
    }

    private func playSpeechText(
        _ text: String,
        purpose: ClickySpeechPlaybackPurpose
    ) async -> ClickySpeechPlaybackOutcome {
        await speechPlaybackCoordinator.play(text, purpose: purpose)
    }

    func testOpenClawConnection() {
        openClawStudioCoordinator.testConnection()
    }

    func refreshCodexRuntimeStatus() {
        codexRuntimeCoordinator.refreshRuntimeStatus()
    }

    var codexRuntimeStatusLabel: String {
        codexRuntimeCoordinator.statusLabel
    }

    var codexRuntimeSummaryCopy: String {
        codexRuntimeCoordinator.summaryCopy
    }

    var codexReadinessChipLabels: [String] {
        codexRuntimeCoordinator.readinessChipLabels
    }

    var codexConfiguredModelLabel: String {
        codexRuntimeCoordinator.configuredModelLabel
    }

    var codexAccountLabel: String {
        codexRuntimeCoordinator.accountLabel
    }

    func openCodexInstallPage() {
        codexRuntimeCoordinator.openInstallPage()
    }

    func startCodexLoginInTerminal() {
        codexRuntimeCoordinator.startLoginInTerminal()
    }

    func registerClickyShellNow() {
        openClawStudioCoordinator.registerShellNow()
    }

    func refreshClickyShellStatusNow() {
        openClawStudioCoordinator.refreshShellStatusNow()
    }

    func refreshOpenClawAgentIdentity() {
        openClawStudioCoordinator.refreshAgentIdentity()
    }

    /// User preference for whether the Clicky cursor should be shown.
    /// When toggled off, the overlay is hidden and push-to-talk is disabled.
    /// Persisted to UserDefaults so the choice survives app restarts.
    var isClickyCursorEnabled: Bool {
        get { preferences.isClickyCursorEnabled }
        set { preferences.isClickyCursorEnabled = newValue }
    }

    func setClickyCursorEnabled(_ enabled: Bool) {
        surfaceLifecycleCoordinator.setCursorEnabled(enabled)
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

        launchRuntimeCoordinator.restoreSessionIfPossible()
        refreshAllPermissions()
        permissionCoordinator.startPolling()
        voiceSessionCoordinator.start()
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

        openClawShellLifecycleController.refreshLifecycle()
        refreshOpenClawAgentIdentity()
        refreshCodexRuntimeStatus()

        // If the user already completed onboarding AND all permissions are
        // still granted, show the cursor overlay immediately. If permissions
        // were revoked (e.g. signing change), don't show the cursor — the
        // panel will show the permissions UI instead.
        surfaceLifecycleCoordinator.showOverlayIfReady()

        ClickyUnifiedTelemetry.lifecycle.info(
            "Companion start completed backend=\(self.selectedAgentBackend.displayName, privacy: .public) permissions=\(self.allPermissionsGranted ? "ready" : "needs-attention", privacy: .public) onboarding=\(self.hasCompletedOnboarding ? "complete" : "pending", privacy: .public) overlay=\(self.surfaceController.isOverlayVisible ? "shown" : "hidden", privacy: .public)"
        )
    }

    /// Called by BlueCursorView after the buddy finishes its pointing
    /// animation and returns to cursor-following mode.
    /// Triggers the onboarding sequence — dismisses the panel and restarts
    /// the overlay so the welcome animation and intro video play.
    func triggerOnboarding() {
        surfaceLifecycleCoordinator.triggerOnboarding()
    }

    /// Replays the onboarding experience from the "Watch Onboarding Again"
    /// footer link. Same flow as triggerOnboarding but the cursor overlay
    /// is already visible so we just restart the welcome animation and video.
    func replayOnboarding() {
        surfaceLifecycleCoordinator.replayOnboarding()
    }

    func clearDetectedElementLocation() {
        pointingSequenceController.clear()
    }

    func advanceDetectedElementLocation() {
        pointingSequenceController.advance()
    }

    private func queueDetectedElementTargets(_ targets: [QueuedPointingTarget]) {
        pointingSequenceController.queue(targets)
    }

    var hasPendingDetectedElementTargets: Bool {
        pointingSequenceController.hasPendingTargets
    }

    var isManagingPointSequence: Bool {
        pointingSequenceController.isManagedSequenceActive
    }

    func notifyManagedPointTargetArrived() {
        pointingSequenceController.notifyTargetArrived()
    }

    private func waitForManagedPointTargetArrival() async {
        await pointingSequenceController.waitForTargetArrival()
    }

    private func requestManagedPointSequenceReturn() {
        pointingSequenceController.requestManagedSequenceReturn()
    }

    private func waitForSpeechPlaybackToFinishIfNeeded() async {
        await elevenLabsTTSClient.waitUntilPlaybackFinishes()
    }

    private func playManagedPointSequence(
        introText: String,
        responsePoints: [ClickyAssistantResponsePoint],
        resolvedTargets: [QueuedPointingTarget]
    ) async {
        let narrationSteps = ClickyPointingCoordinator.managedPointNarrationSteps(from: responsePoints)
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

        pointingSequenceController.beginManagedSequence()
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

    func startTutorialImportFromPanel() {
        tutorialImportCoordinator.startImportFromPanel()
    }

    func startTutorialLessonFromReadyState() {
        tutorialPlaybackCoordinator.startLessonFromReadyState()
    }

    func advanceTutorialLessonFromPanel() {
        tutorialPlaybackCoordinator.advanceLessonFromPanel()
    }

    func rewindTutorialLessonFromPanel() {
        tutorialPlaybackCoordinator.rewindLessonFromPanel()
    }

    func repeatTutorialLessonStepFromPanel() {
        tutorialPlaybackCoordinator.repeatLessonStepFromPanel()
    }

    func retryTutorialImportFromPanel() {
        tutorialImportCoordinator.retryImportFromPanel()
    }

    private func compileTutorialLessonDraft(
        evidenceBundle: TutorialEvidenceBundle
    ) async throws -> TutorialLessonDraft {
        try await tutorialLessonCompiler.compile(evidenceBundle: evidenceBundle)
    }

    func startTutorialPlayback(
        sourceURL: String,
        embedURL: String,
        step: TutorialLessonStep? = nil,
        bubbleText: String? = nil,
        promptTimestampSeconds: Int? = nil,
        autoPlay: Bool = true
    ) {
        tutorialPlaybackCoordinator.startPlayback(
            sourceURL: sourceURL,
            embedURL: embedURL,
            step: step,
            bubbleText: bubbleText ?? "Space play/pause  Left back 10s  Right forward 10s  Esc close",
            promptTimestampSeconds: promptTimestampSeconds,
            autoPlay: autoPlay
        )
    }

    private func updateTutorialPlaybackState(step: TutorialLessonStep, isPlaying: Bool) {
        tutorialPlaybackCoordinator.updatePlaybackState(step: step, isPlaying: isPlaying)
    }

    func updateTutorialPlaybackBubble(_ text: String?) {
        tutorialPlaybackCoordinator.updateBubble(text)
    }

    func pauseTutorialPlaybackForPointing() {
        tutorialPlaybackCoordinator.pauseForPointing()
    }

    func resumeTutorialPlaybackAfterPointingIfNeeded() {
        tutorialPlaybackCoordinator.resumeAfterPointingIfNeeded()
    }

    func stopTutorialPlayback() {
        tutorialPlaybackCoordinator.stopPlayback()
    }

    func handleTutorialPlaybackKeyboardCommand(_ command: TutorialPlaybackCommand) {
        tutorialPlaybackCoordinator.handleKeyboardCommand(command)
    }

    func stop() {
        globalPushToTalkShortcutMonitor.stop()
        buddyDictationManager.cancelCurrentDictation()
        overlayWindowManager.hideOverlay()
        stopTutorialPlayback()
        voiceSessionCoordinator.cancelTransientHide()
        launchRuntimeCoordinator.stop()
        openClawShellLifecycleController.stop()
        onboardingMusicController.stop()

        assistantTurnTaskController.stop()
        voiceSessionCoordinator.stop()
        permissionCoordinator.stopPolling()
    }

    private var clickyBackendAuthClient: ClickyBackendAuthClient {
        ClickyBackendAuthClient(baseURL: clickyBackendBaseURL)
    }

    func handleApplicationDidBecomeActive() {
        launchRuntimeCoordinator.handleApplicationDidBecomeActive()
    }

    func refreshClickyLaunchEntitlementQuietlyIfNeeded(
        reason: String,
        minimumInterval: TimeInterval = 90
    ) {
        launchRuntimeCoordinator.refreshEntitlementQuietlyIfNeeded(
            reason: reason,
            minimumInterval: minimumInterval
        )
    }

    private func presentLaunchSignInRequiredState(openStudio: Bool) {
        launchBlockedTurnPresenter.presentSignInRequired(
            authState: clickyLaunchAuthState,
            openStudio: openStudio
        )
    }

    private func presentLaunchAccessRecoveryState(
        openStudio: Bool,
        message: String,
        logReason: String
    ) {
        launchBlockedTurnPresenter.presentAccessRecovery(
            openStudio: openStudio,
            message: message,
            logReason: logReason
        )
    }

    private func presentLaunchPaywallLockedState(openStudio: Bool) {
        launchBlockedTurnPresenter.presentPaywallLocked(openStudio: openStudio)
    }

    func refreshClickyLaunchTrialState() {
        launchRuntimeCoordinator.refreshTrialState()
    }

    func activateClickyLaunchTrial() {
        launchRuntimeCoordinator.activateTrial()
    }

    func consumeClickyLaunchTrialCredit() {
        launchRuntimeCoordinator.consumeTrialCredit()
    }

    func activateClickyLaunchPaywall() {
        launchRuntimeCoordinator.activatePaywall()
    }

    func refreshAllPermissions() {
        permissionCoordinator.refreshAllPermissions()
    }

    /// Triggers the macOS screen content picker by performing a dummy
    /// screenshot capture. Once the user approves, we persist the grant
    /// so they're never asked again during onboarding.
    func requestScreenContentPermission() {
        permissionCoordinator.requestScreenContentPermission()
    }

    // MARK: - Private

    /// Triggers the system microphone prompt if the user has never been asked.
    /// Once granted/denied the status sticks and polling picks it up.
    private func promptForMicrophoneIfNotDetermined() {
        permissionCoordinator.promptForMicrophoneIfNotDetermined()
    }

    private func preparePushToTalkSessionIfAllowed() -> Bool {
        guard !surfaceController.showOnboardingVideo else { return false }

        if requiresLaunchRepurchaseForCompanionUse {
            presentLaunchAccessRecoveryState(
                openStudio: true,
                message: "your launch pass is no longer active. open studio to buy again or restore access if this looks wrong.",
                logReason: "launch entitlement requires repurchase"
            )
            return false
        }

        if requiresLaunchEntitlementRefreshForCompanionUse {
            presentLaunchAccessRecoveryState(
                openStudio: true,
                message: "your cached access expired and clicky needs to refresh it. open studio and run refresh access before starting a new assisted turn.",
                logReason: "launch entitlement grace expired"
            )
            return false
        }

        if requiresLaunchSignInForCompanionUse {
            presentLaunchSignInRequiredState(openStudio: true)
            return false
        }

        if isClickyLaunchPaywallActive {
            presentLaunchPaywallLockedState(openStudio: true)
            return false
        }

        return true
    }

    private func dismissOnboardingPromptIfNeeded() {
        guard surfaceController.showOnboardingPrompt else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            surfaceController.onboardingPromptOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.surfaceController.showOnboardingPrompt = false
            self.surfaceController.onboardingPromptText = ""
        }
    }

    // MARK: - AI Response Pipeline

    /// Captures a screenshot, sends it along with the transcript to Claude,
    /// and plays the response aloud via ElevenLabs TTS. The cursor stays in
    /// the spinner/processing state until TTS audio begins playing.
    /// The assistant response should be a structured object with spoken text
    /// plus ordered point targets for the cursor overlay.
    private func submitTranscriptToSelectedAgent(
        _ transcript: String,
        historyTranscriptOverride: String? = nil,
        skipsPreflightIntentHandlers: Bool = false
    ) {
        assistantTurnTaskController.submitTranscript(
            transcript,
            historyTranscriptOverride: historyTranscriptOverride,
            skipsPreflightIntentHandlers: skipsPreflightIntentHandlers
        )
    }

    @MainActor
    private func handleTutorialModeTurnIfNeeded(for transcript: String) async -> Bool {
        await tutorialModeCoordinator.handleTurnIfNeeded(for: transcript)
    }

    @MainActor
    private func handleTutorialImportIntentIfNeeded(for transcript: String) async -> Bool {
        let normalizedTranscript = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard ClickyTutorialModeIntentMatcher.isImportIntent(normalizedTranscript) else {
            return false
        }

        tutorialController.tutorialImportStatusMessage = "Open the companion menu and paste the YouTube URL to begin."
        NotificationCenter.default.post(name: .clickyShowPanel, object: nil)
        surfaceController.voiceState = .responding
        _ = await playSpeechText(
            "open the companion menu and paste the youtube url to begin. once it's there, hit start learning and i'll guide you through it.",
            purpose: .systemMessage
        )
        return true
    }

    /// If the cursor is in transient mode (user toggled "Show Clicky" off),
    /// waits for TTS playback and any pointing animation to finish, then
    /// fades out the overlay after a 1-second pause. Cancelled automatically
    /// if the user starts another push-to-talk interaction.
    private func scheduleTransientHideIfNeeded() {
        voiceSessionCoordinator.scheduleTransientHideIfNeeded()
    }

    // MARK: - Onboarding Video

    /// Sets up the onboarding video player, starts playback, and schedules
    /// the demo interaction at 40s. Called by BlueCursorView when onboarding starts.
    func setupOnboardingVideo() {
        onboardingVideoController.setupVideo()
    }

    func tearDownOnboardingVideo() {
        onboardingVideoController.tearDownVideo()
    }

    // MARK: - Onboarding Demo Interaction

    /// Captures a screenshot and asks Claude to find something interesting to
    /// point at, then triggers the buddy's flight animation. Used during
    /// onboarding to demo the pointing feature while the intro video plays.
    func performOnboardingDemoInteraction() {
        onboardingDemoController.perform()
    }
}
