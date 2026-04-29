//
//  ClickyRefactorTests.swift
//  leanring-buddyTests
//

import Foundation
import CoreGraphics
import Testing
@testable import Clicky

private final class CapturingAssistantProvider: ClickyAssistantProvider {
    let backend: CompanionAgentBackend = .claude
    let responseText: String
    private(set) var lastUserPrompt: String?

    init(responseText: String) {
        self.responseText = responseText
    }

    func sendTurn(
        _ request: ClickyAssistantTurnRequest,
        onTextChunk: @MainActor @escaping @Sendable (String) -> Void
    ) async throws -> ClickyAssistantTurnResponse {
        lastUserPrompt = request.userPrompt
        return ClickyAssistantTurnResponse(text: responseText, duration: 0)
    }
}

@MainActor
struct ClickyRefactorTests {
    @Test
    func responseContractPromptAdvertisesAllPresentationModes() {
        let promptInstructions = ClickyAssistantResponseContract.promptInstructions

        #expect(promptInstructions.contains("answer|point|walkthrough|tutorial"))
        #expect(promptInstructions.contains("\"mode\""))
        #expect(promptInstructions.contains("\"spokenText\""))
        #expect(promptInstructions.contains("\"points\""))
        #expect(promptInstructions.contains("\"explanation\""))
    }

    @Test
    func responseContractParsesAnswerPointAndWalkthroughModes() throws {
        let answer = try ClickyAssistantResponseContract.parse(
            rawResponse: #"{"mode":"answer","spokenText":"hello there.","points":[]}"#,
            requiresPoints: false
        )
        #expect(answer.mode == .answer)
        #expect(answer.spokenText == "hello there.")
        #expect(answer.points.isEmpty)

        let point = try ClickyAssistantResponseContract.parse(
            rawResponse: #"{"mode":"point","spokenText":"use save.","points":[{"x":820,"y":460,"label":"Save button","bubbleText":"Save","explanation":"This button saves your changes.","screenNumber":1}]}"#,
            requiresPoints: true
        )
        #expect(point.mode == .point)
        #expect(point.points.count == 1)
        #expect(point.points[0].x == 820)
        #expect(point.points[0].explanation == "This button saves your changes.")

        let walkthrough = try ClickyAssistantResponseContract.parse(
            rawResponse: #"{"mode":"walkthrough","spokenText":"here is the tour.","points":[{"x":260,"y":210,"label":"Account","bubbleText":"Account","explanation":"Start with account settings."},{"x":260,"y":310,"label":"Voice","bubbleText":"Voice","explanation":"Then check voice settings."}]}"#,
            requiresPoints: true
        )
        #expect(walkthrough.mode == .walkthrough)
        #expect(walkthrough.points.count == 2)
    }

