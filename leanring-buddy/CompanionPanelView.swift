//
//  CompanionPanelView.swift
//  leanring-buddy
//
//  The SwiftUI content hosted inside the menu bar panel. The outer shell stays
//  native and glass-first, while the interior swaps between onboarding, ready,
//  locked, and repair states from the Paper designs.
//

import AVFoundation
import SwiftUI

struct CompanionPanelView: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var surfaceController: ClickySurfaceController
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    @ObservedObject private var tutorialController: ClickyTutorialController

    @State private var onboardingStage: CompanionPanelOnboardingStage = .welcome
    @State private var showsSignInWhyCopy = false
    @State private var recentlyGrantedPermissions: Set<CompanionPermissionKind> = []
    @State private var showsLockedStudioChip = false
    @State private var isShowingTutorialFlow = false
    @State private var showsTutorialEntryExplainer = false
    @Namespace private var panelMotionNamespace

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _surfaceController = ObservedObject(wrappedValue: companionManager.surfaceController)
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
        _tutorialController = ObservedObject(wrappedValue: companionManager.tutorialController)
    }

    private var theme: ClickyTheme {
        preferences.clickyThemePreset.theme
    }

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    private var allPermissionsGranted: Bool {
        surfaceController.hasAccessibilityPermission
            && surfaceController.hasScreenRecordingPermission
            && surfaceController.hasMicrophonePermission
            && surfaceController.hasScreenContentPermission
    }

    private var hasCompletedOnboarding: Bool {
        preferences.hasCompletedOnboarding
    }

    private var clickyLaunchAuthState: ClickyLaunchAuthState {
        launchAccessController.clickyLaunchAuthState
    }

    private var isClickyLaunchSignedIn: Bool {
        ClickyLaunchPresentation.isSignedIn(clickyLaunchAuthState)
    }

    private var activeClickyPersonaLabel: String {
        preferences.clickyPersonaPreset.definition.displayName
    }

    private var effectiveClickyVoicePreset: ClickyVoicePreset {
        preferences.clickyVoicePreset
    }

    private var effectiveClickyCursorStyle: ClickyCursorStyle {
        preferences.clickyCursorStyle
    }

    private var hasUnlimitedClickyLaunchAccess: Bool {
        ClickyLaunchPresentation.hasUnlimitedAccess(launchAccessController.clickyLaunchTrialState)
    }

    private var clickyLaunchTrialStatusLabel: String {
        ClickyLaunchPresentation.trialStatusLabel(for: launchAccessController.clickyLaunchTrialState)
    }

    private var panelScreen: CompanionPanelScreen {
        if companionManager.isClickyLaunchPaywallActive {
            return .locked
        }

        if hasCompletedOnboarding {
            if companionManager.isClickyLaunchAuthPending || companionManager.requiresLaunchSignInForCompanionUse {
                return .signIn
            }

            if let tutorialPanelScreen {
                return tutorialPanelScreen
            }
            return allPermissionsGranted ? .active : .repair
        }

        switch onboardingStage {
        case .welcome:
            return .welcome
        case .signIn:
            return .signIn
        case .permissions:
            return .permissions
        case .ready:
            return .ready
        }
    }

    private var onboardingProgressLabel: String {
        switch panelScreen {
        case .welcome:
            return "1 of 4"
        case .signIn:
            return "2 of 4"
        case .permissions:
            return "3 of 4"
        case .ready:
            return "4 of 4"
        case .active, .locked, .repair, .tutorialEntry, .tutorialImportEntry, .tutorialImportMissingSetup, .tutorialExtracting, .tutorialCompiling, .tutorialReady, .tutorialPlayback, .tutorialFailed:
            return ""
        }
    }

    private var statusPrimaryText: String {
        switch panelScreen {
        case .welcome:
            return "Welcome"
        case .signIn:
            return "Sign In"
        case .permissions:
            return "Permissions"
        case .ready:
            return "Ready"
        case .active:
            return statusText
        case .locked:
            return "Locked"
        case .repair:
            return "Repair"
        case .tutorialEntry, .tutorialImportEntry, .tutorialImportMissingSetup, .tutorialExtracting, .tutorialCompiling, .tutorialReady, .tutorialPlayback, .tutorialFailed:
            return "Learn"
        }
    }

    private var statusSecondaryText: String {
        switch panelScreen {
        case .welcome, .signIn, .permissions, .ready:
            return onboardingProgressLabel.uppercased()
        case .active:
            return preferences.selectedAgentBackend.displayName.uppercased()
        case .locked:
            return "CREDITS EXHAUSTED"
        case .repair:
            return "PERMISSIONS REVOKED"
        case .tutorialEntry:
            return preferences.selectedAgentBackend.displayName.uppercased()
        case .tutorialImportEntry:
            return "READY"
        case .tutorialImportMissingSetup:
            return "SETUP NEEDED"
        case .tutorialExtracting:
            return "EXTRACTING"
        case .tutorialCompiling:
            return "COMPILING"
        case .tutorialReady:
            return "READY"
        case .tutorialPlayback:
            if let session = tutorialController.tutorialSessionState {
                return "STEP \(String(format: "%02d", session.currentStepIndex + 1))"
            }
            return "PLAYING"
        case .tutorialFailed:
            return "FAILED"
        }
    }

    private var showsStudioButton: Bool {
        switch panelScreen {
        case .welcome, .signIn, .permissions:
            return false
        case .ready, .active, .locked, .repair, .tutorialEntry, .tutorialImportMissingSetup, .tutorialReady, .tutorialFailed:
            return true
        case .tutorialImportEntry, .tutorialExtracting, .tutorialCompiling, .tutorialPlayback:
            return false
        }
    }

    private var showsHeaderStatusRow: Bool {
        switch panelScreen {
        case .active:
            return false
        case .welcome, .signIn, .permissions, .ready, .locked, .repair, .tutorialEntry, .tutorialImportEntry, .tutorialImportMissingSetup, .tutorialExtracting, .tutorialCompiling, .tutorialReady, .tutorialPlayback, .tutorialFailed:
            return true
        }
    }

    private var tutorialPanelScreen: CompanionPanelScreen? {
        let hasTutorialPlayback = tutorialController.tutorialPlaybackState?.isVisible == true

        guard isShowingTutorialFlow || hasTutorialPlayback else {
            return nil
        }

        if hasTutorialPlayback {
            return .tutorialPlayback
        }

        if tutorialController.isTutorialImportRunning {
            switch tutorialController.currentTutorialImportDraft?.status {
            case .compiling:
                return .tutorialCompiling
            default:
                return .tutorialExtracting
            }
        }

        if let draft = tutorialController.currentTutorialImportDraft {
            switch draft.status {
            case .failed:
                return .tutorialFailed
            case .ready:
                return .tutorialReady
            case .compiling:
                return .tutorialCompiling
            case .extracting, .extracted:
                return .tutorialExtracting
            case .pending:
                break
            }
        }

        if !CompanionRuntimeConfiguration.isTutorialExtractorConfigured {
            return .tutorialImportMissingSetup
        }

        return .tutorialImportEntry
    }

    private var isInTutorialPanelFlow: Bool {
        switch panelScreen {
        case .tutorialEntry, .tutorialImportEntry, .tutorialImportMissingSetup, .tutorialExtracting, .tutorialCompiling, .tutorialReady, .tutorialPlayback, .tutorialFailed:
            return true
        case .welcome, .signIn, .permissions, .ready, .active, .locked, .repair:
            return false
        }
    }

    var body: some View {
        ClickyGlassCluster {
            panelShell
                .padding(12)
        }
        .clickyTheme(theme)
        .frame(width: 360)
        .onAppear {
            syncOnboardingStage()
            requestPanelRelayout(animated: false)
        }
        .onChange(of: launchAccessController.clickyLaunchAuthState) { _, _ in
            syncOnboardingStage()
        }
        .onChange(of: allPermissionsGranted) { _, _ in
            syncOnboardingStage()
        }
        .onChange(of: panelScreenKey) { _, _ in
            requestPanelRelayout(animated: false)
        }
        .onChange(of: permissionRows.count) { _, _ in
            requestPanelRelayout(animated: false)
        }
        .onChange(of: showsSignInWhyCopy) { _, _ in
            requestPanelRelayout(animated: false)
        }
        .onChange(of: surfaceController.hasAccessibilityPermission) { _, isGranted in
            handlePermissionStateChange(.accessibility, isGranted: isGranted)
        }
        .onChange(of: surfaceController.hasMicrophonePermission) { _, isGranted in
            handlePermissionStateChange(.microphone, isGranted: isGranted)
        }
        .onChange(of: surfaceController.hasScreenRecordingPermission) { _, isGranted in
            handlePermissionStateChange(.screenRecording, isGranted: isGranted)
        }
        .onChange(of: surfaceController.hasScreenContentPermission) { _, isGranted in
            handlePermissionStateChange(.screenContent, isGranted: isGranted)
        }
        .onChange(of: panelScreenKey) { _, newValue in
            if newValue == "locked" {
                showsLockedStudioChip = false
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.12))
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showsLockedStudioChip = true
                    }
                }
            } else {
                showsLockedStudioChip = false
            }
        }
    }

    private var panelShell: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHeader
            panelHairline
            panelBody
            panelHairline
            footerSection
        }
        .modifier(ClickyPanelShellStyle())
    }

    private var panelHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("clicky")
                    .font(ClickyTypography.brand(size: 30))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.primary, theme.ring.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if showsHeaderStatusRow {
                    HStack(spacing: 8) {
                        headerStatusPill

                        if !statusSecondaryText.isEmpty {
                            Text(statusSecondaryText)
                                .font(ClickyTypography.mono(size: 10, weight: .medium))
                                .foregroundColor(theme.textMuted)
                        }
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if showsStudioButton {
                    Button(action: openStudio) {
                        Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.foreground.opacity(0.88))
                        .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .modifier(ClickyTinyGlassCircleStyle())
                }

                Button(action: handleTrailingHeaderAction) {
                    Image(systemName: isInTutorialPanelFlow ? "chevron.left" : "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.foreground.opacity(0.88))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .modifier(ClickyTinyGlassCircleStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerStatusPill: some View {
        Text(statusPrimaryText.uppercased())
            .font(ClickyTypography.mono(size: 10, weight: .semibold))
            .foregroundColor(headerPillForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(headerPillBackground)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(headerPillBorder, lineWidth: 0.8)
            )
    }

    private var panelBody: some View {
        return VStack(alignment: .leading, spacing: 12) {
            Group {
                primaryContentCard
                    .panelGlassMotionID("primary-card-\(panelScreenKey)", namespace: panelMotionNamespace)
                    .transition(panelCardTransition)

                secondaryContentCard
                    .panelGlassMotionID("secondary-card-\(panelScreenKey)", namespace: panelMotionNamespace)
                    .transition(panelCardTransition)
            }
        }
        .animation(panelCardAnimation, value: panelScreenKey)
        .animation(panelCardAnimation, value: permissionRows.count)
        .animation(panelCardAnimation, value: showsSignInWhyCopy)
    }

    @ViewBuilder
    private var primaryContentCard: some View {
        switch panelScreen {
        case .welcome:
            primaryCopyCard(
                title: "A companion that sees what you see and helps while you work.",
                body: "Hold Control+Option, ask naturally, and let Clicky understand your screen, answer in voice, and guide your attention when it matters."
            )
        case .signIn:
            primaryCopyCard(
                title: "Sign in so Clicky can stay with you.",
                body: "You get a free taste first. Upgrade only after you've felt the value. Sign-in keeps your credits, restore access, and purchase state attached to you."
            )
        case .permissions:
            primaryCopyCard(
                title: "Give Clicky the access it needs to help in context.",
                body: "These permissions let Clicky listen, understand what's on screen, guide your attention, and act when you approve it. Only show what still needs attention."
            )
        case .ready:
            primaryCopyCard(
                title: "Clicky is ready to join you in the work.",
                body: "From here on, the product should teach itself through use. Hold Control+Option whenever you want help."
            )
        case .active:
            activeHeroCard
        case .locked:
            primaryCopyCard(
                title: "You've felt what Clicky can do.",
                body: "Unlock it to keep this companion with you while you work.",
                tone: .subtle
            )
        case .repair:
            primaryCopyCard(
                title: "Clicky lost some of the access it uses to help.",
                body: "This is a quick repair moment. Restore what's missing and Clicky can keep guiding you in context."
            )
        case .tutorialEntry:
            primaryCopyCard(
                title: "Hold Control+Option whenever you want Clicky with you.",
                body: "The everyday state stays quiet, but Clicky can also turn a YouTube tutorial into something you can follow step by step."
            )
        case .tutorialImportEntry, .tutorialImportMissingSetup:
            primaryCopyCard(
                title: "Learn from YouTube",
                body: "Paste a tutorial URL and Clicky will turn it into a guided flow beside your cursor."
            )
        case .tutorialExtracting:
            primaryCopyCard(
                title: "Pulling out the useful parts of the tutorial.",
                body: "Clicky is extracting transcript, timestamps, and visual evidence so it can guide you later instead of just dumping a video on you."
            )
        case .tutorialCompiling:
            primaryCopyCard(
                title: "Turning the tutorial into a guided lesson.",
                body: "The selected backend is compiling the evidence bundle into clear steps that Clicky can teach through, not just quote back."
            )
        case .tutorialReady:
            primaryCopyCard(
                title: "Your guided lesson is ready.",
                body: "Clicky has turned the tutorial into a step-by-step lesson you can follow beside your cursor."
            )
        case .tutorialPlayback:
            primaryCopyCard(
                title: tutorialPlaybackTitle,
                body: "Clicky can explain this step, answer questions, or point you at the right part of the UI."
            )
        case .tutorialFailed:
            primaryCopyCard(
                title: "Clicky couldn't turn this tutorial into a lesson yet.",
                body: "The import draft is still safe locally, so you can retry, switch sources, or inspect what failed in Studio.",
                tone: .subtle
            )
        }
    }

    @ViewBuilder
    private var secondaryContentCard: some View {
        switch panelScreen {
        case .welcome:
            onboardingWelcomeCard
        case .signIn:
            onboardingSignInCard
        case .permissions:
            permissionsCard(
                primaryTitle: "Continue",
                secondaryTitle: "Later",
                secondaryAction: dismissPanel
            )
        case .ready:
            onboardingReadyCard
        case .active:
            activeStateCard
        case .locked:
            lockedStateCard
        case .repair:
            permissionsCard(
                primaryTitle: nil,
                secondaryTitle: nil,
                secondaryAction: nil
            )
        case .tutorialEntry:
            tutorialEntryPointCard
        case .tutorialImportEntry:
            tutorialImportEntryCard
        case .tutorialImportMissingSetup:
            tutorialImportMissingSetupCard
        case .tutorialExtracting:
            tutorialExtractingCard
        case .tutorialCompiling:
            tutorialCompilingCard
        case .tutorialReady:
            tutorialReadyCard
        case .tutorialPlayback:
            tutorialPlaybackCard
        case .tutorialFailed:
            tutorialFailedCard
        }
    }

    private func primaryCopyCard(title: String, body: String, tone: ClickyPanelContentTone = .hero) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(ClickyTypography.section(size: 22))
                .foregroundColor(contentTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(body)
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(contentTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .modifier(ClickyPanelContentCardStyle(tone: tone, padding: 18))
    }

    private var activeHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Hold")
                    .font(ClickyTypography.section(size: 21))
                    .foregroundColor(contentTheme.textPrimary)

                shortcutKeycap("⌃")
                shortcutKeycap("⌥")

                Text("to talk.")
                    .font(ClickyTypography.section(size: 21))
                    .foregroundColor(contentTheme.textPrimary)
            }

            Text("Ask naturally and Clicky will guide your attention, answer in voice, and keep your place.")
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(contentTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .modifier(ClickyPanelContentCardStyle(tone: .hero, padding: 18))
    }

    private func shortcutKeycap(_ label: String) -> some View {
        Text(label)
            .font(ClickyTypography.mono(size: 13, weight: .semibold))
            .foregroundColor(contentTheme.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(contentTheme.card.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(contentTheme.border.opacity(0.85), lineWidth: 0.9)
            )
    }

    private var onboardingWelcomeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                panelSectionEyebrow("What Clicky Does")

                onboardingBullet("Understand the software in front of you.")
                onboardingBullet("Teach you the next step in plain language.")
                onboardingBullet("Point exactly where you should look or click.")
            }

            HStack(spacing: 10) {
                Button(action: continueFromWelcome) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle(attentionMode: .singlePulse))
                .pointerCursor()

                Button(action: openStudio) {
                    Text("Open Studio")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var onboardingSignInCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(signInSummaryCopy)
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(contentTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if showsSignInWhyCopy {
                Text("Clicky keeps credits, restore, and purchase state on your account so it stays with you across reinstalls and future upgrades.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                Button(action: handleSignInPrimaryAction) {
                    Text(signInPrimaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor(isEnabled: !companionManager.isClickyLaunchAuthPending)
                .disabled(companionManager.isClickyLaunchAuthPending)

                Button(action: {
                    withAnimation(panelSpringAnimation) {
                        showsSignInWhyCopy.toggle()
                    }
                }) {
                    Text(showsSignInWhyCopy ? "Hide" : "Why?")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var onboardingReadyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                panelSectionEyebrow("You Can Now")

                onboardingBullet("Ask what this software is doing.")
                onboardingBullet("Learn the next step while staying in context.")
                onboardingBullet("Follow the pointer when Clicky wants to show you where to look.")
            }

            HStack(spacing: 10) {
                Button(action: {
                    companionManager.triggerOnboarding()
                }) {
                    Text("Start Using Clicky")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()

                Button(action: openStudio) {
                    Text("Open Studio")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var activeStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            tutorialEntryPointCard

            currentFeelCard
        }
    }

    private var currentFeelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    panelSectionEyebrow("Current Feel")

                    Text(activeClickyPersonaLabel)
                        .font(ClickyTypography.section(size: 20))
                        .foregroundColor(contentTheme.textPrimary)

                    Text("\(effectiveClickyVoicePreset.displayName) voice  ·  \(effectiveClickyCursorStyle.displayName) cursor")
                        .font(ClickyTypography.mono(size: 10, weight: .medium))
                        .foregroundColor(contentTheme.textMuted)
                }

                Spacer()

                CompanionCreditsChip(
                    label: launchCreditsLabel.uppercased(),
                    tone: hasUnlimitedClickyLaunchAccess ? .success : .neutral
                )
            }

            panelHairline

            VStack(alignment: .leading, spacing: 8) {
                panelSectionEyebrow("Companion")
                companionBackendButtons
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var tutorialEntryPointCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    panelSectionEyebrow("Learn")
                    Text("Turn a tutorial into a guided flow")
                        .font(ClickyTypography.section(size: 20))
                        .foregroundColor(contentTheme.textPrimary)
                    Text("Paste a YouTube URL and Clicky will teach it beside your cursor.")
                        .font(ClickyTypography.body(size: 12))
                        .foregroundColor(contentTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                panelInlineStatus(label: "New", tone: .info)
            }

            if showsTutorialEntryExplainer {
                Text("Clicky extracts the useful parts, compiles them into a lesson, then guides you step by step with inline video and voice help.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                Button(action: {
                    withAnimation(panelCardAnimation) {
                        isShowingTutorialFlow = true
                        showsTutorialEntryExplainer = false
                    }
                }) {
                    Text("Start Learning")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()

                Button(action: {
                    withAnimation(panelCardAnimation) {
                        showsTutorialEntryExplainer.toggle()
                    }
                }) {
                    Text("How it works")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
                .frame(width: 148)
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var tutorialImportEntryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("YouTube URL")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(contentTheme.textPrimary)

                CompanionPanelTutorialURLField(
                    tutorialController: tutorialController,
                    placeholder: "https://youtube.com/watch?v=...",
                    theme: theme,
                    contentTheme: contentTheme,
                    onSubmit: companionManager.startTutorialImportFromPanel
                )
            }

            Text("Clicky will extract the useful parts, compile a lesson, and guide you through it on your own screen.")
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(contentTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                companionManager.startTutorialImportFromPanel()
            }) {
                Text("Start Learning")
                    .frame(maxWidth: .infinity)
            }
            .modifier(ClickyProminentActionStyle())
            .pointerCursor()
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var tutorialImportMissingSetupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("YouTube URL")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(contentTheme.textPrimary)

                CompanionPanelTutorialURLField(
                    tutorialController: tutorialController,
                    placeholder: "https://youtube.com/watch?v=dQw4w9WgXcQ",
                    theme: theme,
                    contentTheme: contentTheme,
                    onSubmit: companionManager.startTutorialImportFromPanel
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("The tutorial extraction service API key is missing.")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(contentTheme.textPrimary)
                Text("Add it in Studio first, then come back here to start learning from tutorials.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(2)

            Button(action: openStudio) {
                Text("Open Studio")
                    .frame(maxWidth: .infinity)
            }
            .modifier(ClickyProminentActionStyle())
            .pointerCursor()
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var tutorialExtractingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                panelSectionEyebrow("Current Step")
                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.success.opacity(0.75))
                        .frame(width: 8, height: 8)
                    Text("Extracting transcript")
                        .font(ClickyTypography.body(size: 13, weight: .medium))
                        .foregroundColor(contentTheme.textPrimary)
                }

                ProgressView(value: tutorialExtractionProgress)
                    .tint(theme.success)

                Text("Next: representative frames and structure.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
            }

            HStack {
                Button(action: {
                    isShowingTutorialFlow = false
                }) {
                    Text("Cancel")
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()

                Spacer()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var tutorialCompilingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                panelSectionEyebrow("Lesson Draft")
                Text("Building step titles, instructions, and verification hints…")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(contentTheme.textPrimary)
                HStack(spacing: 6) {
                    Circle().fill(contentTheme.textMuted.opacity(0.6)).frame(width: 6, height: 6)
                    Circle().fill(contentTheme.textMuted.opacity(0.85)).frame(width: 6, height: 6)
                    Circle().fill(contentTheme.textMuted.opacity(0.45)).frame(width: 6, height: 6)
                }
            }

            HStack {
                Button(action: {
                    isShowingTutorialFlow = false
                }) {
                    Text("Cancel")
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()

                Spacer()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var tutorialReadyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                panelSectionEyebrow("Lesson Snapshot")
                Text(tutorialLessonTitle)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(contentTheme.textPrimary)
                Text(tutorialLessonSummaryLine)
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: {
                    companionManager.startTutorialLessonFromReadyState()
                }) {
                    Text("Start Lesson")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()

                Button(action: openStudio) {
                    Text("Open Studio")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var tutorialPlaybackCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                panelSectionEyebrow("Video Context")
                Text("Source clip available inline beside the cursor. Space to pause, arrows to seek, Escape to dismiss.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: {
                    companionManager.repeatTutorialLessonStepFromPanel()
                }) {
                    Text("Repeat")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()

                Button(action: {
                    companionManager.rewindTutorialLessonFromPanel()
                }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()

                Button(action: {
                    companionManager.advanceTutorialLessonFromPanel()
                }) {
                    Text("Next Step")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var tutorialFailedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                panelSectionEyebrow("Failure Reason")
                Text(tutorialFailureReason)
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(contentTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Try again or inspect diagnostics in Studio.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
            }

            HStack(spacing: 10) {
                Button(action: {
                    companionManager.retryTutorialImportFromPanel()
                }) {
                    Text("Try Again")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()

                Button(action: openStudio) {
                    Text("Open Studio")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var lockedStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        panelSectionEyebrow("Unlock Clicky")
                        Spacer()
                        Text("$49")
                            .font(ClickyTypography.section(size: 20))
                            .foregroundColor(contentTheme.textPrimary)
                    }

                    Text("One payment to continue learning, asking, and getting guided help in context.")
                        .font(ClickyTypography.body(size: 13))
                        .foregroundColor(contentTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: {
                    companionManager.startClickyLaunchCheckout()
                }) {
                    Text("Pay Now")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle(attentionMode: .loopingPulse))
                .pointerCursor()

                Button(action: {
                    companionManager.signOutClickyLaunchSession()
                }) {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    panelSectionEyebrow("Studio")
                    Spacer()
                    if showsLockedStudioChip {
                        panelInlineStatus(label: "Locked", tone: .warning)
                            .transition(.opacity)
                    }
                }

                Text("Studio stays available for account repair and restore paths while companion use stays locked until upgrade.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private func permissionsCard(
        primaryTitle: String?,
        secondaryTitle: String?,
        secondaryAction: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(permissionRows) { row in
                    panelPermissionRow(row)
                        .transition(.opacity)
                    if row.id != permissionRows.last?.id {
                        panelHairline
                    }
                }
            }

            if let primaryTitle {
                HStack(spacing: 10) {
                    Button(action: continueFromPermissions) {
                        Text(primaryTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .modifier(ClickyProminentActionStyle())
                    .pointerCursor()

                    if let secondaryTitle, let secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .modifier(ClickySecondaryGlassButtonStyle())
                        .pointerCursor()
                    }
                }
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private func panelPermissionRow(_ row: CompanionPanelPermissionRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(row.state.dotColor(theme))
                .frame(width: 10, height: 10)
                .scaleEffect(row.state == .granted ? 1.12 : 1.0)
                .padding(.top, 6)
                .animation(.easeInOut(duration: 0.16), value: row.state)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(contentTheme.textPrimary)
 
                Text(row.detail)
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if row.state == .granted {
                    panelInlineStatus(label: "Granted", tone: .success)
                        .transition(.opacity)
                } else {
                    Button(action: row.primaryAction) {
                        Text(row.primaryTitle)
                    }
                    .modifier(ClickyProminentActionStyle())
                    .pointerCursor()
                    if let secondaryTitle = row.secondaryTitle,
                       let secondaryAction = row.secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                        }
                        .modifier(ClickySecondaryGlassButtonStyle())
                        .pointerCursor()
                    }
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(row.state.backgroundColor(theme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(row.state.borderColor(theme), lineWidth: 0.8)
        )
        .animation(.easeInOut(duration: 0.22), value: row.state)
    }

    private func onboardingBullet(_ text: String) -> some View {
        Text(text)
            .font(ClickyTypography.body(size: 13))
            .foregroundColor(contentTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var permissionRows: [CompanionPanelPermissionRow] {
        var rows: [CompanionPanelPermissionRow] = []

        if !surfaceController.hasAccessibilityPermission {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .accessibility,
                    title: "Accessibility",
                    detail: hasCompletedOnboarding
                        ? "So Clicky can continue helping you act inside software."
                        : "So Clicky can guide and act inside software when you ask.",
                    primaryTitle: "Grant",
                    primaryAction: requestAccessibilityPermission,
                    secondaryTitle: "Find App",
                    secondaryAction: {
                        WindowPositionManager.revealAppInFinder()
                        WindowPositionManager.openAccessibilitySettings()
                    }
                ).withState(rowState(for: .accessibility, isGranted: false))
            )
        } else if recentlyGrantedPermissions.contains(.accessibility) {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .accessibility,
                    title: "Accessibility",
                    detail: "Resolved and quiet again.",
                    primaryTitle: "Grant",
                    primaryAction: {}
                ).withState(.granted)
            )
        }

        if !surfaceController.hasMicrophonePermission {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .microphone,
                    title: "Microphone",
                    detail: "So Clicky can listen when you use push-to-talk.",
                    primaryTitle: "Grant",
                    primaryAction: requestMicrophonePermission
                ).withState(rowState(for: .microphone, isGranted: false))
            )
        } else if recentlyGrantedPermissions.contains(.microphone) {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .microphone,
                    title: "Microphone",
                    detail: "Resolved and quiet again.",
                    primaryTitle: "Grant",
                    primaryAction: {}
                ).withState(.granted)
            )
        }

        if !surfaceController.hasScreenRecordingPermission {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .screenRecording,
                    title: "Screen Recording",
                    detail: hasCompletedOnboarding
                        ? "So Clicky can continue seeing enough context to guide and act safely."
                        : "So Clicky can see enough context to guide and act safely.",
                    primaryTitle: "Grant",
                    primaryAction: requestScreenRecordingPermission
                ).withState(rowState(for: .screenRecording, isGranted: false))
            )
        } else if recentlyGrantedPermissions.contains(.screenRecording) {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .screenRecording,
                    title: "Screen Recording",
                    detail: "Resolved and quiet again.",
                    primaryTitle: "Grant",
                    primaryAction: {}
                ).withState(.granted)
            )
        }

        if surfaceController.hasScreenRecordingPermission && !surfaceController.hasScreenContentPermission {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .screenContent,
                    title: "Screen Content",
                    detail: hasCompletedOnboarding
                        ? "So Clicky can still understand the text and interfaces in front of you."
                        : "So Clicky can still understand the text and interfaces in front of you.",
                    primaryTitle: companionManager.isRequestingScreenContent ? "Waiting…" : "Grant",
                    primaryAction: {
                        companionManager.requestScreenContentPermission()
                    }
                ).withState(rowState(for: .screenContent, isGranted: false))
            )
        } else if surfaceController.hasScreenRecordingPermission && recentlyGrantedPermissions.contains(.screenContent) {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .screenContent,
                    title: "Screen Content",
                    detail: "Resolved and quiet again.",
                    primaryTitle: "Grant",
                    primaryAction: {}
                ).withState(.granted)
            )
        }

        if rows.isEmpty {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .accessibility,
                    title: "All set",
                    detail: "Everything Clicky needs is already available.",
                    primaryTitle: "Continue",
                    primaryAction: continueFromPermissions
                ).withState(.granted)
            )
        }

        return rows
    }

    private var footerSection: some View {
        HStack(spacing: 18) {
            Button(action: {
                NSApp.terminate(nil)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .medium))
                    Text("Quit Clicky")
                        .font(ClickyTypography.body(size: 12, weight: .medium))
                }
                .foregroundColor(theme.textPrimary)
            }
            .buttonStyle(.plain)
            .modifier(ClickyFooterActionStyle())
            .pointerCursor()

            Spacer(minLength: 0)
        }
    }

    private var headerPillForeground: Color {
        switch panelScreen {
        case .locked:
            return theme.warning
        case .repair:
            return theme.textPrimary
        case .active, .welcome, .signIn, .permissions, .ready, .tutorialEntry, .tutorialImportEntry, .tutorialImportMissingSetup, .tutorialExtracting, .tutorialCompiling, .tutorialReady, .tutorialPlayback, .tutorialFailed:
            return theme.textPrimary
        }
    }

    private var headerPillBackground: Color {
        switch panelScreen {
        case .locked:
            return theme.warning.opacity(0.14)
        case .repair:
            return theme.primary.opacity(0.10)
        case .active, .welcome, .signIn, .permissions, .ready, .tutorialEntry, .tutorialImportEntry, .tutorialImportMissingSetup, .tutorialExtracting, .tutorialCompiling, .tutorialReady, .tutorialPlayback, .tutorialFailed:
            return theme.primary.opacity(0.12)
        }
    }

    private var headerPillBorder: Color {
        switch panelScreen {
        case .locked:
            return theme.warning.opacity(0.32)
        case .repair:
            return theme.primary.opacity(0.20)
        case .active, .welcome, .signIn, .permissions, .ready, .tutorialEntry, .tutorialImportEntry, .tutorialImportMissingSetup, .tutorialExtracting, .tutorialCompiling, .tutorialReady, .tutorialPlayback, .tutorialFailed:
            return theme.strokeSoft
        }
    }

    private var signInSummaryCopy: String {
        switch clickyLaunchAuthState {
        case .restoring:
            return "Clicky is restoring your session right now. Stay here for a moment while it checks your account and access."
        case .signingIn:
            return "Finish sign-in in your browser. Once the callback completes, Clicky will move you to the next step automatically."
        case .failed(let message):
            return message
        case .signedIn:
            return "You're signed in. Continue and Clicky will guide you through the remaining setup."
        case .signedOut:
            return "Once you're in, Clicky is ready to help across your work until your included credits run out."
        }
    }

    private var signInPrimaryButtonTitle: String {
        switch clickyLaunchAuthState {
        case .signingIn:
            return "Waiting…"
        case .restoring:
            return "Restoring…"
        case .signedOut, .failed:
            return "Sign In"
        case .signedIn:
            return "Continue"
        }
    }

    private var launchCreditsLabel: String {
        if hasUnlimitedClickyLaunchAccess {
            return "Unlocked"
        }

        return clickyLaunchTrialStatusLabel
    }

    private var tutorialExtractionProgress: Double {
        guard let draft = tutorialController.currentTutorialImportDraft else { return 0.22 }

        switch draft.status {
        case .extracting:
            return 0.48
        case .extracted:
            return 0.66
        case .compiling:
            return 0.84
        case .ready:
            return 1.0
        case .failed:
            return 0.18
        case .pending:
            return 0.08
        }
    }

    private var tutorialLessonTitle: String {
        tutorialController.currentTutorialImportDraft?.compiledLessonDraft?.title
            ?? tutorialController.currentTutorialImportDraft?.title
            ?? "Your guided lesson"
    }

    private var tutorialLessonSummaryLine: String {
        if let lessonDraft = tutorialController.currentTutorialImportDraft?.compiledLessonDraft {
            let stepCount = lessonDraft.steps.count
            return "\(stepCount) steps · \(tutorialController.currentTutorialImportDraft?.channelName ?? "guided help") · answer questions as you go"
        }

        return "Guided help is ready beside your cursor."
    }

    private var tutorialPlaybackTitle: String {
        if let session = tutorialController.tutorialSessionState,
           session.lessonDraft.steps.indices.contains(session.currentStepIndex) {
            return session.lessonDraft.steps[session.currentStepIndex].title
        }

        return "Continue the lesson."
    }

    private var tutorialFailureReason: String {
        tutorialController.currentTutorialImportDraft?.extractionError
            ?? tutorialController.currentTutorialImportDraft?.compileError
            ?? tutorialController.tutorialImportStatusMessage
            ?? "The extraction service returned an incomplete evidence bundle."
    }

    private var panelHairline: some View {
        Rectangle()
            .fill(theme.strokeSoft)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private var statusText: String {
        if !hasCompletedOnboarding || !allPermissionsGranted {
            return "Setup"
        }

        if companionManager.isClickyLaunchPaywallActive {
            return "Locked"
        }

        if !surfaceController.isOverlayVisible {
            return "Ready"
        }

        switch surfaceController.voiceState {
        case .idle:
            return "Active"
        case .listening:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .thinking:
            return "Thinking"
        case .responding:
            return "Responding"
        }
    }

    private func continueFromWelcome() {
        withAnimation(panelSpringAnimation) {
            if isClickyLaunchSignedIn {
                onboardingStage = allPermissionsGranted ? .ready : .permissions
            } else {
                onboardingStage = .signIn
            }
        }
    }

    private func continueFromPermissions() {
        companionManager.refreshAllPermissions()

        if allPermissionsGranted {
            withAnimation(panelSpringAnimation) {
                onboardingStage = .ready
            }
        }
    }

    private func requestMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func requestAccessibilityPermission() {
        _ = WindowPositionManager.requestAccessibilityPermission()
        companionManager.refreshAllPermissions()
    }

    private func requestScreenRecordingPermission() {
        _ = WindowPositionManager.requestScreenRecordingPermission()
        companionManager.refreshAllPermissions()
    }

    private func handleSignInPrimaryAction() {
        switch clickyLaunchAuthState {
        case .signedIn:
            withAnimation(panelSpringAnimation) {
                onboardingStage = allPermissionsGranted ? .ready : .permissions
            }
        case .restoring, .signingIn:
            break
        case .signedOut, .failed:
            companionManager.startClickyLaunchSignIn()
        }
    }

    private func syncOnboardingStage() {
        guard !hasCompletedOnboarding else { return }

        switch onboardingStage {
        case .welcome:
            break
        case .signIn:
            if isClickyLaunchSignedIn {
                withAnimation(panelSpringAnimation) {
                    onboardingStage = allPermissionsGranted ? .ready : .permissions
                }
            }
        case .permissions:
            if allPermissionsGranted {
                withAnimation(panelSpringAnimation) {
                    onboardingStage = .ready
                }
            }
        case .ready:
            if !allPermissionsGranted {
                withAnimation(panelSpringAnimation) {
                    onboardingStage = .permissions
                }
            }
        }
    }

    private func dismissPanel() {
        NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)
    }

    private func handleTrailingHeaderAction() {
        if isInTutorialPanelFlow {
            exitTutorialFlow()
        } else {
            dismissPanel()
        }
    }

    private func exitTutorialFlow() {
        if tutorialController.tutorialPlaybackState?.isVisible == true {
            companionManager.stopTutorialPlayback()
        }

        withAnimation(panelCardAnimation) {
            isShowingTutorialFlow = false
            showsTutorialEntryExplainer = false
        }
    }

    private func openStudio() {
        NotificationCenter.default.post(name: .clickyOpenStudio, object: nil)
    }

    private var companionBackendButtons: some View {
        CompanionPanelBackendButtons(
            selectedBackend: preferences.selectedAgentBackend,
            setSelectedBackend: companionManager.setSelectedAgentBackend
        )
    }

    private func panelSectionEyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ClickyTypography.mono(size: 10, weight: .semibold))
            .foregroundColor(contentTheme.textMuted)
            .tracking(1.2)
    }

    private func panelInlineStatus(label: String, tone: PanelInlineStatusTone) -> some View {
        Text(label)
            .font(ClickyTypography.mono(size: 10, weight: .semibold))
            .foregroundColor(panelInlineStatusForeground(tone))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(panelInlineStatusBackground(tone))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(panelInlineStatusBorder(tone), lineWidth: 0.8)
            )
    }

    private func panelInlineStatusForeground(_ tone: PanelInlineStatusTone) -> Color {
        switch tone {
        case .neutral:
            return theme.textSecondary
        case .success:
            return theme.success
        case .warning:
            return theme.warning
        case .info:
            return theme.accentStrong
        }
    }

    private func panelInlineStatusBackground(_ tone: PanelInlineStatusTone) -> Color {
        switch tone {
        case .neutral:
            return Color.white.opacity(0.02)
        case .success:
            return theme.success.opacity(0.12)
        case .warning:
            return theme.warning.opacity(0.12)
        case .info:
            return theme.primary.opacity(0.12)
        }
    }

    private func panelInlineStatusBorder(_ tone: PanelInlineStatusTone) -> Color {
        switch tone {
        case .neutral:
            return theme.strokeSoft
        case .success:
            return theme.success.opacity(0.3)
        case .warning:
            return theme.warning.opacity(0.3)
        case .info:
            return theme.primary.opacity(0.3)
        }
    }

    private var panelScreenKey: String {
        switch panelScreen {
        case .welcome:
            return "welcome"
        case .signIn:
            return "sign-in"
        case .permissions:
            return "permissions"
        case .ready:
            return "ready"
        case .active:
            return "active"
        case .locked:
            return "locked"
        case .repair:
            return "repair"
        case .tutorialEntry:
            return "tutorial-entry"
        case .tutorialImportEntry:
            return "tutorial-import-entry"
        case .tutorialImportMissingSetup:
            return "tutorial-missing-setup"
        case .tutorialExtracting:
            return "tutorial-extracting"
        case .tutorialCompiling:
            return "tutorial-compiling"
        case .tutorialReady:
            return "tutorial-ready"
        case .tutorialPlayback:
            return "tutorial-playback"
        case .tutorialFailed:
            return "tutorial-failed"
        }
    }

    private var panelSpringAnimation: Animation {
        .spring(response: 0.32, dampingFraction: 0.88)
    }

    private var panelCardAnimation: Animation {
        .easeInOut(duration: 0.2)
    }

    private var panelCardTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: PanelCardTransitionModifier(opacity: 0, offsetY: 6),
                identity: PanelCardTransitionModifier(opacity: 1, offsetY: 0)
            ),
            removal: .modifier(
                active: PanelCardTransitionModifier(opacity: 0, offsetY: -6),
                identity: PanelCardTransitionModifier(opacity: 1, offsetY: 0)
            )
        )
    }

    private func requestPanelRelayout(animated: Bool) {
        NotificationCenter.default.post(name: .clickyPanelNeedsLayout, object: nil)
    }

    private func rowState(for kind: CompanionPermissionKind, isGranted: Bool) -> CompanionPermissionRowState {
        if isGranted || recentlyGrantedPermissions.contains(kind) {
            return .granted
        }

        return .missing
    }

    private func handlePermissionStateChange(_ kind: CompanionPermissionKind, isGranted: Bool) {
        guard isGranted else { return }

        withAnimation(.easeInOut(duration: 0.22)) {
            _ = recentlyGrantedPermissions.insert(kind)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            withAnimation(.easeInOut(duration: 0.22)) {
                _ = recentlyGrantedPermissions.remove(kind)
            }
        }
    }
}

