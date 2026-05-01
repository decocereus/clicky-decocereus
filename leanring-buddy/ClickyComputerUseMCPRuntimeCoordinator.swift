//
//  ClickyComputerUseMCPRuntimeCoordinator.swift
//  leanring-buddy
//
//  Resolves the BackgroundComputerUse MCP server command without wrapping the
//  package's tool API.
//

import Foundation

struct ClickyComputerUseMCPServerDescriptor: Equatable, Sendable {
    let commandPath: String
    let arguments: [String]
    let workingDirectoryPath: String?
    let instructionResourceURI: String

    var assistantConfiguration: ClickyAssistantMCPServerConfiguration {
        ClickyAssistantMCPServerConfiguration(
            name: "background-computer-use",
            commandPath: commandPath,
            arguments: arguments,
            workingDirectoryPath: workingDirectoryPath,
            instructionResourceURI: instructionResourceURI
        )
    }
}

@MainActor
final class ClickyComputerUseMCPRuntimeCoordinator {
    private static let instructionResourceURI = "background-computer-use://instructions"
    private static let packageDirectoryName = "clicky-background-computer-use"
    private static let packageExecutableProductName = "BackgroundComputerUseMCP"
    private static let mcpProxyBundledExecutableName = "ClickyComputerUseMCPProxy"
    private static let mcpProxyScriptPath = "script/clicky_computer_use_mcp_proxy.swift"

    private let routingController: ClickyBackendRoutingController
    private let fileManager: FileManager
    private let bundle: Bundle

    init(
        routingController: ClickyBackendRoutingController,
        fileManager: FileManager = .default,
        bundle: Bundle = .main
    ) {
        self.routingController = routingController
        self.fileManager = fileManager
        self.bundle = bundle
    }

    var descriptor: ClickyComputerUseMCPServerDescriptor? {
        directDescriptor
    }

    var directDescriptor: ClickyComputerUseMCPServerDescriptor? {
        if let bundledHelperURL = bundledHelperExecutableURL(named: Self.packageExecutableProductName) {
            return ClickyComputerUseMCPServerDescriptor(
                commandPath: bundledHelperURL.path,
                arguments: [],
                workingDirectoryPath: nil,
                instructionResourceURI: Self.instructionResourceURI
            )
        }

        guard let packageDirectoryURL = developmentPackageDirectory(),
              fileManager.fileExists(atPath: packageDirectoryURL.appendingPathComponent("Package.swift").path) else {
            return nil
        }

        return ClickyComputerUseMCPServerDescriptor(
            commandPath: "/usr/bin/env",
            arguments: ["swift", "run", Self.packageExecutableProductName],
            workingDirectoryPath: packageDirectoryURL.path,
            instructionResourceURI: Self.instructionResourceURI
        )
    }

    var observeOnlyDescriptor: ClickyComputerUseMCPServerDescriptor? {
        guard let directDescriptor else {
            return nil
        }

        if let bundledProxyURL = bundledHelperExecutableURL(named: Self.mcpProxyBundledExecutableName) {
            return ClickyComputerUseMCPServerDescriptor(
                commandPath: bundledProxyURL.path,
                arguments: proxyArguments(for: directDescriptor, policy: .observeOnly),
                workingDirectoryPath: nil,
                instructionResourceURI: Self.instructionResourceURI
            )
        }

        guard let scriptURL = developmentMCPProxyScript(),
              fileManager.fileExists(atPath: scriptURL.path) else {
            return nil
        }

        return ClickyComputerUseMCPServerDescriptor(
            commandPath: "/usr/bin/env",
            arguments: ["swift", scriptURL.path] + proxyArguments(for: directDescriptor, policy: .observeOnly),
            workingDirectoryPath: clickyRepositoryDirectory()?.path,
            instructionResourceURI: Self.instructionResourceURI
        )
    }

    var reviewDescriptor: ClickyComputerUseMCPServerDescriptor? {
        guard let directDescriptor else {
            return nil
        }

        if let bundledProxyURL = bundledHelperExecutableURL(named: Self.mcpProxyBundledExecutableName) {
            return ClickyComputerUseMCPServerDescriptor(
                commandPath: bundledProxyURL.path,
                arguments: proxyArguments(for: directDescriptor, policy: .review),
                workingDirectoryPath: nil,
                instructionResourceURI: Self.instructionResourceURI
            )
        }

        guard let scriptURL = developmentMCPProxyScript(),
              fileManager.fileExists(atPath: scriptURL.path) else {
            return nil
        }

        return ClickyComputerUseMCPServerDescriptor(
            commandPath: "/usr/bin/env",
            arguments: ["swift", scriptURL.path] + proxyArguments(for: directDescriptor, policy: .review),
            workingDirectoryPath: clickyRepositoryDirectory()?.path,
            instructionResourceURI: Self.instructionResourceURI
        )
    }