    @Test
    func responseContractRejectsPointingRequestsWithoutPoints() {
        do {
            _ = try ClickyAssistantResponseContract.parse(
                rawResponse: #"{"mode":"answer","spokenText":"i cannot point at that.","points":[]}"#,
                requiresPoints: true
            )
            Issue.record("Expected response contract parsing to fail when pointing is required.")
        } catch let ClickyAssistantResponseContractError.invalidResponse(issues, _) {
            #expect(issues.contains("points array was empty even though the request required pointing"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func assistantResponseRepairerRequiresPointingForVisibleControlRequests() {
        #expect(ClickyAssistantResponseRepairer.transcriptRequiresVisiblePointing("show me the button"))
        #expect(ClickyAssistantResponseRepairer.transcriptRequiresVisiblePointing("where is the settings icon?"))
        #expect(!ClickyAssistantResponseRepairer.transcriptRequiresVisiblePointing("tell me a joke"))
    }

    @Test
    func assistantResponseRepairerAuditsNarratedWalkthroughExplanations() {
        let registry = ClickyAssistantProviderRegistry(providers: [])
        let repairer = ClickyAssistantResponseRepairer(
            assistantTurnExecutor: ClickyAssistantTurnExecutor(providerRegistry: registry)
        )
        let response = """
        {"mode":"walkthrough","spokenText":"here are the controls.","points":[{"x":100,"y":120,"label":"Fan"},{"x":200,"y":220,"label":"Temperature","explanation":"This adjusts temperature."}]}
        """

        let audit = repairer.audit(
            responseText: response,
            transcript: "walk me through the climate controls"
        )

        #expect(audit.needsRepair)
        #expect(audit.issues.contains("point 1 was missing an explanation"))
    }

    @Test
    func assistantResponseRepairerSendsRepairPromptToBackend() async throws {
        let provider = CapturingAssistantProvider(
            responseText: #"{"mode":"point","spokenText":"Use the Save button.","points":[{"x":100,"y":120,"label":"Save button","bubbleText":"Save","explanation":"This saves your work."}]}"#
        )
        let registry = ClickyAssistantProviderRegistry(providers: [provider])
        let repairer = ClickyAssistantResponseRepairer(
            assistantTurnExecutor: ClickyAssistantTurnExecutor(providerRegistry: registry)
        )

        let repairedResponse = try await repairer.repairIfNeeded(
            backend: .claude,
            originalResponseText: "Use the Save button.",
            transcript: "show me the save button",
            baseSystemPrompt: "Base prompt",
            labeledImages: [],
            focusContext: nil,
            conversationHistory: [],
            audit: ClickyAssistantResponseAudit(issues: ["response was not a single json object"])
        )

        #expect(repairedResponse.structuredResponse.spokenText == "Use the Save button.")
        #expect(provider.lastUserPrompt?.contains("repair context:") == true)
        #expect(provider.lastUserPrompt?.contains("invalid previous reply:") == true)
        #expect(provider.lastUserPrompt != "show me the save button")
    }

    @Test
    func pointingCoordinatorParsesLegacyPointTags() {
        let result = ClickyPointingCoordinator.parsePointingCoordinates(
            from: "look here [POINT:120,240:screen2:Save button|save]"
        )

        #expect(result.spokenText == "look here")
        #expect(result.targets.count == 1)
        #expect(result.targets[0].coordinate == CGPoint(x: 120, y: 240))
        #expect(result.targets[0].screenNumber == 2)
        #expect(result.targets[0].elementLabel == "Save button")
        #expect(result.targets[0].bubbleText == "save")
    }

    @Test
    func pointingCoordinatorResolvesScreenshotPixelsToDisplayPoints() {
        let capture = CompanionScreenCapture(
            imageData: Data(),
            label: "primary focus",
            isCursorScreen: true,
            capturedAt: Date(),
            displayWidthInPoints: 500,
            displayHeightInPoints: 250,
            displayFrame: CGRect(x: 10, y: 20, width: 500, height: 250),
            screenshotWidthInPixels: 1000,
            screenshotHeightInPixels: 500
        )
        let targets = ClickyPointingCoordinator.resolvedPointingTargets(
            from: [
                ParsedPointingTarget(
                    coordinate: CGPoint(x: 500, y: 250),
                    elementLabel: "Center",
                    screenNumber: nil,
                    bubbleText: "center"
                )
            ],
            screenCaptures: [capture]
        )

        #expect(targets.count == 1)
        #expect(targets[0].screenLocation == CGPoint(x: 260, y: 145))
        #expect(targets[0].displayFrame == capture.displayFrame)
    }

    @Test
    @MainActor
    func preferencesStorePersistsSelectionsAcrossReloads() throws {
        let suiteName = "ClickyPreferencesStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated defaults suite")
            return
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = ClickyPreferencesStore(defaults: defaults)
        store.selectedAgentBackend = .codex
        store.clickyThemePreset = .light
        store.hasCompletedOnboarding = true

        let reloadedStore = ClickyPreferencesStore(defaults: defaults)

        #expect(reloadedStore.selectedAgentBackend == .codex)
        #expect(reloadedStore.clickyThemePreset == .light)
        #expect(reloadedStore.hasCompletedOnboarding)
    }

    @Test
    @MainActor
    func preferencesStoreMigratesLegacyBackendURL() throws {
        let suiteName = "ClickyBackendURLMigrationTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated defaults suite")
            return
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("https://api.clicky.app", forKey: "clickyBackendBaseURL")

