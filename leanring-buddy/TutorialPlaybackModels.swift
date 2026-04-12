//
//  TutorialPlaybackModels.swift
//  leanring-buddy
//
//  Shared tutorial playback state for the cursor companion.
//

import Foundation

enum TutorialPlaybackSurfaceMode: String, Codable, Sendable {
    case hidden
    case inlineVideo
    case inlineVideoWithBubble
    case pointerGuidance
}

enum TutorialPlaybackResumeBehavior: String, Codable, Sendable {
    case resumeInlineVideoAfterPointing
    case stayHiddenAfterPointing
}

struct TutorialPlaybackBindingState: Codable, Sendable {
    var sourceURL: String
    var embedURL: String
    var currentStepID: UUID?
    var currentStepTitle: String?
    var bubbleText: String?
    var isPlaying: Bool
    var isVisible: Bool
    var surfaceMode: TutorialPlaybackSurfaceMode
    var resumeBehavior: TutorialPlaybackResumeBehavior
    var preferredInlinePlayerWidth: Double
    var preferredInlinePlayerHeight: Double
    var lastPromptTimestampSeconds: Int?
    var showsKeyboardShortcutsHint: Bool

    init(
        sourceURL: String,
        embedURL: String,
        currentStepID: UUID? = nil,
        currentStepTitle: String? = nil,
        bubbleText: String? = nil,
        isPlaying: Bool = false,
        isVisible: Bool = false,
        surfaceMode: TutorialPlaybackSurfaceMode = .hidden,
        resumeBehavior: TutorialPlaybackResumeBehavior = .resumeInlineVideoAfterPointing,
        preferredInlinePlayerWidth: Double = 330,
        preferredInlinePlayerHeight: Double = 186,
        lastPromptTimestampSeconds: Int? = nil,
        showsKeyboardShortcutsHint: Bool = true
    ) {
        self.sourceURL = sourceURL
        self.embedURL = embedURL
        self.currentStepID = currentStepID
        self.currentStepTitle = currentStepTitle
        self.bubbleText = bubbleText
        self.isPlaying = isPlaying
        self.isVisible = isVisible
        self.surfaceMode = surfaceMode
        self.resumeBehavior = resumeBehavior
        self.preferredInlinePlayerWidth = preferredInlinePlayerWidth
        self.preferredInlinePlayerHeight = preferredInlinePlayerHeight
        self.lastPromptTimestampSeconds = lastPromptTimestampSeconds
        self.showsKeyboardShortcutsHint = showsKeyboardShortcutsHint
    }
}

struct TutorialPlaybackKeyboardBindings: Codable, Sendable {
    var playPause: String
    var seekBackward: String
    var seekForward: String
    var dismiss: String

    static let `default` = TutorialPlaybackKeyboardBindings(
        playPause: "space",
        seekBackward: "leftArrow",
        seekForward: "rightArrow",
        dismiss: "escape"
    )
}

enum TutorialPlaybackCommand: String, Sendable {
    case play
    case pause
    case togglePlayPause
    case seekBackward
    case seekForward
    case dismiss
}
