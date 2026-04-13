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
}
