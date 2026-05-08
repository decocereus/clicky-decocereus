//
//  BlueCursorView.swift
//  leanring-buddy
//
//  SwiftUI composition and interaction state for the system-wide cursor buddy.
//

import AppKit
import SwiftUI

// SwiftUI view for the blue glowing cursor pointer.
// Each screen gets its own BlueCursorView. The view checks whether
// the cursor is currently on THIS screen and only shows the buddy
// triangle when it is. During voice interaction, the triangle is
// replaced by a waveform (listening), spinner (processing), or
// streaming text bubble (responding).
struct BlueCursorView: View {
    let screenFrame: CGRect
    let isFirstAppearance: Bool
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var surfaceController: ClickySurfaceController
    @ObservedObject private var tutorialController: ClickyTutorialController

    @State private var cursorPosition: CGPoint
    @State private var isCursorOnThisScreen: Bool

    init(screenFrame: CGRect, isFirstAppearance: Bool, companionManager: CompanionManager) {
        self.screenFrame = screenFrame
        self.isFirstAppearance = isFirstAppearance
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _surfaceController = ObservedObject(wrappedValue: companionManager.surfaceController)
        _tutorialController = ObservedObject(wrappedValue: companionManager.tutorialController)

        // Seed the cursor position from the current mouse location so the
        // buddy doesn't flash at (0,0) before onAppear fires.
        let mouseLocation = NSEvent.mouseLocation
        let localX = mouseLocation.x - screenFrame.origin.x
        let localY = screenFrame.height - (mouseLocation.y - screenFrame.origin.y)
        _cursorPosition = State(initialValue: CGPoint(x: localX + 35, y: localY + 25))
        _isCursorOnThisScreen = State(initialValue: screenFrame.contains(mouseLocation))
    }
    @State private var timer: Timer?
    @State private var welcomeText: String = ""
    @State private var showWelcome: Bool = true
    @State private var bubbleSize: CGSize = .zero
    @State private var bubbleOpacity: Double = 1.0
    @State private var cursorOpacity: Double = 0.0
    @State private var pulseCursorIsExpanded: Bool = false
    @State private var haloLoadingExpanded: Bool = false

    // MARK: - Buddy Navigation State

    /// The buddy's current behavioral mode (following cursor, navigating, or pointing).
    @State private var buddyNavigationMode: BuddyNavigationMode = .followingCursor

    /// The rotation angle of the triangle in degrees. Default is -35° (cursor-like).
    /// Changes to face the direction of travel when navigating to a target.
    @State private var triangleRotationDegrees: Double = -35.0

    /// Speech bubble text shown when pointing at a detected element.
    @State private var navigationBubbleText: String = ""
    @State private var navigationBubbleOpacity: Double = 0.0
    @State private var navigationBubbleSize: CGSize = .zero

    /// The cursor position at the moment navigation started, used to detect
    /// if the user moves the cursor enough to cancel the navigation.
    @State private var cursorPositionWhenNavigationStarted: CGPoint = .zero

    /// Timer driving the frame-by-frame bezier arc flight animation.
    /// Invalidated when the flight completes, is canceled, or the view disappears.
    @State private var navigationAnimationTimer: Timer?

    /// Scale factor applied to the buddy triangle during flight. Grows to ~1.3x
    /// at the midpoint of the arc and shrinks back to 1.0x on landing, creating
    /// an energetic "swooping" feel.
    @State private var buddyFlightScale: CGFloat = 1.0

    /// Scale factor for the navigation speech bubble's pop-in entrance.
    /// Starts at 0.5 and springs to 1.0 when the first character appears.
    @State private var navigationBubbleScale: CGFloat = 1.0

    /// True when the buddy is flying BACK to the cursor after pointing.
    /// Only during the return flight can cursor movement cancel the animation.
    @State private var isReturningToCursor: Bool = false
    @State private var sequenceReturnPosition: CGPoint?

    private let fullWelcomeMessage = "hey! i'm clicky"

    private let navigationPointerPhrases = [
        "right here!",
        "this one!",
        "over here!",
        "here it is!",
        "found it!",
        "look here!"
    ]

    private var activeTheme: ClickyTheme {
        preferences.clickyThemePreset.theme
    }

