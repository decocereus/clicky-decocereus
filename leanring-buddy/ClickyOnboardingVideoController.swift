//
//  ClickyOnboardingVideoController.swift
//  leanring-buddy
//
//  Owns first-run onboarding video playback and prompt streaming.
//

@preconcurrency import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class ClickyOnboardingVideoController {
    private let surfaceController: ClickySurfaceController
    private let performDemoInteraction: @MainActor () -> Void

    private var videoEndObserver: NSObjectProtocol?
    private var demoTimeObserver: Any?
    private var promptTask: Task<Void, Never>?

    init(
        surfaceController: ClickySurfaceController,
        performDemoInteraction: @escaping @MainActor () -> Void
    ) {
        self.surfaceController = surfaceController
        self.performDemoInteraction = performDemoInteraction
    }

    func setupVideo() {
        guard let videoURL = URL(string: "https://stream.mux.com/e5jB8UuSrtFABVnTHCR7k3sIsmcUHCyhtLu1tzqLlfs.m3u8") else { return }

        let player = AVPlayer(url: videoURL)
        player.isMuted = false
        player.volume = 0.0
        surfaceController.onboardingVideoPlayer = player
        surfaceController.showOnboardingVideo = true
        surfaceController.onboardingVideoOpacity = 0.0

        player.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            surfaceController.onboardingVideoOpacity = 1.0
            fadeInVideoAudio(player: player, targetVolume: 1.0, duration: 2.0)
        }

        let demoTriggerTime = CMTime(seconds: 40, preferredTimescale: 600)
        demoTimeObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: demoTriggerTime)],
            queue: .main
        ) { [weak self] in
            Task { @MainActor [weak self] in
                ClickyAnalytics.trackOnboardingDemoTriggered()
                self?.performDemoInteraction()
            }
        }

        videoEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                ClickyAnalytics.trackOnboardingVideoCompleted()
                surfaceController.onboardingVideoOpacity = 0.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self else { return }
                    tearDownVideo()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.startPromptStream()
                    }
                }
            }
        }
    }

    func tearDownVideo() {
        surfaceController.showOnboardingVideo = false
        if let timeObserver = demoTimeObserver {
            surfaceController.onboardingVideoPlayer?.removeTimeObserver(timeObserver)
            demoTimeObserver = nil
        }
        surfaceController.onboardingVideoPlayer?.pause()
        surfaceController.onboardingVideoPlayer = nil
        if let observer = videoEndObserver {
            NotificationCenter.default.removeObserver(observer)
            videoEndObserver = nil
        }
    }

    private func startPromptStream() {
        let message = "press control + option and introduce yourself"
        promptTask?.cancel()
        surfaceController.onboardingPromptText = ""
        surfaceController.showOnboardingPrompt = true
        surfaceController.onboardingPromptOpacity = 0.0

        withAnimation(.easeIn(duration: 0.4)) {
            surfaceController.onboardingPromptOpacity = 1.0
        }

        promptTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for character in message {
                surfaceController.onboardingPromptText.append(character)
                try? await Task.sleep(nanoseconds: 30_000_000)
            }

            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard self.surfaceController.showOnboardingPrompt else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                self.surfaceController.onboardingPromptOpacity = 0.0
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            self.surfaceController.showOnboardingPrompt = false
            self.surfaceController.onboardingPromptText = ""
            self.promptTask = nil
        }
    }

    private func fadeInVideoAudio(player: AVPlayer, targetVolume: Float, duration: Double) {
        let steps = 20
        let stepInterval = duration / Double(steps)
        let volumeIncrement = (targetVolume - player.volume) / Float(steps)
        var stepsRemaining = steps

        Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { timer in
            stepsRemaining -= 1
            player.volume += volumeIncrement

            if stepsRemaining <= 0 {
                timer.invalidate()
                player.volume = targetVolume
            }
        }
    }
}
