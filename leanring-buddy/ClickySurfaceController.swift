//
//  ClickySurfaceController.swift
//  leanring-buddy
//
//  Observable live surface state for the panel and cursor overlay.
//

@preconcurrency import AVFoundation
import Combine
import Foundation

@MainActor
final class ClickySurfaceController: ObservableObject {
    @Published var voiceState: CompanionVoiceState = .idle
    @Published var lastTranscript: String?
    @Published var currentAudioPowerLevel: CGFloat = 0
    @Published var hasAccessibilityPermission = false
    @Published var hasScreenRecordingPermission = false
    @Published var hasMicrophonePermission = false
    @Published var hasScreenContentPermission = false
    @Published var detectedElementScreenLocation: CGPoint?
    @Published var detectedElementDisplayFrame: CGRect?
    @Published var detectedElementBubbleText: String?
    @Published var managedPointSequenceReturnToken: Int = 0
    @Published var onboardingVideoPlayer: AVPlayer?
    @Published var showOnboardingVideo: Bool = false
    @Published var onboardingVideoOpacity: Double = 0.0
    @Published var onboardingPromptText: String = ""
    @Published var onboardingPromptOpacity: Double = 0.0
    @Published var showOnboardingPrompt: Bool = false
    @Published var isOverlayVisible: Bool = false
}