    private var effectiveClickyCursorStyle: ClickyCursorStyle {
        preferences.clickyCursorStyle
    }

    var body: some View {
        ZStack {
            // Nearly transparent background (helps with compositing)
            Color.black.opacity(0.001)

            // Welcome speech bubble (first launch only)
            if isCursorOnThisScreen && showWelcome && !welcomeText.isEmpty {
                BlueCursorMeasuredSpeechBubble(text: welcomeText, accentColor: cursorAccentColor)
                    .opacity(bubbleOpacity)
                    .position(x: cursorPosition.x + 10 + (bubbleSize.width / 2), y: cursorPosition.y + 18)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.easeOut(duration: 0.5), value: bubbleOpacity)
                    .onPreferenceChange(BlueCursorBubbleSizePreferenceKey.self) { newSize in
                        bubbleSize = newSize
                    }
            }

            BlueCursorOnboardingVideoSurface(
                player: surfaceController.onboardingVideoPlayer,
                opacity: surfaceController.onboardingVideoOpacity,
                cursorPosition: cursorPosition,
                isCursorOnThisScreen: isCursorOnThisScreen
            )

            BlueCursorTutorialInlinePlayerSurface(
                tutorialController: tutorialController,
                cursorPosition: cursorPosition,
                isCursorOnThisScreen: isCursorOnThisScreen,
                accentColor: cursorAccentColor,
                bubbleSize: $bubbleSize
            )

            // Onboarding prompt — "press control + option and say hi" streamed after video ends
            if isCursorOnThisScreen && surfaceController.showOnboardingPrompt && !surfaceController.onboardingPromptText.isEmpty {
                BlueCursorMeasuredSpeechBubble(text: surfaceController.onboardingPromptText, accentColor: cursorAccentColor)
                    .opacity(surfaceController.onboardingPromptOpacity)
                    .position(x: cursorPosition.x + 10 + (bubbleSize.width / 2), y: cursorPosition.y + 18)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.easeOut(duration: 0.4), value: surfaceController.onboardingPromptOpacity)
                    .onPreferenceChange(BlueCursorBubbleSizePreferenceKey.self) { newSize in
                        bubbleSize = newSize
                    }
            }

