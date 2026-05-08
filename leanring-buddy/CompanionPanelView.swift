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

    private var isClickyLaunchAuthPending: Bool {
        switch clickyLaunchAuthState {
        case .restoring, .signingIn:
            return true
        case .signedOut, .signedIn, .failed:
            return false
        }
    }

    private var isClickyLaunchPaywallActive: Bool {
        companionManager.launchTurnGate.isPaywallActive()
    }

    private var requiresLaunchSignInForCompanionUse: Bool {
        companionManager.launchTurnGate.requiresSignInForCompanionUse(
            hasCompletedOnboarding: hasCompletedOnboarding,
            allPermissionsGranted: allPermissionsGranted
        )
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

    private var panelFlowState: CompanionPanelFlowState {
        CompanionPanelFlowState(
            isLaunchPaywallActive: isClickyLaunchPaywallActive,
            hasCompletedOnboarding: hasCompletedOnboarding,
            isLaunchAuthPending: isClickyLaunchAuthPending,
            requiresLaunchSignInForCompanionUse: requiresLaunchSignInForCompanionUse,
            allPermissionsGranted: allPermissionsGranted,
            onboardingStage: onboardingStage,
            isShowingTutorialFlow: isShowingTutorialFlow,
            hasVisibleTutorialPlayback: tutorialController.tutorialPlaybackState?.isVisible == true,
            isTutorialImportRunning: tutorialController.isTutorialImportRunning,
            tutorialImportStatus: tutorialController.currentTutorialImportDraft?.status,
            isTutorialExtractorConfigured: CompanionRuntimeConfiguration.isTutorialExtractorConfigured
        )
    }

    private var panelScreen: CompanionPanelScreen {
        panelFlowState.panelScreen
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

    private var isInTutorialPanelFlow: Bool {
        panelFlowState.isInTutorialPanelFlow
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
            CompanionPanelHairline()
            panelBody
            CompanionPanelHairline()
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
        CompanionPanelPrimaryContentCard(
            screen: panelScreen,
            tutorialPlaybackTitle: tutorialPlaybackTitle
        )
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

    private var onboardingWelcomeCard: some View {
        CompanionPanelOnboardingWelcomeCard(
            continueFromWelcome: continueFromWelcome,
            openStudio: openStudio
        )
    }

    private var onboardingSignInCard: some View {
        CompanionPanelSignInCard(
            authState: clickyLaunchAuthState,
            showsWhyCopy: showsSignInWhyCopy,
            primaryAction: handleSignInPrimaryAction,
            toggleWhyCopy: toggleSignInWhyCopy
        )
    }

    private var onboardingReadyCard: some View {
        CompanionPanelOnboardingReadyCard(
            startUsingClicky: companionManager.surfaceLifecycleCoordinator.triggerOnboarding,
            openStudio: openStudio
        )
    }

    private var activeStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            tutorialEntryPointCard

            currentFeelCard
        }
    }

    private var currentFeelCard: some View {
        CompanionPanelCurrentFeelCard(
            personaLabel: activeClickyPersonaLabel,
            voicePreset: effectiveClickyVoicePreset,
            cursorStyle: effectiveClickyCursorStyle,
            creditsLabel: hasUnlimitedClickyLaunchAccess ? "Unlocked" : clickyLaunchTrialStatusLabel,
            hasUnlimitedAccess: hasUnlimitedClickyLaunchAccess,
            selectedBackend: preferences.selectedAgentBackend,
            setSelectedBackend: companionManager.settingsMutationCoordinator.setSelectedBackend
        )
    }

    private var tutorialEntryPointCard: some View {
        CompanionPanelTutorialEntryPointCard(
            showsExplainer: showsTutorialEntryExplainer,
            startLearning: enterTutorialFlow,
            toggleExplainer: toggleTutorialEntryExplainer
        )
    }

    private var tutorialImportEntryCard: some View {
        CompanionPanelTutorialImportEntryCard(
            tutorialController: tutorialController,
            startImport: companionManager.tutorialImportCoordinator.startImportFromPanel
        )
    }

    private var tutorialImportMissingSetupCard: some View {
        CompanionPanelTutorialImportMissingSetupCard(
            tutorialController: tutorialController,
            startImport: companionManager.tutorialImportCoordinator.startImportFromPanel,
            openStudio: openStudio
        )
    }

    private var tutorialExtractingCard: some View {
        CompanionPanelTutorialExtractingCard(
            tutorialController: tutorialController,
            cancel: leaveTutorialImportFlow
        )
    }

    private var tutorialCompilingCard: some View {
        CompanionPanelTutorialCompilingCard(cancel: leaveTutorialImportFlow)
    }

    private var tutorialReadyCard: some View {
        CompanionPanelTutorialReadyCard(
            tutorialController: tutorialController,
            startLesson: companionManager.tutorialPlaybackCoordinator.startLessonFromReadyState,
            openStudio: openStudio
        )
    }

    private var tutorialPlaybackCard: some View {
        CompanionPanelTutorialPlaybackCard(
            repeatStep: companionManager.tutorialPlaybackCoordinator.repeatLessonStepFromPanel,
            rewind: companionManager.tutorialPlaybackCoordinator.rewindLessonFromPanel,
            advance: companionManager.tutorialPlaybackCoordinator.advanceLessonFromPanel
        )
    }

    private var tutorialFailedCard: some View {
        CompanionPanelTutorialFailedCard(
            tutorialController: tutorialController,
            retryImport: companionManager.tutorialImportCoordinator.retryImportFromPanel,
            openStudio: openStudio
        )
    }

    private var lockedStateCard: some View {
        CompanionPanelLockedStateCard(
            showsStudioChip: showsLockedStudioChip,
            startCheckout: companionManager.launchFlowCoordinator.startCheckout,
            signOut: companionManager.launchFlowCoordinator.signOut
        )
    }

    private func permissionsCard(
        primaryTitle: String?,
        secondaryTitle: String?,
        secondaryAction: (() -> Void)?
    ) -> some View {
        CompanionPanelPermissionsCard(
            rows: permissionRows,
            primaryTitle: primaryTitle,
            primaryAction: continueFromPermissions,
            secondaryTitle: secondaryTitle,
            secondaryAction: secondaryAction
        )
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
                        companionManager.permissionCoordinator.requestScreenContentPermission()
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

    private var tutorialPlaybackTitle: String {
        if let session = tutorialController.tutorialSessionState,
           session.lessonDraft.steps.indices.contains(session.currentStepIndex) {
            return session.lessonDraft.steps[session.currentStepIndex].title
        }

        return "Continue the lesson."
    }

    private var statusText: String {
        if !hasCompletedOnboarding || !allPermissionsGranted {
            return "Setup"
        }

        if isClickyLaunchPaywallActive {
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
        companionManager.permissionCoordinator.refreshAllPermissions()

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
        companionManager.permissionCoordinator.refreshAllPermissions()
    }

    private func requestScreenRecordingPermission() {
        _ = WindowPositionManager.requestScreenRecordingPermission()
        companionManager.permissionCoordinator.refreshAllPermissions()
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
            companionManager.launchFlowCoordinator.startSignIn()
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

    private func enterTutorialFlow() {
        withAnimation(panelCardAnimation) {
            isShowingTutorialFlow = true
            showsTutorialEntryExplainer = false
        }
    }

    private func toggleTutorialEntryExplainer() {
        withAnimation(panelCardAnimation) {
            showsTutorialEntryExplainer.toggle()
        }
    }

    private func toggleSignInWhyCopy() {
        withAnimation(panelSpringAnimation) {
            showsSignInWhyCopy.toggle()
        }
    }

    private func leaveTutorialImportFlow() {
        isShowingTutorialFlow = false
    }

    private func exitTutorialFlow() {
        if tutorialController.tutorialPlaybackState?.isVisible == true {
            companionManager.tutorialPlaybackCoordinator.stopPlayback()
        }

        withAnimation(panelCardAnimation) {
            isShowingTutorialFlow = false
            showsTutorialEntryExplainer = false
        }
    }

    private func openStudio() {
        NotificationCenter.default.post(name: .clickyOpenStudio, object: nil)
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
