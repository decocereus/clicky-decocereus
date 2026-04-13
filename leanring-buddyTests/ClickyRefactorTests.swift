//
//  ClickyRefactorTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct ClickyRefactorTests {
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
    func launchAuthPendingTracksLaunchAccessControllerState() {
        let manager = CompanionManager()

        manager.launchAccessController.clickyLaunchAuthState = .restoring
        #expect(manager.isClickyLaunchAuthPending)

        manager.launchAccessController.clickyLaunchAuthState = .signingIn
        #expect(manager.isClickyLaunchAuthPending)

        manager.launchAccessController.clickyLaunchAuthState = .failed(message: "Oops")
        #expect(!manager.isClickyLaunchAuthPending)
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
}
