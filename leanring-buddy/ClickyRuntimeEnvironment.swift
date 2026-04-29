//
//  ClickyRuntimeEnvironment.swift
//  leanring-buddy
//
//  Centralizes process-level runtime checks that affect app startup.
//

import Foundation

enum ClickyRuntimeEnvironment {
    static var isRunningAppHostedUnitTests: Bool {
        isRunningAppHostedUnitTests(
            environment: ProcessInfo.processInfo.environment,
            arguments: ProcessInfo.processInfo.arguments
        )
    }

    static func isRunningAppHostedUnitTests(
        environment: [String: String],
        arguments: [String]
    ) -> Bool {
        if environment["XCTestConfigurationFilePath"] != nil {
            return true
        }

        if environment["XCTestSessionIdentifier"] != nil {
            return true
        }

        return arguments.contains { argument in
            let normalizedArgument = argument.lowercased()
            return normalizedArgument.hasSuffix(".xctest") || normalizedArgument.contains("xctest")
        }
    }
}