        let store = ClickyPreferencesStore(defaults: defaults)
        let expectedDefaultURL = CompanionRuntimeConfiguration.defaultBackendBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(store.clickyBackendBaseURL == expectedDefaultURL)
        #expect(defaults.string(forKey: "clickyBackendBaseURL") == expectedDefaultURL)
    }

    @Test
    @MainActor
    func launchTurnGateRequiresSignInOnlyAfterSetupIsReady() {
        let accessController = ClickyLaunchAccessController()
        let sessionService = ClickyLaunchSessionService(
            client: ClickyBackendAuthClient(baseURL: "https://clicky.example"),
            accessController: accessController
        )
        let gate = ClickyLaunchTurnGate(
            accessController: accessController,
            sessionService: sessionService
        )

        accessController.clickyLaunchAuthState = .signedOut

        #expect(!gate.requiresSignInForCompanionUse(
            hasCompletedOnboarding: false,
            allPermissionsGranted: true
        ))
        #expect(!gate.requiresSignInForCompanionUse(
            hasCompletedOnboarding: true,
            allPermissionsGranted: false
        ))
        #expect(gate.requiresSignInForCompanionUse(
            hasCompletedOnboarding: true,
            allPermissionsGranted: true
        ))

        accessController.clickyLaunchAuthState = .signedIn(email: "user@example.com")
        #expect(!gate.requiresSignInForCompanionUse(
            hasCompletedOnboarding: true,
            allPermissionsGranted: true
        ))
    }

    @Test
    func launchPresentationFormatsSharedStatusLabels() {
        #expect(ClickyLaunchPresentation.authStatusLabel(for: .signedOut) == "Signed out")
        #expect(ClickyLaunchPresentation.authStatusLabel(for: .signedIn(email: "hello@clicky.app")) == "hello@clicky.app")
        #expect(ClickyLaunchPresentation.billingStatusLabel(for: .waitingForCompletion) == "Waiting for purchase")
        #expect(ClickyLaunchPresentation.trialStatusLabel(for: .active(remainingCredits: 3)) == "3 credits left")
        #expect(ClickyLaunchPresentation.isSignedIn(.signedIn(email: "hello@clicky.app")))
        #expect(!ClickyLaunchPresentation.isSignedIn(.failed(message: "Nope")))
        #expect(ClickyLaunchPresentation.hasUnlimitedAccess(.unlocked))
        #expect(!ClickyLaunchPresentation.hasUnlimitedAccess(.paywalled))
    }

    @Test
    func launchPresentationDerivesAccountNameAndInitials() {
        let localUserName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedFallbackName = localUserName.isEmpty ? "Grace Hopper" : localUserName

        #expect(
            ClickyLaunchPresentation.displayName(
                profileName: "  Ada Lovelace  ",
                authState: .signedIn(email: "ignored@clicky.app")
            ) == "Ada Lovelace"
        )
        #expect(
            ClickyLaunchPresentation.displayName(
                profileName: "",
                authState: .signedIn(email: "grace_hopper@clicky.app")
            ) == expectedFallbackName
        )
        #expect(ClickyLaunchPresentation.initials(for: "Ada Lovelace") == "AL")
        #expect(ClickyLaunchPresentation.initials(for: "Clicky") == "CL")
    }

    @Test
    func launchTurnAuthorizationMapsPromptModes() {
        #expect(LaunchAssistantTurnAuthorization.standard.promptMode == .standard)
        #expect(LaunchAssistantTurnAuthorization(
            session: nil,
            shouldUseWelcomeTurn: true,
            shouldUsePaywallTurn: false
        ).promptMode == .welcome)
        #expect(LaunchAssistantTurnAuthorization(
            session: nil,
            shouldUseWelcomeTurn: true,
            shouldUsePaywallTurn: true
        ).promptMode == .paywall)
    }

    @Test
    func launchAccessControllerFormatsEntitlementAccessRules() {
        let activeEntitlement = ClickyLaunchEntitlementSnapshot(
            productKey: "clicky-launch",
            status: "active",
            hasAccess: true,
            gracePeriodEndsAt: nil
        )
        let refundedEntitlement = ClickyLaunchEntitlementSnapshot(
            productKey: "clicky-launch",
            status: "refunded",
            hasAccess: false,
            gracePeriodEndsAt: nil
        )

        #expect(ClickyLaunchAccessController.entitlementHasEffectiveAccess(activeEntitlement))
        #expect(!ClickyLaunchAccessController.entitlementRequiresRepurchase(activeEntitlement))
        #expect(ClickyLaunchAccessController.entitlementRequiresRepurchase(refundedEntitlement))
        #expect(ClickyLaunchAccessController.formatEntitlementStatus(activeEntitlement) == "Active")
        #expect(ClickyLaunchAccessController.formatEntitlementStatus(refundedEntitlement) == "Refunded")
    }

    @Test
    func tutorialLessonCompilerExtractsJSONObjectFromWrappedResponse() {
        let wrappedResponse = """
        Sure, here is the draft:
        {"title":"Basics","summary":"Learn the flow","steps":[]}
        """

        #expect(
            ClickyTutorialLessonCompiler.extractJSONObject(from: wrappedResponse)
                == #"{"title":"Basics","summary":"Learn the flow","steps":[]}"#
        )
    }

    @Test
    func tutorialImportCoordinatorAcceptsOnlyYouTubeURLs() {
        #expect(ClickyTutorialImportCoordinator.isSupportedYouTubeURL("https://youtube.com/watch?v=abc"))
        #expect(ClickyTutorialImportCoordinator.isSupportedYouTubeURL("https://www.youtube.com/watch?v=abc"))
        #expect(ClickyTutorialImportCoordinator.isSupportedYouTubeURL("https://youtu.be/abc"))
        #expect(ClickyTutorialImportCoordinator.isSupportedYouTubeURL("https://music.youtube.com/watch?v=abc"))
        #expect(!ClickyTutorialImportCoordinator.isSupportedYouTubeURL("https://example.com/watch?v=abc"))
        #expect(!ClickyTutorialImportCoordinator.isSupportedYouTubeURL("not a url"))
    }

    @Test
    func tutorialModeIntentMatcherClassifiesCommonCommands() {
        #expect(ClickyTutorialModeIntentMatcher.shouldAdvanceStep("i am done, next"))
        #expect(ClickyTutorialModeIntentMatcher.shouldRepeatCurrentStep("repeat that please"))
        #expect(ClickyTutorialModeIntentMatcher.shouldListSteps("what are the steps"))
        #expect(ClickyTutorialModeIntentMatcher.shouldStopTutorialMode("stop tutorial"))
        #expect(ClickyTutorialModeIntentMatcher.isImportIntent("help me with a youtube tutorial"))
        #expect(!ClickyTutorialModeIntentMatcher.isImportIntent("what is the weather"))
    }

    @Test
    @MainActor
    func tutorialImportVoiceIntentPromptsPanelAndSpeech() async {
        let tutorialController = ClickyTutorialController()
        let surfaceController = ClickySurfaceController()
        var spokenText: String?
        let coordinator = ClickyTutorialImportVoiceIntentCoordinator(
            tutorialController: tutorialController,
            surfaceController: surfaceController,
            playSpeech: { text, purpose in
                spokenText = "\(purpose):\(text)"
                return ClickySpeechPlaybackOutcome(
                    finalProviderDisplayName: "System Speech",
                    fallbackMessage: nil,
                    encounteredElevenLabsFailure: false
                )
            }
        )

        let ignored = await coordinator.handleIntentIfNeeded(for: "what is the weather")
        #expect(!ignored)
        #expect(spokenText == nil)

        let handled = await coordinator.handleIntentIfNeeded(for: "help me learn this youtube tutorial")
        #expect(handled)
        #expect(tutorialController.tutorialImportStatusMessage == "Open the companion menu and paste the YouTube URL to begin.")
        #expect(surfaceController.voiceState == .responding)
        #expect(spokenText?.contains("open the companion menu") == true)
    }

    @Test
    func assistantConversationHistoryTrimsToMaximumCount() {
        var history = ClickyAssistantConversationHistory()

        for index in 0..<12 {
            history.append(
                userTranscript: "user \(index)",
                assistantResponse: "assistant \(index)"
            )
        }

        #expect(history.exchanges.count == 10)
        #expect(history.exchanges.first?.userTranscript == "user 2")
        #expect(history.exchanges.last?.assistantResponse == "assistant 11")
    }

    @Test
    func speechProviderCoordinatorClassifiesElevenLabsErrors() {
        let creditError = NSError(domain: "test", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "insufficient credits"
        ])
        let authError = NSError(domain: "test", code: 401, userInfo: [
            NSLocalizedDescriptionKey: "unauthorized"
        ])
        let missingVoiceError = NSError(domain: "test", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "voice not found"
        ])

        #expect(ClickySpeechProviderCoordinator.isLikelyCreditExhaustion(creditError))
        #expect(ClickySpeechProviderCoordinator.isLikelyUnauthorized(authError))
        #expect(ClickySpeechProviderCoordinator.isLikelyVoiceMissing(missingVoiceError))
    }

    @Test
    @MainActor
    func openClawShellLifecycleBlocksRegistrationWhenBackendIsNotOpenClaw() async {
        let gateway = FakeOpenClawShellGateway()
        let routingController = ClickyBackendRoutingController()
        let controller = ClickyOpenClawShellLifecycleController(
            gatewayAgent: gateway,
            routingController: routingController,
            configurationProvider: {
                ClickyOpenClawShellLifecycleConfiguration(
                    selectedBackend: .claude,
                    gatewayURL: "http://127.0.0.1:4891",
                    gatewayAuthToken: "",
                    isGatewayRemote: false,
                    isLocalPluginEnabled: true,
                    effectiveAgentName: "Agent",
                    effectivePresentationName: "Clicky",
                    personaScopeMode: .useOpenClawIdentity,
                    sessionKey: ""
                )
            }
        )

        controller.registerNow()

        #expect(gateway.registerShellCallCount == 0)
        guard case .failed(let message) = routingController.clickyShellRegistrationStatus else {
            Issue.record("Expected shell registration to fail before hitting the gateway.")
            return
        }
        #expect(message.contains("Switch the Agent backend"))
    }

    @Test
    @MainActor
    func openClawShellLifecycleRegistersRemoteGatewayAndPublishesStatus() async throws {
        let gateway = FakeOpenClawShellGateway()
        let routingController = ClickyBackendRoutingController()
        let controller = ClickyOpenClawShellLifecycleController(
            gatewayAgent: gateway,
            routingController: routingController,
            configurationProvider: {
                ClickyOpenClawShellLifecycleConfiguration(
                    selectedBackend: .openClaw,
                    gatewayURL: "https://gateway.example.com",
                    gatewayAuthToken: "token",
                    isGatewayRemote: true,
                    isLocalPluginEnabled: false,
                    effectiveAgentName: "Agent",
                    effectivePresentationName: "Clicky",
                    personaScopeMode: .overrideInClicky,
                    sessionKey: "session-1"
                )
            }
        )

        controller.registerNow()
        try await Task.sleep(for: .milliseconds(50))
        controller.stop()

        #expect(gateway.registerShellCallCount == 1)
        #expect(gateway.lastRegistrationPayload?.personaScope == "clicky-local-override")
        #expect(gateway.lastRegistrationPayload?.sessionKey == "session-1")
        guard case .registered(let summary) = routingController.clickyShellRegistrationStatus else {
            Issue.record("Expected shell registration to publish registered status.")
            return
        }
        #expect(summary == "Registered")
        #expect(routingController.clickyShellServerFreshnessState == "fresh")
        #expect(routingController.clickyShellServerSessionBindingState == "bound")
        #expect(routingController.clickyShellServerTrustState == "trusted-remote")
    }

    @Test
    func menuBarIconStateResolverPrefersListeningDuringActiveVoiceSession() {
        let input = ClickyMenuBarIconStateInput(
            hasCompletedOnboarding: true,
            hasAccessibilityPermission: true,
            hasScreenRecordingPermission: true,
            hasMicrophonePermission: true,
            hasScreenContentPermission: true,
            voiceState: .listening,
            selectedBackend: .openClaw,
            launchAuthState: .signedIn(email: "user@example.com"),
            launchTrialState: .active(remainingCredits: 5),
            openClawConnectionStatus: .connected(summary: "Connected"),
            codexRuntimeStatus: .ready(summary: "Ready")
        )

        #expect(ClickyMenuBarIconStateResolver.resolve(input) == .listening)
    }

    @Test
    func menuBarIconStateResolverShowsAttentionForSignedOutLaunchState() {
        let input = ClickyMenuBarIconStateInput(
            hasCompletedOnboarding: true,
            hasAccessibilityPermission: true,
            hasScreenRecordingPermission: true,
            hasMicrophonePermission: true,
            hasScreenContentPermission: true,
            voiceState: .idle,
            selectedBackend: .claude,
            launchAuthState: .signedOut,
            launchTrialState: .inactive,
            openClawConnectionStatus: .idle,
            codexRuntimeStatus: .idle
        )

        #expect(ClickyMenuBarIconStateResolver.resolve(input) == .signInRequired)
    }

    @Test
    func menuBarIconStateResolverShowsAttentionForSelectedBackendFailure() {
        let input = ClickyMenuBarIconStateInput(
            hasCompletedOnboarding: true,
            hasAccessibilityPermission: true,
            hasScreenRecordingPermission: true,
            hasMicrophonePermission: true,
            hasScreenContentPermission: true,
            voiceState: .idle,
            selectedBackend: .codex,
            launchAuthState: .signedIn(email: "user@example.com"),
            launchTrialState: .active(remainingCredits: 3),
            openClawConnectionStatus: .connected(summary: "Connected"),
            codexRuntimeStatus: .failed(message: "Needs login")
        )

        #expect(ClickyMenuBarIconStateResolver.resolve(input) == .backendIssue)
    }

    @Test
    func menuBarIconStateResolverUsesOnboardingStateBeforeActiveUsage() {
        let input = ClickyMenuBarIconStateInput(
            hasCompletedOnboarding: false,
            hasAccessibilityPermission: true,
            hasScreenRecordingPermission: true,
            hasMicrophonePermission: true,
            hasScreenContentPermission: true,
            voiceState: .idle,
            selectedBackend: .claude,
            launchAuthState: .signedIn(email: "user@example.com"),
            launchTrialState: .active(remainingCredits: 3),
            openClawConnectionStatus: .idle,
            codexRuntimeStatus: .idle
        )

        #expect(ClickyMenuBarIconStateResolver.resolve(input) == .onboarding)
    }

    @Test
    func codexRuntimeCoordinatorFormatsReadinessCopy() {
        #expect(ClickyCodexRuntimeCoordinator.statusLabel(for: .idle) == "Not checked yet")
        #expect(
            ClickyCodexRuntimeCoordinator.summaryCopy(for: .failed(message: "Needs login")) == "Needs login"
        )
        #expect(
            ClickyCodexRuntimeCoordinator.readinessChipLabels(
                status: .ready(summary: "Ready"),
                authModeLabel: "ChatGPT",
                configuredModelName: "gpt-5"
            ) == ["Ready", "ChatGPT", "gpt-5"]
        )
        #expect(
            ClickyCodexRuntimeCoordinator.readinessChipLabels(
                status: .idle,
                authModeLabel: " ",
                configuredModelName: nil
            ) == ["Not checked yet", "Local runtime"]
        )
    }

    @Test
    func permissionCoordinatorRequiresEveryPermission() {
        #expect(
            ClickyPermissionCoordinator.allPermissionsGranted(
                hasAccessibilityPermission: true,
                hasScreenRecordingPermission: true,
                hasMicrophonePermission: true,
                hasScreenContentPermission: true
            )
        )
        #expect(
            !ClickyPermissionCoordinator.allPermissionsGranted(
                hasAccessibilityPermission: true,
                hasScreenRecordingPermission: true,
                hasMicrophonePermission: false,
                hasScreenContentPermission: true
            )
        )
    }

    @Test
    func openClawStudioCoordinatorFormatsGatewayAndPluginState() {
        #expect(!ClickyOpenClawStudioCoordinator.isGatewayRemote("ws://localhost:4466"))
        #expect(!ClickyOpenClawStudioCoordinator.isGatewayRemote("ws://127.0.0.1:4466"))
        #expect(ClickyOpenClawStudioCoordinator.isGatewayRemote("wss://gateway.example.com"))
        #expect(ClickyOpenClawStudioCoordinator.gatewayAuthSummary(explicitGatewayAuthToken: " token ") == "Using token from Studio settings")

        let enabledConfiguration: [String: Any] = [
            "plugins": [
                "entries": [
                    "clicky-shell": ["enabled": true],
                ],
            ],
        ]
        let disabledConfiguration: [String: Any] = [
            "plugins": [
                "entries": [
                    "clicky-shell": ["enabled": false],
                ],
            ],
        ]

        #expect(ClickyOpenClawStudioCoordinator.pluginStatus(openClawConfiguration: enabledConfiguration) == .enabled)
        #expect(ClickyOpenClawStudioCoordinator.pluginStatus(openClawConfiguration: disabledConfiguration) == .disabled)
        #expect(ClickyOpenClawStudioCoordinator.pluginStatus(openClawConfiguration: nil) == .notConfigured)
        #expect(ClickyOpenClawStudioCoordinator.pluginStatusLabel(for: .enabled) == "Enabled in local OpenClaw config")
    }

    @Test
    func openClawStudioCoordinatorFormatsIdentityLabels() {
        #expect(
            ClickyOpenClawStudioCoordinator.effectiveAgentName(
                manualName: "  Ada  ",
                inferredName: "Claw"
            ) == "Ada"
        )
        #expect(
            ClickyOpenClawStudioCoordinator.effectiveAgentName(
                manualName: " ",
                inferredName: " Claw "
            ) == "Claw"
        )
        #expect(
            ClickyOpenClawStudioCoordinator.inferredIdentityDisplayName(
                emoji: "*",
                name: "Claw"
            ) == "* Claw"
        )
        #expect(ClickyOpenClawStudioCoordinator.inferredIdentityEmojiLabel(" ") == "No emoji provided by OpenClaw")
        #expect(ClickyOpenClawStudioCoordinator.inferredIdentityAvatarLabel("avatar-url") == "Avatar available from OpenClaw")
    }

    @Test
    func personaPromptCoordinatorResolvesPresentationAndModelLabels() {
        #expect(
            ClickyPersonaPromptCoordinator.effectivePresentationName(
                selectedBackend: .claude,
                personaScopeMode: .useOpenClawIdentity,
                personaOverrideName: "  Pilot  ",
                effectiveOpenClawAgentName: "Claw"
            ) == "Pilot"
        )
        #expect(
            ClickyPersonaPromptCoordinator.effectivePresentationName(
                selectedBackend: .openClaw,
                personaScopeMode: .useOpenClawIdentity,
                personaOverrideName: "Pilot",
                effectiveOpenClawAgentName: "Claw"
            ) == "Claw"
        )
        #expect(
            ClickyPersonaPromptCoordinator.effectivePresentationName(
                selectedBackend: .openClaw,
                personaScopeMode: .overrideInClicky,
                personaOverrideName: " ",
                effectiveOpenClawAgentName: "Claw"
            ) == "Clicky"
        )
        #expect(
            ClickyPersonaPromptCoordinator.selectedAssistantModelIdentityLabel(
                selectedBackend: .codex,
                selectedModel: "",
                codexConfiguredModelName: "  gpt-5  ",
                openClawAgentIdentifier: "",
                inferredOpenClawAgentIdentifier: nil,
                effectiveOpenClawAgentName: "Claw"
            ) == "gpt-5"
        )
        #expect(
            ClickyPersonaPromptCoordinator.selectedAssistantModelIdentityLabel(
                selectedBackend: .openClaw,
                selectedModel: "",
                codexConfiguredModelName: nil,
                openClawAgentIdentifier: " ",
                inferredOpenClawAgentIdentifier: " agent-1 ",
                effectiveOpenClawAgentName: "Claw"
            ) == "agent-1"
        )
    }

    @Test
    func personaPromptCoordinatorAppendsCustomToneInstructions() {
        let definition = ClickyPersonaPreset.guide.definition
        let baseInstructions = ClickyPersonaPromptCoordinator.effectiveSpeechInstructions(
            activePersonaDefinition: definition,
            customToneInstructions: " "
        )
        let customInstructions = ClickyPersonaPromptCoordinator.effectiveSpeechInstructions(
            activePersonaDefinition: definition,
            customToneInstructions: "more concise"
        )

        #expect(baseInstructions.contains(definition.speechGuidance))
        #expect(!baseInstructions.contains("also follow these clicky-only tone notes"))
        #expect(customInstructions.contains("also follow these clicky-only tone notes: more concise"))
    }

    @Test
    func launchRuntimeCoordinatorQuietRefreshRulesMatchBillingState() {
        let inactiveSession = ClickyAuthSessionSnapshot(
            sessionToken: "token",
            userID: "user",
            email: "user@example.com",
            name: "",
            image: "",
            entitlement: ClickyLaunchEntitlementSnapshot(
                productKey: "clicky",
                status: "inactive",
                hasAccess: false,
                gracePeriodEndsAt: nil
            ),
            trial: ClickyLaunchTrialSnapshot(
                status: "inactive",
                initialCredits: 0,
                remainingCredits: 0,
                setupCompletedAt: nil,
                trialActivatedAt: nil,
                lastCreditConsumedAt: nil,
                welcomePromptDeliveredAt: nil,
                paywallActivatedAt: nil
            )
        )
        let activeSession = ClickyAuthSessionSnapshot(
            sessionToken: "token",
            userID: "user",
            email: "user@example.com",
            name: "",
            image: "",
            entitlement: ClickyLaunchEntitlementSnapshot(
                productKey: "clicky",
                status: "active",
                hasAccess: true,
                gracePeriodEndsAt: nil
            ),
            trial: ClickyLaunchTrialSnapshot(
                status: "inactive",
                initialCredits: 0,
                remainingCredits: 0,
                setupCompletedAt: nil,
                trialActivatedAt: nil,
                lastCreditConsumedAt: nil,
                welcomePromptDeliveredAt: nil,
                paywallActivatedAt: nil
            )
        )

        #expect(
            ClickyLaunchRuntimeCoordinator.shouldAttemptQuietEntitlementRefresh(
                storedSession: activeSession,
                trialState: .inactive,
                billingState: .idle
            )
        )
        #expect(
            ClickyLaunchRuntimeCoordinator.shouldAttemptQuietEntitlementRefresh(
                storedSession: inactiveSession,
                trialState: .paywalled,
                billingState: .idle
            )
        )
        #expect(
            ClickyLaunchRuntimeCoordinator.shouldAttemptQuietEntitlementRefresh(
                storedSession: inactiveSession,
                trialState: .inactive,
                billingState: .waitingForCompletion
            )
        )
        #expect(
            !ClickyLaunchRuntimeCoordinator.shouldAttemptQuietEntitlementRefresh(
                storedSession: inactiveSession,
                trialState: .inactive,
                billingState: .idle
            )
        )
        #expect(
            ClickyLaunchRuntimeCoordinator.quietEntitlementSyncMode(
                storedSession: activeSession,
                billingState: .idle
            ) == .refresh
        )
        #expect(
            ClickyLaunchRuntimeCoordinator.quietEntitlementSyncMode(
                storedSession: inactiveSession,
                billingState: .idle
            ) == .restore
        )
    }

    @Test
    func runtimeEnvironmentDetectsAppHostedUnitTests() {
        #expect(ClickyRuntimeEnvironment.isRunningAppHostedUnitTests(
            environment: ["XCTestConfigurationFilePath": "/tmp/Clicky.xctestconfiguration"],
            arguments: []
        ))

        #expect(ClickyRuntimeEnvironment.isRunningAppHostedUnitTests(
            environment: [:],
            arguments: ["/Applications/Xcode.app/Contents/Developer/usr/bin/xctest"]
        ))

        #expect(!ClickyRuntimeEnvironment.isRunningAppHostedUnitTests(
            environment: [:],
            arguments: ["/Applications/Clicky.app/Contents/MacOS/Clicky"]
        ))
    }
}