            // Navigation pointer bubble — shown when buddy arrives at a detected element.
            // Pops in with a scale-bounce (0.5x → 1.0x spring) and a bright initial
            // glow that settles, creating a "materializing" effect.
            if buddyNavigationMode == .pointingAtTarget && !navigationBubbleText.isEmpty {
                BlueCursorMeasuredNavigationBubble(
                    text: navigationBubbleText,
                    accentColor: cursorAccentColor,
                    scale: navigationBubbleScale
                )
                    .scaleEffect(navigationBubbleScale)
                    .opacity(navigationBubbleOpacity)
                    .position(x: cursorPosition.x + 10 + (navigationBubbleSize.width / 2), y: cursorPosition.y + 18)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: navigationBubbleScale)
                    .animation(.easeOut(duration: 0.5), value: navigationBubbleOpacity)
                    .onPreferenceChange(BlueCursorNavigationBubbleSizePreferenceKey.self) { newSize in
                        navigationBubbleSize = newSize
                    }
            }

            // Blue triangle cursor — shown only when idle.
            // All cursor treatments stay in the view tree
            // permanently and cross-fade via opacity so SwiftUI doesn't remove/re-insert
            // them (which caused a visible cursor "pop").
            //
            // During cursor following: fast spring animation for snappy tracking.
            // During navigation: NO implicit animation — the frame-by-frame bezier
            // timer controls position directly at 60fps for a smooth arc flight.
            personaCursorIdleView
                .opacity(
                    buddyIsVisibleOnThisScreen
                        && (surfaceController.voiceState == .idle || buddyNavigationMode != .followingCursor)
                        ? cursorOpacity
                        : 0
                )
                .position(cursorPosition)
                .animation(
                    buddyNavigationMode == .followingCursor
                        ? .spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0)
                        : nil,
                    value: cursorPosition
                )
                .animation(.easeIn(duration: 0.25), value: surfaceController.voiceState)
                .animation(
                    buddyNavigationMode == .navigatingToTarget ? nil : .easeInOut(duration: 0.3),
                    value: triangleRotationDegrees
                )

            // Style-aware listening indicator
            listeningIndicatorView
                .opacity(
                    buddyIsVisibleOnThisScreen
                        && buddyNavigationMode == .followingCursor
                        && surfaceController.voiceState == .listening
                        ? cursorOpacity
                        : 0
                )
                .position(cursorPosition)
                .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                .animation(.easeIn(duration: 0.15), value: surfaceController.voiceState)

            // Style-aware transcribing indicator
            transcribingIndicatorView
                .opacity(
                    buddyIsVisibleOnThisScreen
                        && buddyNavigationMode == .followingCursor
                        && surfaceController.voiceState == .transcribing
                        ? cursorOpacity
                        : 0
                )
                .position(cursorPosition)
                .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                .animation(.easeIn(duration: 0.15), value: surfaceController.voiceState)

            // Style-aware thinking indicator
            thinkingIndicatorView
                .opacity(
                    buddyIsVisibleOnThisScreen
                        && buddyNavigationMode == .followingCursor
                        && surfaceController.voiceState == .thinking
                        ? cursorOpacity
                        : 0
                )
                .position(cursorPosition)
                .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                .animation(.easeIn(duration: 0.15), value: surfaceController.voiceState)

            // Style-aware responding indicator
            respondingIndicatorView
                .opacity(
                    buddyIsVisibleOnThisScreen
                        && buddyNavigationMode == .followingCursor
                        && surfaceController.voiceState == .responding
                        ? cursorOpacity
                        : 0
                )
                .position(cursorPosition)
                .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                .animation(.easeIn(duration: 0.15), value: surfaceController.voiceState)

        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .ignoresSafeArea()
        .onAppear {
            // Set initial cursor position immediately before starting animation
            let mouseLocation = NSEvent.mouseLocation
            isCursorOnThisScreen = screenFrame.contains(mouseLocation)

            let swiftUIPosition = convertScreenPointToSwiftUICoordinates(mouseLocation)
            self.cursorPosition = CGPoint(x: swiftUIPosition.x + 35, y: swiftUIPosition.y + 25)

            startTrackingCursor()

            // Only show welcome message on first appearance (app start)
            // and only if the cursor starts on this screen
            if isFirstAppearance && isCursorOnThisScreen {
                withAnimation(.easeIn(duration: 2.0)) {
                    self.cursorOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.bubbleOpacity = 0.0
                    startWelcomeAnimation()
                }
            } else {
                self.cursorOpacity = 1.0
            }

            if effectiveClickyCursorStyle == .pulse {
                withAnimation(.easeOut(duration: 1.05).repeatForever(autoreverses: true)) {
                    pulseCursorIsExpanded = true
                }
            }
            if effectiveClickyCursorStyle == .halo {
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                    haloLoadingExpanded = true
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            navigationAnimationTimer?.invalidate()
            companionManager.onboardingVideoController.tearDownVideo()
        }
        .onChange(of: surfaceController.detectedElementScreenLocation) { _, newLocation in
            // When a UI element location is detected, navigate the buddy to
            // that position so it points at the element.
            guard let screenLocation = newLocation,
                  let displayFrame = surfaceController.detectedElementDisplayFrame else {
                return
            }

            // Only navigate if the target is on THIS screen
            guard screenFrame.contains(CGPoint(x: displayFrame.midX, y: displayFrame.midY))
                  || displayFrame == screenFrame else {
                return
            }

            startNavigatingToElement(screenLocation: screenLocation)
        }
        .onChange(of: surfaceController.managedPointSequenceReturnToken) { _, _ in
            guard buddyNavigationMode == .pointingAtTarget else { return }
            navigationBubbleOpacity = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard self.buddyNavigationMode == .pointingAtTarget else { return }
                self.startFlyingBackToCursor()
            }
        }
    }

    private var cursorAccentColor: Color {
        return activeTheme.primary
    }

    private var cursorSecondaryColor: Color {
        return activeTheme.ring
    }

    private var cursorSoftGlowColor: Color {
        return activeTheme.glowB
    }

    @ViewBuilder
    private var listeningIndicatorView: some View {
        switch effectiveClickyCursorStyle {
        case .classic:
            BlueCursorWaveformView(
                audioPowerLevel: surfaceController.currentAudioPowerLevel,
                accentColor: cursorAccentColor,
                secondaryColor: cursorSecondaryColor
            )
        case .halo:
            HaloActivityIndicatorView(
                accentColor: cursorAccentColor,
                secondaryColor: cursorSecondaryColor,
                activityLevel: surfaceController.currentAudioPowerLevel,
                isExpanded: haloLoadingExpanded
            )
        case .pulse:
            PulsingOrbIndicatorView(
                accentColor: cursorAccentColor,
                secondaryColor: cursorSecondaryColor,
                activityLevel: surfaceController.currentAudioPowerLevel,
                mode: .listening
            )
        }
    }

    @ViewBuilder
    private var transcribingIndicatorView: some View {
        switch effectiveClickyCursorStyle {
        case .classic:
            BlueCursorSpinnerView(accentColor: cursorAccentColor, secondaryColor: cursorSecondaryColor)
        case .halo:
            HaloSpinnerIndicatorView(
                accentColor: cursorAccentColor,
                secondaryColor: cursorSecondaryColor,
                isExpanded: haloLoadingExpanded
            )
        case .pulse:
            PulsingOrbIndicatorView(
                accentColor: cursorAccentColor,
                secondaryColor: cursorSecondaryColor,
                activityLevel: 0.52,
                mode: .transcribing
            )
        }
    }

    @ViewBuilder
    private var thinkingIndicatorView: some View {
        switch effectiveClickyCursorStyle {
        case .classic:
            BlueCursorThinkingView(accentColor: cursorAccentColor, secondaryColor: cursorSecondaryColor)
        case .halo:
            HaloThinkingIndicatorView(
                accentColor: cursorAccentColor,
                secondaryColor: cursorSecondaryColor,
                isExpanded: haloLoadingExpanded
            )
        case .pulse:
            PulsingOrbIndicatorView(
                accentColor: cursorAccentColor,
                secondaryColor: cursorSecondaryColor,
                activityLevel: 0.76,
                mode: .thinking
            )
        }
    }

    @ViewBuilder
    private var respondingIndicatorView: some View {
        switch effectiveClickyCursorStyle {
        case .classic:
            BlueCursorSpeakingWaveformView(accentColor: cursorAccentColor, secondaryColor: cursorSecondaryColor)
        case .halo:
            HaloSpeakingIndicatorView(
                accentColor: cursorAccentColor,
                secondaryColor: cursorSecondaryColor,
                isExpanded: haloLoadingExpanded
            )
        case .pulse:
            PulsingOrbIndicatorView(
                accentColor: cursorAccentColor,
                secondaryColor: cursorSecondaryColor,
                activityLevel: 0.92,
                mode: .responding
            )
        }
    }

    @ViewBuilder
    private var personaCursorIdleView: some View {
        switch effectiveClickyCursorStyle {
        case .classic:
            Triangle()
                .fill(
                    LinearGradient(
                        colors: [cursorAccentColor, cursorSecondaryColor.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(triangleRotationDegrees))
                .overlay(
                    Triangle()
                        .stroke(cursorSoftGlowColor.opacity(0.45), lineWidth: 0.9)
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(triangleRotationDegrees))
                )
                .shadow(color: cursorSecondaryColor.opacity(0.55), radius: 8 + (buddyFlightScale - 1.0) * 20, x: 0, y: 0)
                .scaleEffect(buddyFlightScale)
        case .halo:
            ZStack {
                Circle()
                    .stroke(cursorSecondaryColor.opacity(0.55), lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                    .shadow(color: cursorSecondaryColor.opacity(0.32), radius: 10, x: 0, y: 0)

                Triangle()
                    .fill(
                        LinearGradient(
                            colors: [cursorAccentColor, cursorSecondaryColor.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(triangleRotationDegrees))
            }
            .scaleEffect(buddyFlightScale)
        case .pulse:
            ZStack {
                Circle()
                    .fill(cursorSecondaryColor.opacity(0.16))
                    .frame(width: 28, height: 28)
                    .scaleEffect(pulseCursorIsExpanded ? 1.35 : 0.92)
                    .opacity(pulseCursorIsExpanded ? 0.10 : 0.42)

                Circle()
                    .stroke(cursorSecondaryColor.opacity(0.45), lineWidth: 1.2)
                    .frame(width: 24, height: 24)
                    .scaleEffect(pulseCursorIsExpanded ? 1.22 : 0.96)
                    .opacity(pulseCursorIsExpanded ? 0.14 : 0.62)

                Triangle()
                    .fill(
                        LinearGradient(
                            colors: [cursorAccentColor, cursorSecondaryColor.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(triangleRotationDegrees))
                    .shadow(color: cursorSecondaryColor.opacity(0.42), radius: 12, x: 0, y: 0)
            }
            .scaleEffect(buddyFlightScale)
        }
    }

    /// Whether the buddy triangle should be visible on this screen.
    /// True when cursor is on this screen during normal following, or
    /// when navigating/pointing at a target on this screen. When another
    /// screen is navigating (detectedElementScreenLocation is set but this
    /// screen isn't the one animating), hide the cursor so only one buddy
    /// is ever visible at a time.
    private var buddyIsVisibleOnThisScreen: Bool {
        switch buddyNavigationMode {
        case .followingCursor:
            // If another screen's BlueCursorView is navigating to an element,
            // hide the cursor on this screen to prevent a duplicate buddy
            if surfaceController.detectedElementScreenLocation != nil {
                return false
            }
            return isCursorOnThisScreen
        case .navigatingToTarget, .pointingAtTarget:
            return true
        }
    }

    // MARK: - Cursor Tracking

    private func startTrackingCursor() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            let mouseLocation = NSEvent.mouseLocation
            self.isCursorOnThisScreen = self.screenFrame.contains(mouseLocation)

            // During forward flight or pointing, the buddy is NOT interrupted by
            // mouse movement — it completes its full animation and return flight.
            // Only during the RETURN flight do we allow cursor movement to cancel
            // (so the buddy snaps to following if the user moves while it's flying back).
            if case .navigatingToTarget = self.buddyNavigationMode, self.isReturningToCursor {
                let currentMouseInSwiftUI = self.convertScreenPointToSwiftUICoordinates(mouseLocation)
                let distanceFromNavigationStart = hypot(
                    currentMouseInSwiftUI.x - self.cursorPositionWhenNavigationStarted.x,
                    currentMouseInSwiftUI.y - self.cursorPositionWhenNavigationStarted.y
                )
                if distanceFromNavigationStart > 100 {
                    cancelNavigationAndResumeFollowing()
                }
                return
            }

            // During forward navigation or pointing, just skip cursor tracking
            if case .followingCursor = self.buddyNavigationMode {
                // Normal cursor following continues below.
            } else {
                return
            }

            // Normal cursor following
            let swiftUIPosition = self.convertScreenPointToSwiftUICoordinates(mouseLocation)
            let buddyX = swiftUIPosition.x + 35
            let buddyY = swiftUIPosition.y + 25
            self.cursorPosition = CGPoint(x: buddyX, y: buddyY)
        }
    }

    /// Converts a macOS screen point (AppKit, bottom-left origin) to SwiftUI
    /// coordinates (top-left origin) relative to this screen's overlay window.
    private func convertScreenPointToSwiftUICoordinates(_ screenPoint: CGPoint) -> CGPoint {
        let x = screenPoint.x - screenFrame.origin.x
        let y = (screenFrame.origin.y + screenFrame.height) - screenPoint.y
        return CGPoint(x: x, y: y)
    }

    // MARK: - Element Navigation

    /// Starts animating the buddy toward a detected UI element location.
    private func startNavigatingToElement(screenLocation: CGPoint) {
        // Don't interrupt welcome animation
        guard !showWelcome || welcomeText.isEmpty else { return }

        if sequenceReturnPosition == nil {
            sequenceReturnPosition = cursorPosition
        }

        navigationBubbleText = ""
        navigationBubbleOpacity = 0.0

        // Convert the AppKit screen location to SwiftUI coordinates for this screen
        let targetInSwiftUI = convertScreenPointToSwiftUICoordinates(screenLocation)

        // Offset the target so the buddy sits beside the element rather than
        // directly on top of it — 8px to the right, 12px below.
        let offsetTarget = CGPoint(
            x: targetInSwiftUI.x + 8,
            y: targetInSwiftUI.y + 12
        )

        // Clamp target to screen bounds with padding
        let clampedTarget = CGPoint(
            x: max(20, min(offsetTarget.x, screenFrame.width - 20)),
            y: max(20, min(offsetTarget.y, screenFrame.height - 20))
        )

        // Record the current cursor position so we can detect if the user
        // moves the mouse enough to cancel the return flight
        let mouseLocation = NSEvent.mouseLocation
        cursorPositionWhenNavigationStarted = convertScreenPointToSwiftUICoordinates(mouseLocation)

        // Enter navigation mode — stop cursor following
        buddyNavigationMode = .navigatingToTarget
        isReturningToCursor = false

        animateBezierFlightArc(to: clampedTarget) {
            guard self.buddyNavigationMode == .navigatingToTarget else { return }
            self.startPointingAtElement()
        }
    }

    /// Animates the buddy along a quadratic bezier arc from its current position
    /// to the specified destination. The triangle rotates to face its direction
    /// of travel (tangent to the curve) each frame, scales up at the midpoint
    /// for a "swooping" feel, and the glow intensifies during flight.
    private func animateBezierFlightArc(
        to destination: CGPoint,
        onComplete: @escaping () -> Void
    ) {
        navigationAnimationTimer?.invalidate()

        let flightPlan = BlueCursorFlightPlan(
            startPosition: cursorPosition,
            endPosition: destination
        )
        var currentFrame = 0

        navigationAnimationTimer = Timer.scheduledTimer(withTimeInterval: BlueCursorFlightPlan.frameInterval, repeats: true) { _ in
            currentFrame += 1

            guard let frame = flightPlan.frame(at: currentFrame) else {
                self.navigationAnimationTimer?.invalidate()
                self.navigationAnimationTimer = nil
                self.cursorPosition = flightPlan.endPosition
                self.buddyFlightScale = 1.0
                onComplete()
                return
            }

            self.cursorPosition = frame.position
            self.triangleRotationDegrees = frame.rotationDegrees
            self.buddyFlightScale = frame.scale
        }
    }

    /// Transitions to pointing mode — shows a speech bubble with a bouncy
    /// scale-in entrance and variable-speed character streaming.
    private func startPointingAtElement() {
        companionManager.tutorialPlaybackCoordinator.pauseForPointing()
        buddyNavigationMode = .pointingAtTarget

        // Rotate back to default pointer angle now that we've arrived
        triangleRotationDegrees = -35.0

        // Reset navigation bubble state — start small for the scale-bounce entrance
        navigationBubbleText = ""
        navigationBubbleOpacity = 1.0
        navigationBubbleSize = .zero
        navigationBubbleScale = 0.5

        // Use custom bubble text from the companion manager (e.g. onboarding demo)
        // if available, otherwise fall back to a random pointer phrase
        let pointerPhrase = surfaceController.detectedElementBubbleText
            ?? navigationPointerPhrases.randomElement()
            ?? "right here!"

        companionManager.pointingSequenceController.notifyTargetArrived()

        streamNavigationBubbleCharacter(phrase: pointerPhrase, characterIndex: 0) {
            guard !self.companionManager.pointingSequenceController.isManagedSequenceActive else {
                return
            }

            // All characters streamed — hold for 3 seconds, then continue.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                guard self.buddyNavigationMode == .pointingAtTarget else { return }
                self.navigationBubbleOpacity = 0.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard self.buddyNavigationMode == .pointingAtTarget else { return }
                    if self.companionManager.pointingSequenceController.hasPendingTargets {
                        self.companionManager.pointingSequenceController.advance()
                    } else {
                        self.startFlyingBackToCursor()
                    }
                }
            }
        }
    }

    /// Streams the navigation bubble text one character at a time with variable
    /// delays (30–60ms) for a natural "speaking" rhythm.
    private func streamNavigationBubbleCharacter(
        phrase: String,
        characterIndex: Int,
        onComplete: @escaping () -> Void
    ) {
        guard buddyNavigationMode == .pointingAtTarget else { return }
        guard characterIndex < phrase.count else {
            onComplete()
            return
        }

        let charIndex = phrase.index(phrase.startIndex, offsetBy: characterIndex)
        navigationBubbleText.append(phrase[charIndex])

        // On the first character, trigger the scale-bounce entrance
        if characterIndex == 0 {
            navigationBubbleScale = 1.0
        }

        let characterDelay = Double.random(in: 0.03...0.06)
        DispatchQueue.main.asyncAfter(deadline: .now() + characterDelay) {
            self.streamNavigationBubbleCharacter(
                phrase: phrase,
                characterIndex: characterIndex + 1,
                onComplete: onComplete
            )
        }
    }

    /// Flies the buddy back to the current cursor position after pointing is done.
    private func startFlyingBackToCursor() {
        let cursorInSwiftUI: CGPoint
        let cursorWithTrackingOffset: CGPoint

        if let sequenceReturnPosition {
            cursorWithTrackingOffset = sequenceReturnPosition
            cursorInSwiftUI = CGPoint(
                x: sequenceReturnPosition.x - 35,
                y: sequenceReturnPosition.y - 25
            )
        } else {
            let mouseLocation = NSEvent.mouseLocation
            cursorInSwiftUI = convertScreenPointToSwiftUICoordinates(mouseLocation)
            cursorWithTrackingOffset = CGPoint(x: cursorInSwiftUI.x + 35, y: cursorInSwiftUI.y + 25)
        }

        cursorPositionWhenNavigationStarted = cursorInSwiftUI

        buddyNavigationMode = .navigatingToTarget
        isReturningToCursor = true

        animateBezierFlightArc(to: cursorWithTrackingOffset) {
            self.finishNavigationAndResumeFollowing()
        }
    }

    /// Cancels an in-progress navigation because the user moved the cursor.
    private func cancelNavigationAndResumeFollowing() {
        navigationAnimationTimer?.invalidate()
        navigationAnimationTimer = nil
        navigationBubbleText = ""
        navigationBubbleOpacity = 0.0
        navigationBubbleScale = 1.0
        buddyFlightScale = 1.0
        buddyNavigationMode = .followingCursor
        isReturningToCursor = false
        triangleRotationDegrees = -35.0
        companionManager.pointingSequenceController.clear()
        sequenceReturnPosition = nil
        companionManager.tutorialPlaybackCoordinator.resumeAfterPointingIfNeeded()
    }

    /// Returns the buddy to normal cursor-following mode after navigation completes.
    private func finishNavigationAndResumeFollowing() {
        navigationAnimationTimer?.invalidate()
        navigationAnimationTimer = nil
        buddyNavigationMode = .followingCursor
        isReturningToCursor = false
        triangleRotationDegrees = -35.0
        buddyFlightScale = 1.0
        navigationBubbleText = ""
        navigationBubbleOpacity = 0.0
        navigationBubbleScale = 1.0
        if companionManager.pointingSequenceController.isManagedSequenceActive {
            companionManager.tutorialPlaybackCoordinator.resumeAfterPointingIfNeeded()
            return
        }

        companionManager.pointingSequenceController.advance()
        if !companionManager.pointingSequenceController.hasPendingTargets {
            sequenceReturnPosition = nil
        }
        companionManager.tutorialPlaybackCoordinator.resumeAfterPointingIfNeeded()
    }

    // MARK: - Welcome Animation

    private func startWelcomeAnimation() {
        withAnimation(.easeIn(duration: 0.4)) {
            self.bubbleOpacity = 1.0
        }

        var currentIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            guard currentIndex < self.fullWelcomeMessage.count else {
                timer.invalidate()
                // Hold the text for 2 seconds, then fade it out
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.bubbleOpacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self.showWelcome = false
                    // Start the onboarding video right after the welcome text disappears
                    self.companionManager.onboardingVideoController.setupVideo()
                }
                return
            }

            let index = self.fullWelcomeMessage.index(self.fullWelcomeMessage.startIndex, offsetBy: currentIndex)
            self.welcomeText.append(self.fullWelcomeMessage[index])
            currentIndex += 1
        }
    }
}
