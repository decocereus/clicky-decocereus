//
//  OverlayIndicators.swift
//  leanring-buddy
//
//  Cursor overlay waveform, spinner, halo, and pulsing-orb indicators.
//

import SwiftUI

// MARK: - Blue Cursor Waveform

/// A small blue waveform that replaces the triangle cursor while
/// the user is holding the push-to-talk shortcut and speaking.
struct BlueCursorWaveformView: View {
    let audioPowerLevel: CGFloat
    let accentColor: Color
    let secondaryColor: Color

    private let barCount = 5
    private let listeningBarProfile: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 36.0)) { timelineContext in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { barIndex in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(barFill(for: barIndex))
                        .frame(
                            width: 2,
                            height: barHeight(
                                for: barIndex,
                                timelineDate: timelineContext.date
                            )
                        )
                }
            }
            .shadow(color: secondaryColor.opacity(0.45), radius: 6, x: 0, y: 0)
            .animation(.linear(duration: 0.08), value: audioPowerLevel)
        }
    }

    private func barFill(for barIndex: Int) -> LinearGradient {
        let isCenterBar = barIndex == 2
        return LinearGradient(
            colors: isCenterBar ? [accentColor, secondaryColor.opacity(0.88)] : [accentColor.opacity(0.92), secondaryColor.opacity(0.62)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func barHeight(for barIndex: Int, timelineDate: Date) -> CGFloat {
        let animationPhase = CGFloat(timelineDate.timeIntervalSinceReferenceDate * 3.6) + CGFloat(barIndex) * 0.35
        let normalizedAudioPowerLevel = max(audioPowerLevel - 0.008, 0)
        let easedAudioPowerLevel = pow(min(normalizedAudioPowerLevel * 2.85, 1), 0.76)
        let reactiveHeight = easedAudioPowerLevel * 10 * listeningBarProfile[barIndex]
        let idlePulse = (sin(animationPhase) + 1) / 2 * 1.5
        return 3 + reactiveHeight + idlePulse
    }
}

// MARK: - Blue Cursor Thinking

/// A pulsing three-dot indicator used once the user's speech has been
/// transcribed and the assistant is now thinking about the reply.
struct BlueCursorThinkingView: View {
    let accentColor: Color
    let secondaryColor: Color
    private let dotCount = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timelineContext in
            HStack(spacing: 3) {
                ForEach(0..<dotCount, id: \.self) { dotIndex in
                    Circle()
                        .fill(dotColor(for: dotIndex))
                        .frame(width: 4, height: 4)
                        .scaleEffect(dotScale(for: dotIndex, timelineDate: timelineContext.date))
                        .opacity(dotOpacity(for: dotIndex, timelineDate: timelineContext.date))
                }
            }
            .shadow(color: secondaryColor.opacity(0.45), radius: 6, x: 0, y: 0)
        }
    }

    private func dotColor(for dotIndex: Int) -> Color {
        dotIndex == 1 ? accentColor : secondaryColor.opacity(0.88)
    }

    private func dotScale(for dotIndex: Int, timelineDate: Date) -> CGFloat {
        let animationPhase = CGFloat(timelineDate.timeIntervalSinceReferenceDate * 3.0) + CGFloat(dotIndex) * 0.45
        return 0.75 + ((sin(animationPhase) + 1) / 2) * 0.6
    }

    private func dotOpacity(for dotIndex: Int, timelineDate: Date) -> Double {
        let animationPhase = CGFloat(timelineDate.timeIntervalSinceReferenceDate * 3.0) + CGFloat(dotIndex) * 0.45
        return 0.35 + Double((sin(animationPhase) + 1) / 2) * 0.65
    }
}

// MARK: - Blue Cursor Speaking