private enum CompanionPanelScreen {
    case welcome
    case signIn
    case permissions
    case ready
    case active
    case locked
    case repair
    case tutorialEntry
    case tutorialImportEntry
    case tutorialImportMissingSetup
    case tutorialExtracting
    case tutorialCompiling
    case tutorialReady
    case tutorialPlayback
    case tutorialFailed
}

private enum CompanionPanelOnboardingStage: Int {
    case welcome
    case signIn
    case permissions
    case ready
}

private enum CompanionPermissionKind: Hashable {
    case accessibility
    case microphone
    case screenRecording
    case screenContent
}

private enum CompanionPermissionRowState: Equatable {
    case missing
    case granted

    func dotColor(_ theme: ClickyTheme) -> Color {
        switch self {
        case .missing:
            return theme.warning.opacity(0.7)
        case .granted:
            return theme.success.opacity(0.75)
        }
    }

    func backgroundColor(_ theme: ClickyTheme) -> Color {
        switch self {
        case .missing:
            return Color.clear
        case .granted:
            return theme.success.opacity(0.08)
        }
    }

    func borderColor(_ theme: ClickyTheme) -> Color {
        switch self {
        case .missing:
            return Color.clear
        case .granted:
            return theme.success.opacity(0.22)
        }
    }
}