    func descriptor(for permissionMode: ClickyComputerUsePermissionMode) -> ClickyComputerUseMCPServerDescriptor? {
        switch permissionMode {
        case .off:
            return nil
        case .observeOnly:
            return observeOnlyDescriptor
        case .review:
            return reviewDescriptor
        case .direct:
            return directDescriptor
        }
    }

    func refreshRuntimeStatus(permissionMode: ClickyComputerUsePermissionMode = .direct) {
        routingController.computerUseRuntimeStatus = .checking

        guard let descriptor = descriptor(for: permissionMode == .off ? .direct : permissionMode) else {
            clearResolvedDescriptor()
            routingController.computerUseRuntimeStatus = .failed(
                message: "BackgroundComputerUse MCP is not bundled and no sibling package checkout was found."
            )
            ClickyLogger.error(.agent, "Computer use MCP unavailable reason=descriptor-not-found")
            return
        }

        guard fileManager.isExecutableFile(atPath: descriptor.commandPath) else {
            clearResolvedDescriptor()
            routingController.computerUseRuntimeStatus = .failed(
                message: "BackgroundComputerUse MCP command is not executable at \(descriptor.commandPath)."
            )
            ClickyLogger.error(.agent, "Computer use MCP unavailable reason=command-not-executable path=\(descriptor.commandPath)")
            return
        }

        if let workingDirectoryPath = descriptor.workingDirectoryPath,
           !fileManager.fileExists(atPath: workingDirectoryPath) {
            clearResolvedDescriptor()
            routingController.computerUseRuntimeStatus = .failed(
                message: "BackgroundComputerUse MCP working directory is missing at \(workingDirectoryPath)."
            )
            ClickyLogger.error(.agent, "Computer use MCP unavailable reason=working-directory-missing path=\(workingDirectoryPath)")
            return
        }

        routingController.computerUseMCPCommandPath = descriptor.commandPath
        routingController.computerUseMCPArguments = descriptor.arguments
        routingController.computerUseMCPWorkingDirectoryPath = descriptor.workingDirectoryPath
        routingController.computerUseMCPInstructionResourceURI = descriptor.instructionResourceURI

        let launchLabel = ([descriptor.commandPath] + descriptor.arguments).joined(separator: " ")
        routingController.computerUseRuntimeStatus = .ready(
            summary: "BackgroundComputerUse MCP is available via \(launchLabel)."
        )
        ClickyLogger.notice(.agent, "Computer use MCP ready command=\(launchLabel)")
    }

    private func clearResolvedDescriptor() {
        routingController.computerUseMCPCommandPath = nil
        routingController.computerUseMCPArguments = []
        routingController.computerUseMCPWorkingDirectoryPath = nil
        routingController.computerUseMCPInstructionResourceURI = nil
    }

    private func developmentPackageDirectory() -> URL? {
        let currentSourceURL = URL(fileURLWithPath: #filePath)
        let clickyRepositoryURL = currentSourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectsDirectoryURL = clickyRepositoryURL.deletingLastPathComponent()
        let packageDirectoryURL = projectsDirectoryURL.appendingPathComponent(Self.packageDirectoryName, isDirectory: true)

        guard fileManager.fileExists(atPath: packageDirectoryURL.path) else {
            return nil
        }

        return packageDirectoryURL
    }

    private func bundledHelperExecutableURL(named name: String) -> URL? {
        if let auxiliaryExecutableURL = bundle.url(forAuxiliaryExecutable: name) {
            return auxiliaryExecutableURL
        }

        let helpersURL = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent(name)

        guard fileManager.isExecutableFile(atPath: helpersURL.path) else {
            return nil
        }

        return helpersURL
    }

    private func developmentMCPProxyScript() -> URL? {
        clickyRepositoryDirectory()?.appendingPathComponent(Self.mcpProxyScriptPath)
    }

    private func clickyRepositoryDirectory() -> URL? {
        let currentSourceURL = URL(fileURLWithPath: #filePath)
        return currentSourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func proxyArguments(
        for directDescriptor: ClickyComputerUseMCPServerDescriptor,
        policy: ClickyComputerUsePermissionMode
    ) -> [String] {
        var arguments = [
            "--policy",
            policy == .review ? "review" : "observe",
            "--server-command",
            directDescriptor.commandPath
        ]

        if policy == .review {
            arguments.append(contentsOf: [
                "--review-dir",
                ClickyComputerUseReviewCoordinator.reviewDirectoryURL(fileManager: fileManager).path
            ])
        }

        if let workingDirectoryPath = directDescriptor.workingDirectoryPath {
            arguments.append(contentsOf: ["--server-cwd", workingDirectoryPath])
        }

        for argument in directDescriptor.arguments {
            arguments.append(contentsOf: ["--server-arg", argument])
        }

        return arguments
    }
}