/// A non-reactive waveform used while the assistant is speaking so the
/// user can see the response is actively being read aloud.
struct BlueCursorSpeakingWaveformView: View {
    let accentColor: Color
    let secondaryColor: Color
    private let barCount = 5
    private let speakingBarProfile: [CGFloat] = [0.55, 0.85, 1.0, 0.85, 0.55]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timelineContext in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { barIndex in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(barFill(for: barIndex))
                        .frame(
                            width: 2,
                            height: barHeight(for: barIndex, timelineDate: timelineContext.date)
                        )
                }
            }
            .shadow(color: secondaryColor.opacity(0.45), radius: 6, x: 0, y: 0)
        }
    }

    private func barFill(for barIndex: Int) -> LinearGradient {
        let intensity = speakingBarProfile[barIndex]
        return LinearGradient(
            colors: [
                accentColor.opacity(0.78 + (0.18 * intensity)),
                secondaryColor.opacity(0.55 + (0.20 * intensity))
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func barHeight(for barIndex: Int, timelineDate: Date) -> CGFloat {
        let animationPhase = CGFloat(timelineDate.timeIntervalSinceReferenceDate * 4.8) + CGFloat(barIndex) * 0.55
        let speakingPulse = (sin(animationPhase) + 1) / 2
        return 4 + speakingPulse * 9 * speakingBarProfile[barIndex]
    }
}

// MARK: - Blue Cursor Spinner

/// A small blue spinning indicator that replaces the triangle cursor
/// while the AI is processing a voice input.
struct BlueCursorSpinnerView: View {
    let accentColor: Color
    let secondaryColor: Color
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0.15, to: 0.85)
            .stroke(
                AngularGradient(
                    colors: [
                        secondaryColor.opacity(0.0),
                        secondaryColor,
                        accentColor
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .shadow(color: secondaryColor.opacity(0.45), radius: 6, x: 0, y: 0)
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            }
    }
}

struct HaloActivityIndicatorView: View {
    let accentColor: Color
    let secondaryColor: Color
    let activityLevel: CGFloat
    let isExpanded: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(secondaryColor.opacity(0.22), lineWidth: 1.2)
                .frame(width: 24, height: 24)
                .scaleEffect(isExpanded ? 1.12 : 0.96)

            Circle()
                .trim(from: 0.18, to: 0.82)
                .stroke(secondaryColor.opacity(0.75), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
                .frame(width: 18 + activityLevel * 5, height: 18 + activityLevel * 5)
                .rotationEffect(.degrees(isExpanded ? 180 : 20))

            Circle()
                .fill(accentColor)
                .frame(width: 5, height: 5)
        }
        .shadow(color: secondaryColor.opacity(0.30), radius: 8, x: 0, y: 0)
    }
}

struct HaloSpinnerIndicatorView: View {
    let accentColor: Color
    let secondaryColor: Color
    let isExpanded: Bool
    @State private var isRotating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(secondaryColor.opacity(0.18), lineWidth: 1.0)
                .frame(width: 24, height: 24)
                .scaleEffect(isExpanded ? 1.08 : 0.96)

            Circle()
                .trim(from: 0.12, to: 0.56)
                .stroke(
                    AngularGradient(colors: [secondaryColor, accentColor], center: .center),
                    style: StrokeStyle(lineWidth: 2.1, lineCap: .round)
                )
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
        }
        .shadow(color: secondaryColor.opacity(0.30), radius: 8, x: 0, y: 0)
        .onAppear {
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
    }
}

struct HaloThinkingIndicatorView: View {
    let accentColor: Color
    let secondaryColor: Color
    let isExpanded: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(secondaryColor.opacity(0.20), lineWidth: 1.0)
                .frame(width: 24, height: 24)
                .scaleEffect(isExpanded ? 1.1 : 0.95)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == 1 ? accentColor : secondaryColor.opacity(0.85))
                        .frame(width: 3.5, height: 3.5)
                        .opacity(index == 1 ? 1.0 : 0.55)
                }
            }
        }
        .shadow(color: secondaryColor.opacity(0.28), radius: 8, x: 0, y: 0)
    }
}

struct HaloSpeakingIndicatorView: View {
    let accentColor: Color
    let secondaryColor: Color
    let isExpanded: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(secondaryColor.opacity(0.18), lineWidth: 1.0)
                .frame(width: 24, height: 24)
                .scaleEffect(isExpanded ? 1.08 : 0.96)

            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.4, style: .continuous)
                        .fill(index == 1 ? accentColor : secondaryColor.opacity(0.82))
                        .frame(width: 2.6, height: index == 1 ? 11 : 7)
                }
            }
        }
        .shadow(color: secondaryColor.opacity(0.30), radius: 8, x: 0, y: 0)
    }
}

enum PulsingOrbMode {
    case listening
    case transcribing
    case thinking
    case responding
}

struct PulsingOrbIndicatorView: View {
    let accentColor: Color
    let secondaryColor: Color
    let activityLevel: CGFloat
    let mode: PulsingOrbMode
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(secondaryColor.opacity(0.18))
                .frame(width: 26, height: 26)
                .scaleEffect(isExpanded ? 1.28 : 0.92)
                .opacity(isExpanded ? 0.16 : 0.42)

            Circle()
                .fill(coreFill)
                .frame(width: 14 + activityLevel * 4, height: 14 + activityLevel * 4)

            if mode == .responding || mode == .listening {
                Circle()
                    .stroke(secondaryColor.opacity(0.55), lineWidth: 1.4)
                    .frame(width: 20, height: 20)
                    .scaleEffect(isExpanded ? 1.16 : 0.95)
            }
        }
        .shadow(color: secondaryColor.opacity(0.34), radius: 10, x: 0, y: 0)
        .onAppear {
            withAnimation(.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
                isExpanded = true
            }
        }
    }

    private var animationDuration: Double {
        switch mode {
        case .listening:
            return 0.62
        case .transcribing:
            return 0.82
        case .thinking:
            return 1.0
        case .responding:
            return 0.58
        }
    }

    private var coreFill: Color {
        switch mode {
        case .listening:
            return accentColor
        case .transcribing:
            return secondaryColor.opacity(0.90)
        case .thinking:
            return secondaryColor.opacity(0.82)
        case .responding:
            return accentColor
        }
    }
}