private struct CompanionPanelPermissionRow: Identifiable {
    let id = UUID()
    let kind: CompanionPermissionKind
    let title: String
    let detail: String
    let primaryTitle: String
    let primaryAction: () -> Void
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var state: CompanionPermissionRowState = .missing

    func withState(_ state: CompanionPermissionRowState) -> Self {
        var copy = self
        copy.state = state
        return copy
    }
}

private enum PanelInlineStatusTone {
    case neutral
    case success
    case warning
    case info
}

private enum ClickyPanelContentTone {
    case regular
    case hero
    case subtle
}

private struct ClickyPanelContentCardStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    let tone: ClickyPanelContentTone
    let padding: CGFloat

    init(tone: ClickyPanelContentTone = .regular, padding: CGFloat = 15) {
        self.tone = tone
        self.padding = padding
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        content
            .clickyTheme(theme.contentSurfaceTheme)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                shape
                    .fill(backgroundFill)
                    .overlay(shape.fill(highlightFill))
            )
            .overlay(
                shape
                    .stroke(borderColor, lineWidth: 0.9)
            )
            .shadow(color: Color.black.opacity(tone == .subtle ? 0.04 : 0.07), radius: 18, y: 8)
    }

    private var backgroundFill: Color {
        switch tone {
        case .regular:
            return theme.card.opacity(0.92)
        case .hero:
            return theme.secondary.opacity(0.96)
        case .subtle:
            return theme.card.opacity(0.82)
        }
    }

    private var highlightFill: LinearGradient {
        switch tone {
        case .regular:
            return LinearGradient(
                colors: [Color.white.opacity(0.08), theme.secondary.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hero:
            return LinearGradient(
                colors: [Color.white.opacity(0.10), theme.primary.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .subtle:
            return LinearGradient(
                colors: [Color.white.opacity(0.06), theme.secondary.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        switch tone {
        case .regular:
            return theme.border.opacity(0.72)
        case .hero:
            return theme.primary.opacity(0.22)
        case .subtle:
            return theme.border.opacity(0.52)
        }
    }
}

struct ClickyProminentActionStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme
    let attentionMode: ClickyPanelAttentionMode

    init(attentionMode: ClickyPanelAttentionMode = .none) {
        self.attentionMode = attentionMode
    }

    func body(content: Content) -> some View {
        content
            .buttonStyle(ClickyPrimaryPanelButtonStyle(theme: theme, attentionMode: attentionMode))
    }
}

struct ClickySecondaryGlassButtonStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        content
            .buttonStyle(ClickySecondaryPanelButtonStyle(theme: theme))
    }
}

enum ClickyPanelAttentionMode {
    case none
    case singlePulse
    case loopingPulse
}

private struct ClickyPrimaryPanelButtonStyle: ButtonStyle {
    let theme: ClickyTheme
    let attentionMode: ClickyPanelAttentionMode

    @State private var isHovered = false
    @State private var pulseAmount: CGFloat = 0
    @State private var triggeredSinglePulse = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ClickyTypography.body(size: 13, weight: .semibold))
            .foregroundColor(theme.accentForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .multilineTextAlignment(.center)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.primary)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.22 : 0.10),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isHovered ? 0.18 : 0.10), lineWidth: 0.9)
            )
            .shadow(
                color: theme.accent.opacity(attentionShadowOpacity),
                radius: 10 + (pulseAmount * 8),
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.985 : (isHovered ? 1.01 : (1 + (pulseAmount * 0.015))))
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onAppear {
                startPulseIfNeeded()
            }
    }

    private var attentionShadowOpacity: Double {
        switch attentionMode {
        case .none:
            return isHovered ? 0.16 : 0.10
        case .singlePulse, .loopingPulse:
            return 0.16 + (0.18 * Double(pulseAmount))
        }
    }

    private func startPulseIfNeeded() {
        switch attentionMode {
        case .none:
            pulseAmount = 0
        case .singlePulse:
            guard !triggeredSinglePulse else { return }
            triggeredSinglePulse = true
            pulseAmount = 0
            withAnimation(.easeInOut(duration: 1.2)) {
                pulseAmount = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.4)) {
                    pulseAmount = 0
                }
            }
        case .loopingPulse:
            pulseAmount = 0
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulseAmount = 1
            }
        }
    }
}

