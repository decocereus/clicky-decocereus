//
//  ClickyComputerUseContractTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct ClickyComputerUseContractTests {
    private let runtimeToolNames = [
        "list_apps",
        "list_windows",
        "get_window_state",
        "click",
        "type_text",
        "press_key",
        "scroll",
        "set_value",
        "perform_secondary_action",
        "drag",
        "resize",
        "set_window_frame",
    ]

    @Test
    func pluginManifestExposesOnlyRuntimeNamedComputerUseTools() throws {
        let manifest = try readRepositoryFile("plugins/openclaw-clicky-shell/openclaw.plugin.json")
        let data = try #require(manifest.data(using: .utf8))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let contracts = try #require(object["contracts"] as? [String: Any])
        let tools = try #require(contracts["tools"] as? [String])

        #expect(tools.contains("clicky_status"))
        #expect(tools.contains("clicky_present"))
        for toolName in runtimeToolNames {
            #expect(tools.contains(toolName), "Missing \(toolName)")
        }

        #expect(!tools.contains("clicky_request_computer_use"))
        #expect(!tools.contains("clicky_locate"))
        #expect(!tools.contains("clicky_locate_many"))
        #expect(!tools.contains(where: { $0.hasPrefix("clicky_") && $0 != "clicky_status" && $0 != "clicky_present" }))
    }

    @Test
    func pluginSourceDoesNotAcceptOldComputerUseEnvelope() throws {
        let source = try readRepositoryFile("plugins/openclaw-clicky-shell/index.ts")

        #expect(!source.contains("clicky_request_computer_use"))
        #expect(!source.contains("computerUseAction"))
        #expect(!source.contains("clicky_locate"))
        #expect(!source.contains("clicky_locate_many"))
        #expect(source.contains("clicky.shell.next_computer_use_action"))
        #expect(source.contains("clicky.shell.complete_computer_use_action"))
    }

    @Test
    func pluginPromptTeachesObserveActObserveInsteadOfAppSpecificRecipes() throws {
        let source = try readRepositoryFile("plugins/openclaw-clicky-shell/index.ts")
        let agentSource = try readRepositoryFile("leanring-buddy/OpenClawGatewayCompanionAgent.swift")

        #expect(source.contains("observe-act-observe"))
        #expect(source.contains("get_window_state before meaningful UI actions"))
        #expect(source.contains("do not pass frontmost, current, active, or a visible title"))
        #expect(source.contains("Clicky does not perform semantic target scoring"))
        #expect(source.contains("do not use generic shell/process/exec/osascript/browser automation"))
        #expect(source.contains("verify the result with get_window_state before using clicky_present"))
        #expect(agentSource.contains(#""execSecurity": "deny""#))
        #expect(agentSource.contains(#""execAsk": "always""#))
        #expect(source.contains("prependSystemContext: context"))
        #expect(!source.contains("ctx.systemMessages.push"))
        #expect(!source.contains("Post button in X left sidebar"))
        #expect(!source.contains("tweet composer text box"))
    }

    @Test
    func runtimeRouteForwarderCoversEveryModelFacingRoute() throws {
        let source = try readRepositoryFile("leanring-buddy/CompanionManager.swift")

        for route in runtimeToolNames {
            #expect(source.contains("case \"\(route)\""), "Missing Swift forwarding case for \(route)")
        }
        #expect(source.contains("preparedComputerUsePayload(route: route, payload: payload)"))
        #expect(source.contains("validateOpenClawComputerUsePayload(route: route, payload: payload)"))
        #expect(source.contains("body[\"imageMode\"] = \"path\""))
        #expect(source.contains("preparedCompactObservationPayload"))
        #expect(source.contains("body[\"includeMenuBar\"] = false"))
        #expect(!source.contains("clicky-operator"))
        #expect(source.contains("executeOpenClawComputerUseToolRequest"))
    }

    @Test
    func openClawComputerUseSessionsCancelOnEveryExitPath() throws {
        let source = try readRepositoryFile("leanring-buddy/OpenClawGatewayCompanionAgent.swift")

        #expect(source.contains("_ = try await connect()\n            defer { cancel() }"))
        #expect(source.contains("if waitStatus == \"timeout\""))
        #expect(source.contains("throw NSError(\n                        domain: \"OpenClawGatewayCompanionAgent\""))
    }

    @Test
    func computerUseCursorStatusIsDebouncedAcrossToolLoops() throws {
        let source = try readRepositoryFile("leanring-buddy/CompanionManager.swift")

        #expect(source.contains("minimumComputerUseStatusDisplayInterval"))
        #expect(source.contains("computerUseActivityFinishTask"))
        #expect(source.contains("lastComputerUseStatusText == trimmedStatusText"))
        #expect(source.contains("now.timeIntervalSince(lastComputerUseStatusUpdatedAt) < minimumComputerUseStatusDisplayInterval"))
        #expect(source.contains("try? await Task.sleep(for: .milliseconds(900))"))
    }

    @Test
    func pluginUsesRouteSpecificComputerUseSchemas() throws {
        let source = try readRepositoryFile("plugins/openclaw-clicky-shell/index.ts")

        #expect(source.contains("function runtimeToolParameters(route: ComputerUseRoute)"))
        #expect(source.contains("parameters: runtimeToolParameters(route)"))
        #expect(source.contains("formatToolResult(route, result)"))
        #expect(source.contains("return JSON.stringify(compact, null, 2)"))
        #expect(!source.contains("Use this JSON as the source of truth"))
        #expect(!source.contains("Clicky computer-use result for"))
        #expect(source.contains("rememberCompletionProof(shell, route, result, ctx?.sessionKey)"))
        #expect(source.contains("validatePresentationAgainstCompletionProof(params, ctx?.sessionKey, shell)"))
        #expect(source.contains("clicky_present cannot claim completion yet"))
        #expect(source.contains("if (!hasString(payload, \"app\")) return missing(\"app\")"))
        #expect(source.contains("List live windows for an app name, bundle ID, or app identifier from list_apps."))
        #expect(source.contains("additionalProperties: false"))
        #expect(source.contains("const actionTargetParameter"))
        #expect(source.contains("enum: [\"display_index\", \"node_id\", \"refetch_fingerprint\"]"))
        #expect(source.contains("function validatePayload(route: ComputerUseRoute, params: unknown)"))
        #expect(source.contains("provide target, or provide both x and y"))
        #expect(source.contains("actionSchema([\"window\", \"target\", \"direction\"]"))
        #expect(source.contains("actionSchema([\"window\", \"target\", \"value\"]"))
        #expect(source.contains("if (!hasTarget(payload, \"target\")) return missing(\"target\")"))
        #expect(!source.contains("if (!hasInteger(payload, \"elementIndex\")) return missing(\"elementIndex\")"))
        #expect(source.contains("Defaults to path"))
        #expect(source.contains("sanitizeToolResultForModel(result)"))
        #expect(source.contains("compactToolResultForModel(route, result)"))
        #expect(source.contains("normalizeComputerUsePayloadForModel(route, payload)"))
        #expect(source.contains("structuredContent: sanitizedResult"))
        #expect(!source.contains("function screenshotDataUrl(result: Record<string, unknown>)"))
        #expect(!source.contains("content.push({ type: \"image\", url: screenshotUrl })"))
        #expect(!source.contains("additionalProperties: true,\n  properties: {\n    app: { type: \"string\" }"))
    }

    @Test
    func openClawComputerUseDebugTraceCapturesTheFullLoop() throws {
        let traceSource = try readRepositoryFile("leanring-buddy/ClickyComputerUseDebugTrace.swift")
        let managerSource = try readRepositoryFile("leanring-buddy/CompanionManager.swift")
        let providerSource = try readRepositoryFile("leanring-buddy/OpenClawAssistantProvider.swift")
        let gatewaySource = try readRepositoryFile("leanring-buddy/OpenClawGatewayCompanionAgent.swift")

        #expect(traceSource.contains("ComputerUseTraces"))
        #expect(traceSource.contains("initial-turn.json"))
        #expect(traceSource.contains("openclaw-dispatch.json"))
        #expect(traceSource.contains("trace.jsonl"))
        #expect(traceSource.contains("screenshots"))
        #expect(traceSource.contains("beginToolStep"))
        #expect(traceSource.contains("finishToolStep"))
        #expect(managerSource.contains("ClickyComputerUseDebugTrace.shared.startRun"))
        #expect(managerSource.contains("ClickyComputerUseDebugTrace.shared.beginToolStep"))
        #expect(managerSource.contains("ClickyComputerUseDebugTrace.shared.finishToolStep"))
        #expect(providerSource.contains("recordOpenClawDispatch"))
        #expect(gatewaySource.contains("recordOpenClawFrame"))
    }

    @Test
    func typeTextUsesTypingSemanticsAndRejectsStaleTargets() throws {
        let source = try readRepositoryFile("Packages/BackgroundComputerUse/Sources/BackgroundComputerUse/Actions/TypeText/TypeTextRouteService.swift")

        #expect(source.contains("Supplied stateToken did not match the live pre-action recapture; refusing to type"))
        #expect(source.contains("type_text uses PID-scoped Unicode posting; use set_value for direct AX value mutation."))
        #expect(source.contains("AXActionRuntimeSupport.postUnicodeText(text, to: pid)"))
        #expect(source.contains("placeholderOnlyTextValue"))
        #expect(!source.contains("AXUIElementSetAttributeValue(kAXValueAttribute) + AXUIElementSetAttributeValue(kAXSelectedTextRangeAttribute)"))
        #expect(!source.contains("Using element-bound AX value write for type_text"))
    }

    @Test
    func clickyShellLifecycleSerializesGatewayRegistrationAndHeartbeat() throws {
        let source = try readRepositoryFile("leanring-buddy/CompanionManager.swift")

        #expect(source.contains("isClickyShellRegistrationInFlight"))
        #expect(source.contains("isClickyShellHeartbeatInFlight"))
        #expect(source.contains("guard !isClickyShellRegistrationInFlight else { return }"))
        #expect(source.contains("guard !isClickyShellHeartbeatInFlight else { return }"))
        #expect(source.contains("scheduleClickyShellRegistrationRetry()"))
        #expect(!source.contains("ClickyLogger.error(.plugin, \"Clicky shell heartbeat failed error=\\(error.localizedDescription)\")\n            attemptClickyShellRegistration()"))
    }

    @Test
    func routeDecoderAcceptsRuntimeDateFormats() throws {
        struct DateProbe: Decodable {
            let capturedAt: Date
            let observedAt: Date
            let fallbackAt: Date
        }

        let payload = Data(
            #"""
            {
              "capturedAt": "2026-04-27T13:14:57Z",
              "observedAt": "2026-04-27T13:14:57.123Z",
              "fallbackAt": 1777295697.0
            }
            """#.utf8
        )

        let decoded = try ClickyComputerUseRouteUtilities.makeRouteDecoder()
            .decode(DateProbe.self, from: payload)

        #expect(decoded.capturedAt.timeIntervalSince1970 > 0)
        #expect(decoded.observedAt.timeIntervalSince(decoded.capturedAt) > 0)
        #expect(decoded.fallbackAt.timeIntervalSince1970 == 1777295697.0)
    }

    @Test
    func actionPolicyStillSeparatesRoutineAndSensitiveActions() {
        let routineReview = ClickyComputerUseActionPolicy.review(
            toolName: .typeText,
            rawPayload: #"{"window":"window-1","target":{"kind":"display_index","value":7},"text":"hello"}"#
        )
        let sensitiveReview = ClickyComputerUseActionPolicy.review(
            toolName: .click,
            rawPayload: #"{"window":"window-1","target":{"kind":"display_index","value":4},"label":"Submit payment"}"#
        )

        #expect(routineReview.riskLevel == .normalMutation)
        #expect(!routineReview.isBlocked)
        #expect(sensitiveReview.riskLevel == .sensitiveHighImpact)
        #expect(sensitiveReview.requiresFreshObservation)
    }

    private func readRepositoryFile(_ relativePath: String) throws -> String {
        var directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let candidateURL = directoryURL.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                return try String(contentsOf: candidateURL, encoding: .utf8)
            }
            directoryURL.deleteLastPathComponent()
        }
        throw NSError(
            domain: "ClickyComputerUseContractTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not locate \(relativePath) from test working directory."]
        )
    }
}
