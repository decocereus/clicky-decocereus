//
//  ClickyOnboardingMusicController.swift
//  leanring-buddy
//
//  Plays the short onboarding music bed and fades it out.
//

import AVFoundation
import Foundation

@MainActor
final class ClickyOnboardingMusicController {
    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?

    func start() {
        stop()

        guard let musicURL = Bundle.main.url(forResource: "ff", withExtension: "mp3") else {
            ClickyLogger.error(.ui, "Onboarding music asset ff.mp3 not found in bundle")
            return
        }

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: musicURL)
            audioPlayer.volume = 0.3
            audioPlayer.play()
            player = audioPlayer

            fadeTimer = Timer.scheduledTimer(withTimeInterval: 90.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.fadeOut()
                }
            }
        } catch {
            ClickyLogger.error(.ui, "Failed to play onboarding music error=\(error.localizedDescription)")
        }
    }

    func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        player?.stop()
        player = nil
    }

    private func fadeOut() {
        guard let fadingPlayer = player else { return }

        let fadeSteps = 30
        let fadeDuration: Double = 3.0
        let volumeDecrement = fadingPlayer.volume / Float(fadeSteps)
        let stepDurationNanoseconds = UInt64((fadeDuration / Double(fadeSteps)) * 1_000_000_000)

        fadeTimer?.invalidate()
        fadeTimer = nil

        Task { @MainActor [weak self] in
            guard let self else { return }

            for _ in 0..<fadeSteps {
                guard let currentPlayer = self.player, currentPlayer === fadingPlayer else {
                    return
                }

                currentPlayer.volume -= volumeDecrement
                try? await Task.sleep(nanoseconds: stepDurationNanoseconds)
            }

            guard let currentPlayer = self.player, currentPlayer === fadingPlayer else { return }
            currentPlayer.stop()
            self.player = nil
        }
    }
}