private final class FakeOpenClawShellGateway: ClickyOpenClawShellGateway {
    var registerShellCallCount = 0
    var lastRegistrationPayload: OpenClawShellRegistrationPayload?

    func registerShell(
        gatewayURLString: String,
        explicitGatewayAuthToken: String?,
        payload: OpenClawShellRegistrationPayload
    ) async throws -> String {
        registerShellCallCount += 1
        lastRegistrationPayload = payload
        return "Registered"
    }

    func sendShellHeartbeat(
        gatewayURLString: String,
        explicitGatewayAuthToken: String?,
        shellIdentifier: String
    ) async throws {}

    func fetchShellStatus(
        gatewayURLString: String,
        explicitGatewayAuthToken: String?,
        shellIdentifier: String
    ) async throws -> OpenClawShellStatusSnapshot {
        OpenClawShellStatusSnapshot(
            freshnessState: "fresh",
            isRegistered: true,
            agentIdentityName: "Agent",
            clickyPresentationName: "Clicky",
            personaScope: "clicky-local-override",
            sessionKey: "session-1",
            summary: "Registered",
            sessionBindingState: "bound",
            trustState: "trusted-remote"
        )
    }

    func bindShellSession(
        gatewayURLString: String,
        explicitGatewayAuthToken: String?,
        shellIdentifier: String,
        sessionKey: String?
    ) async throws -> OpenClawShellStatusSnapshot {
        try await fetchShellStatus(
            gatewayURLString: gatewayURLString,
            explicitGatewayAuthToken: explicitGatewayAuthToken,
            shellIdentifier: shellIdentifier
        )
    }
}
