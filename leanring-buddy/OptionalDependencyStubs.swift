//
//  OptionalDependencyStubs.swift
//  leanring-buddy
//
//  Local no-op replacements for optional vendor dependencies so the app
//  can build even when Sparkle or PostHog packages are unavailable.
//

import Foundation

struct PostHogConfig {
    let apiKey: String
    let host: String
}

final class PostHogSDK {
    static let shared = PostHogSDK()

    private init() {}

    func setup(_ config: PostHogConfig) {
        _ = config
    }

    func capture(_ event: String, properties: [String: Any]? = nil) {
        _ = event
        _ = properties
    }

    func identify(_ distinctId: String, userProperties: [String: Any]? = nil) {
        _ = distinctId
        _ = userProperties
    }
}

final class SPUUpdater {
    func start() throws {}
}

final class SPUStandardUpdaterController {
    let updater = SPUUpdater()

    init(
        startingUpdater: Bool,
        updaterDelegate: Any?,
        userDriverDelegate: Any?
    ) {
        _ = startingUpdater
        _ = updaterDelegate
        _ = userDriverDelegate
    }
}
