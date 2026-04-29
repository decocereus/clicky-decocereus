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
        return ClaudeAPI(proxyURL: "\(CompanionRuntimeConfiguration.workerBaseURL)/chat", model: preferences.selectedModel)
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
                selectedBackend: self.preferences.selectedAgentBackend,
                gatewayURL: self.preferences.openClawGatewayURL,
                gatewayAuthToken: self.preferences.openClawGatewayAuthToken,
                isGatewayRemote: ClickyOpenClawStudioCoordinator.isGatewayRemote(self.preferences.openClawGatewayURL),
                isLocalPluginEnabled: Self.currentOpenClawPluginStatus() == .enabled,
                effectiveAgentName: ClickyOpenClawStudioCoordinator.effectiveAgentName(
                    manualName: self.preferences.openClawAgentName,
                    inferredName: self.backendRoutingController.inferredOpenClawAgentIdentityName
                ),
                effectivePresentationName: ClickyPersonaPromptCoordinator.effectivePresentationName(
                    selectedBackend: self.preferences.selectedAgentBackend,
                    personaScopeMode: self.preferences.clickyPersonaScopeMode,
                    personaOverrideName: self.preferences.clickyPersonaOverrideName,
                    effectiveOpenClawAgentName: ClickyOpenClawStudioCoordinator.effectiveAgentName(
                        manualName: self.preferences.openClawAgentName,
                        inferredName: self.backendRoutingController.inferredOpenClawAgentIdentityName
                    )
                ),
                personaScopeMode: self.preferences.clickyPersonaScopeMode,
                sessionKey: self.preferences.openClawSessionKey
            )
        }
    )
    lazy var openClawStudioCoordinator = ClickyOpenClawStudioCoordinator(
        preferences: preferences,
        backendRoutingController: backendRoutingController,
        gatewayAgent: openClawGatewayCompanionAgent,
        shellLifecycleController: openClawShellLifecycleController,
        selectedBackendProvider: { [weak self] in
            self?.preferences.selectedAgentBackend ?? .claude
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
                    gatewayURLString: self.preferences.openClawGatewayURL,
                    gatewayAuthToken: self.preferences.openClawGatewayAuthToken,
                    agentIdentifier: self.preferences.openClawAgentIdentifier,
                    sessionKey: self.preferences.openClawSessionKey,
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
        onRequestingScreenContentChanged: { [weak self] _ in
            self?.objectWillChange.send()
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
    private lazy var managedPointingPlaybackCoordinator = ClickyManagedPointingPlaybackCoordinator(
        pointingSequenceController: pointingSequenceController,
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
        waitForSpeechPlaybackToFinish: { [weak self] in
            await self?.elevenLabsTTSClient.waitUntilPlaybackFinishes()
        }
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
            self?.onboardingDemoController.perform()
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
    private lazy var launchPreflightCoordinator = ClickyLaunchPreflightCoordinator(
        launchTurnGate: launchTurnGate,
        blockedTurnPresenter: launchBlockedTurnPresenter,
        authStateProvider: { [weak self] in
            self?.launchAccessController.clickyLaunchAuthState ?? .signedOut
        },
        hasCompletedOnboarding: { [weak self] in
            self?.hasCompletedOnboarding == true
        },
        allPermissionsGranted: { [weak self] in
            self?.allPermissionsGranted == true
        },
        isOnboardingVideoVisible: { [weak self] in
            self?.surfaceController.showOnboardingVideo == true
        }
    )
    private lazy var lifecycleCoordinator = ClickyCompanionLifecycleCoordinator(
        preferences: preferences,
        settingsMutationCoordinator: settingsMutationCoordinator,
        launchRuntimeCoordinator: launchRuntimeCoordinator,
        permissionCoordinator: permissionCoordinator,
        voiceSessionCoordinator: voiceSessionCoordinator,
        dictationManager: buddyDictationManager,
        shortcutMonitor: globalPushToTalkShortcutMonitor,
        overlayWindowManager: overlayWindowManager,
        surfaceLifecycleCoordinator: surfaceLifecycleCoordinator,
        openClawShellLifecycleController: openClawShellLifecycleController,
        openClawStudioCoordinator: openClawStudioCoordinator,
        codexRuntimeCoordinator: codexRuntimeCoordinator,
        onboardingMusicController: onboardingMusicController,
        assistantTurnTaskController: assistantTurnTaskController,
        stopTutorialPlayback: { [weak self] in
            self?.stopTutorialPlayback()
        },
        warmClaudeAPI: { [weak self] in
            guard let self else { return }
            _ = self.claudeAPI
        },
        allPermissionsGranted: { [weak self] in
            self?.allPermissionsGranted == true
        },
        hasCompletedOnboarding: { [weak self] in
            self?.hasCompletedOnboarding == true
        },
        isOverlayVisible: { [weak self] in
            self?.surfaceController.isOverlayVisible == true
        }
    )
    private lazy var tutorialPlaybackCoordinator = ClickyTutorialPlaybackCoordinator(
        tutorialController: tutorialController
    )
    private lazy var tutorialImportVoiceIntentCoordinator = ClickyTutorialImportVoiceIntentCoordinator(
        tutorialController: tutorialController,
        surfaceController: surfaceController,
        playSpeech: { [weak self] text, purpose in
            guard let self else {
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "Unavailable",
                    fallbackMessage: "Companion manager was released.",
                    encounteredElevenLabsFailure: false
                )
            }
            return await self.playSpeechText(text, purpose: purpose)
        }
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
            self?.preferences.clickyVoicePreset ?? .balanced
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
                selectedBackend: self.preferences.selectedAgentBackend,
                selectedModel: self.preferences.selectedModel,
                codexConfiguredModelName: self.backendRoutingController.codexConfiguredModelName,
                openClawAgentIdentifier: self.preferences.openClawAgentIdentifier,
                inferredOpenClawAgentIdentifier: self.backendRoutingController.inferredOpenClawAgentIdentifier,
                effectiveOpenClawAgentName: self.openClawStudioCoordinator.effectiveAgentName,
                personaScopeMode: self.preferences.clickyPersonaScopeMode,
                personaOverrideName: self.preferences.clickyPersonaOverrideName,
                personaOverrideInstructions: self.preferences.clickyPersonaOverrideInstructions,
                activePersonaDefinition: self.preferences.clickyPersonaPreset.definition,
                voicePreset: self.preferences.clickyVoicePreset,
                cursorStyle: self.preferences.clickyCursorStyle,
                customToneInstructions: self.preferences.clickyPersonaToneInstructions
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
            self?.preferences.selectedAgentBackend ?? .claude
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
            await self?.managedPointingPlaybackCoordinator.play(
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
            await self?.tutorialImportVoiceIntentCoordinator.handleIntentIfNeeded(for: transcript) ?? false
        },
        handleTutorialModeTurn: { [weak self] transcript in
            await self?.tutorialModeCoordinator.handleTurnIfNeeded(for: transcript) ?? false
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
            self?.preferences.selectedAgentBackend ?? .claude
        }
    )
    private lazy var tutorialImportCoordinator = ClickyTutorialImportCoordinator(
        tutorialController: tutorialController,
        backendURLProvider: { [weak self] in
            self?.preferences.clickyBackendBaseURL ?? ""
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
            self?.preferences.selectedAgentBackend ?? .claude
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
            self?.launchPreflightCoordinator.canBeginPushToTalkSession() ?? false
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
            self?.onboardingVideoController.dismissPromptIfNeeded()
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

    var isRequestingScreenContent: Bool {
        permissionCoordinator.isScreenContentRequestInFlight
    }

    private static func currentOpenClawPluginStatus() -> ClickyOpenClawPluginStatus {
        ClickyOpenClawStudioCoordinator.pluginStatus(
            openClawConfiguration: ClickyOpenClawStudioCoordinator.loadLocalOpenClawConfiguration()
        )
    }

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

    var isClickyLaunchAuthPending: Bool {
        switch launchAccessController.clickyLaunchAuthState {
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
        lifecycleCoordinator.start()
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
        lifecycleCoordinator.stop()
    }

    private var clickyBackendAuthClient: ClickyBackendAuthClient {
        ClickyBackendAuthClient(baseURL: preferences.clickyBackendBaseURL)
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

}
