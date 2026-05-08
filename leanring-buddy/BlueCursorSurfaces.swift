//
//  BlueCursorSurfaces.swift
//  leanring-buddy
//
//  Reusable bubble and media surfaces for the cursor overlay.
//

import AppKit
import AVFoundation
import SwiftUI

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let height = size * sqrt(3.0) / 2.0

        path.move(to: CGPoint(x: rect.midX, y: rect.midY - height / 1.5))
        path.addLine(to: CGPoint(x: rect.midX - size / 2, y: rect.midY + height / 3))
        path.addLine(to: CGPoint(x: rect.midX + size / 2, y: rect.midY + height / 3))
        path.closeSubpath()
        return path
    }
}

struct BlueCursorBubbleSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct BlueCursorNavigationBubbleSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct BlueCursorSpeechBubble: View {
    let text: String
    let accentColor: Color
    let shadowOpacity: Double
    let shadowRadius: CGFloat

    init(
        text: String,
        accentColor: Color,
        shadowOpacity: Double = 0.5,
        shadowRadius: CGFloat = 6
    ) {
        self.text = text
        self.accentColor = accentColor
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(accentColor)
                    .shadow(color: accentColor.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: 0)
            )
            .fixedSize()
    }
}

struct BlueCursorMeasuredSpeechBubble: View {
    let text: String
    let accentColor: Color

    var body: some View {
        BlueCursorSpeechBubble(text: text, accentColor: accentColor)
            .overlay(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: BlueCursorBubbleSizePreferenceKey.self, value: geometry.size)
                }
            )
    }
}

struct BlueCursorMeasuredNavigationBubble: View {
    let text: String
    let accentColor: Color
    let scale: CGFloat

    var body: some View {
        BlueCursorSpeechBubble(
            text: text,
            accentColor: accentColor,
            shadowOpacity: 0.5 + (1.0 - scale) * 1.0,
            shadowRadius: 6 + (1.0 - scale) * 16
        )
        .overlay(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: BlueCursorNavigationBubbleSizePreferenceKey.self, value: geometry.size)
            }
        )
    }
}

struct BlueCursorOnboardingVideoSurface: View {
    let player: AVPlayer?
    let opacity: Double
    let cursorPosition: CGPoint
    let isCursorOnThisScreen: Bool

    private let width: CGFloat = 330
    private let height: CGFloat = 186

    var body: some View {
        OnboardingVideoPlayerView(player: player)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.4 * opacity), radius: 12, x: 0, y: 6)
            .opacity(isCursorOnThisScreen ? opacity : 0)
            .position(
                x: cursorPosition.x + 10 + (width / 2),
                y: cursorPosition.y + 18 + (height / 2)
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
            .animation(.easeInOut(duration: 2.0), value: opacity)
            .allowsHitTesting(false)
    }
}

struct BlueCursorTutorialInlinePlayerSurface: View {
    @ObservedObject var tutorialController: ClickyTutorialController

    let cursorPosition: CGPoint
    let isCursorOnThisScreen: Bool
    let accentColor: Color
    @Binding var bubbleSize: CGSize

    var body: some View {
        if isCursorOnThisScreen,
           let tutorialPlaybackState = tutorialController.tutorialPlaybackState,
           tutorialPlaybackState.isVisible {
            TutorialInlineYouTubePlayerView(
                embedURL: tutorialPlaybackState.embedURL,
                isPlaying: tutorialPlaybackState.isPlaying,
                commandNonce: tutorialController.tutorialPlaybackCommandNonce,
                lastCommand: tutorialController.tutorialPlaybackLastCommand,
                startAtSeconds: tutorialPlaybackState.lastPromptTimestampSeconds
            )
            .frame(
                width: tutorialPlaybackState.preferredInlinePlayerWidth,
                height: tutorialPlaybackState.preferredInlinePlayerHeight
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
            .position(
                x: cursorPosition.x + 10 + (tutorialPlaybackState.preferredInlinePlayerWidth / 2),
                y: cursorPosition.y + 18 + (tutorialPlaybackState.preferredInlinePlayerHeight / 2)
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
            .allowsHitTesting(false)
            .opacity(tutorialPlaybackState.surfaceMode == .pointerGuidance ? 0.92 : 1.0)

            if tutorialPlaybackState.surfaceMode == .inlineVideoWithBubble,
               let bubbleText = tutorialPlaybackState.bubbleText,
               !bubbleText.isEmpty {
                BlueCursorMeasuredSpeechBubble(text: bubbleText, accentColor: accentColor)
                    .opacity(tutorialController.tutorialPlaybackBubbleOpacity)
                    .position(
                        x: cursorPosition.x + 10 + (bubbleSize.width / 2),
                        y: cursorPosition.y + 18 - (bubbleSize.height / 2) - 12
                    )
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.easeOut(duration: 0.2), value: tutorialController.tutorialPlaybackBubbleOpacity)
                    .onPreferenceChange(BlueCursorBubbleSizePreferenceKey.self) { newSize in
                        bubbleSize = newSize
                    }
            }
        }
    }
}