private struct ClickySecondaryPanelButtonStyle: ButtonStyle {
    let theme: ClickyTheme

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let contentTheme = theme.contentSurfaceTheme

        return configuration.label
            .font(ClickyTypography.body(size: 12, weight: .semibold))
            .foregroundColor(contentTheme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.88)
            .multilineTextAlignment(.center)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(contentTheme.card.opacity(isHovered ? 1.0 : 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(contentTheme.border.opacity(isHovered ? 0.98 : 0.86), lineWidth: 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : (isHovered ? 1.003 : 1.0))
            .shadow(color: Color.black.opacity(isHovered ? 0.10 : 0.07), radius: 8, y: 3)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

private struct ClickyFooterActionStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.background.opacity(0.42))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
    }
}

private struct ClickyTinyGlassCircleStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(buttonFill)
                    .overlay(
                        Circle()
                            .stroke(buttonStroke, lineWidth: 1)
                    )
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isHovered ? 0.34 : 0.22),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .padding(1)
                            .clipShape(Circle())
                    )
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.10 : 0.06), radius: 8, y: 3)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var buttonFill: Color {
        let base = theme.contentSurfaceTheme.card
        return base.opacity(isHovered ? 0.94 : 0.88)
    }

    private var buttonStroke: Color {
        theme.contentSurfaceTheme.border.opacity(isHovered ? 0.95 : 0.82)
    }
}

private struct ClickyPanelShellStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        if #available(macOS 26.0, *) {
            content
                .padding(18)
                .glassEffect(.clear, in: shape)
                .overlay(
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.10),
                                    theme.primary.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.18), radius: 28, y: 16)
        } else {
            content
                .clickyGlassCard(cornerRadius: 28, padding: 18)
        }
    }
}

private extension View {
    @ViewBuilder
    func panelGlassMotionID(_ identifier: String, namespace: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffectID(identifier, in: namespace)
        } else {
            self
        }
    }
}

private struct PanelCardTransitionModifier: ViewModifier {
    let opacity: Double
    let offsetY: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(y: offsetY)
    }
}

private struct CompanionCreditsChip: View {
    let label: String
    let tone: PanelInlineStatusTone

    @State private var shimmerOffset: CGFloat = -1
    @Environment(\.clickyTheme) private var theme

    var body: some View {
        Text(label)
            .font(ClickyTypography.mono(size: 10, weight: .semibold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
                    .overlay {
                        GeometryReader { geometry in
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: geometry.size.width * 0.4)
                            .offset(x: geometry.size.width * shimmerOffset)
                            .blendMode(.screen)
                        }
                        .clipShape(Capsule(style: .continuous))
                    }
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor, lineWidth: 0.8)
            )
            .onAppear {
                shimmerOffset = -1
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false).delay(2.8)) {
                    shimmerOffset = 1.6
                }
            }
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return theme.textSecondary
        case .success:
            return theme.success
        case .warning:
            return theme.warning
        case .info:
            return theme.accentStrong
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            return Color.white.opacity(0.02)
        case .success:
            return theme.success.opacity(0.12)
        case .warning:
            return theme.warning.opacity(0.12)
        case .info:
            return theme.primary.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral:
            return theme.strokeSoft
        case .success:
            return theme.success.opacity(0.3)
        case .warning:
            return theme.warning.opacity(0.3)
        case .info:
            return theme.primary.opacity(0.3)
        }
    }
}
