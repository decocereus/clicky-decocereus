//
//  ClickyComputerUseFlowScenarioTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct ClickyComputerUseFlowScenarioTests {
    @Test
    func xDraftTweetFlowOpensComposerTypesAndStopsBeforePosting() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .draftTweetHappyPath,
            calls: [
                .listWindows(app: "net.imput.helium"),
                .getWindowState(window: "w_helium_x"),
                .click(window: "w_helium_x", targetDisplayIndex: 4),
                .getWindowState(window: "w_helium_x", textEntryDisplayIndex: 17),
                .typeText(window: "w_helium_x", stateToken: "s2", targetDisplayIndex: 17, text: "hello world"),
                .getWindowState(window: "w_helium_x", textEntryDisplayIndex: 17),
            ]
        )

        #expect(report.failures.isEmpty)
    }

    @Test
    func sameTaskWhenXIsNotFrontmostSelectsHeliumWindowFromInventory() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .draftTweetBackgroundWindow,
            calls: [
                .listWindows(app: "net.imput.helium"),
                .getWindowState(window: "w_helium_x"),
                .click(window: "w_helium_x", targetDisplayIndex: 4),
                .getWindowState(window: "w_helium_x", textEntryDisplayIndex: 17),
                .typeText(window: "w_helium_x", stateToken: "s2", targetDisplayIndex: 17, text: "hello world"),
            ]
        )

        #expect(report.failures.isEmpty)
    }

    @Test
    func multiWindowHeliumChoosesXWindowByTitleOrUrl() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .multiWindowHelium,
            calls: [
                .listWindows(app: "net.imput.helium"),
                .getWindowState(window: "w_helium_x"),
                .click(window: "w_helium_x", targetDisplayIndex: 4),
                .getWindowState(window: "w_helium_x", textEntryDisplayIndex: 17),
                .typeText(window: "w_helium_x", stateToken: "s2", targetDisplayIndex: 17, text: "hello world"),
            ]
        )

        #expect(report.failures.isEmpty)
    }

    @Test
    func staleWindowIdRecoversByListingWindowsAndReobserving() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .staleWindowRecovery,
            calls: [
                .getWindowState(window: "stale_window"),
                .listWindows(app: "net.imput.helium"),
                .getWindowState(window: "w_helium_x"),
                .click(window: "w_helium_x", targetDisplayIndex: 4),
            ]
        )

        #expect(report.failures.isEmpty)
    }

    @Test
    func textEntryTypesOnlyAfterObservingTextEntryElement() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .textEntryGrounding,
            calls: [
                .getWindowState(window: "w_helium_x", textEntryDisplayIndex: 17),
                .typeText(window: "w_helium_x", stateToken: "s1", targetDisplayIndex: 17, text: "hello world"),
            ]
        )

        #expect(report.failures.isEmpty)
    }

    @Test
    func sensitiveFinalActionUsesReviewModeOnlyForRealSubmit() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .sensitiveFinalAction,
            calls: [
                .getWindowState(window: "w_helium_x", textEntryDisplayIndex: 17),
                .typeText(window: "w_helium_x", stateToken: "s1", targetDisplayIndex: 17, text: "hello world"),
                .review(route: "click", label: "Post"),
            ]
        )

        #expect(report.failures.isEmpty)
    }

    @Test
    func backgroundActionUsesTargetWindowInsteadOfFrontmostAlias() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .backgroundAction,
            calls: [
                .listWindows(app: "net.imput.helium"),
                .getWindowState(window: "w_helium_x"),
                .click(window: "w_helium_x", targetDisplayIndex: 4),
                .typeText(window: "w_helium_x", stateToken: "s2", targetDisplayIndex: 17, text: "hello world"),
            ]
        )

        #expect(report.failures.isEmpty)
    }

    @Test
    func visualProgressStartsBeforeFirstActionAndUpdatesEveryAction() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .visualProgress,
            calls: [
                .progress("looking at windows"),
                .listWindows(app: "net.imput.helium"),
                .progress("looking at window"),
                .getWindowState(window: "w_helium_x"),
                .progress("clicking"),
                .click(window: "w_helium_x", targetDisplayIndex: 4),
            ]
        )

        #expect(report.failures.isEmpty)
    }

    @Test
    func mutationRejectsTypingBeforeStateObservation() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .textEntryGrounding,
            calls: [
                .typeText(window: "w_helium_x", stateToken: nil, targetDisplayIndex: 17, text: "hello world"),
            ]
        )

        #expect(report.failures.contains(.typedBeforeObservedTextEntryTarget))
    }

    @Test
    func mutationRejectsFrontmostAliasForBackgroundWindowTask() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .backgroundAction,
            calls: [
                .listWindows(app: "net.imput.helium"),
                .getWindowState(window: "w_helium_x"),
                .click(window: "frontmost", targetDisplayIndex: 4),
            ]
        )

        #expect(report.failures.contains(.usedFrontmostAlias))
    }

    @Test
    func mutationRejectsGenericDesktopAutomationEscape() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .draftTweetHappyPath,
            calls: [
                .listWindows(app: "net.imput.helium"),
                .getWindowState(window: "w_helium_x"),
                .desktopAutomationEscape("exec"),
            ]
        )

        #expect(report.failures.contains(.usedGenericDesktopAutomation("exec")))
    }

    @Test
    func mutationRejectsCompletionClaimBeforePostActionObservation() {
        let report = ComputerUseFlowEvalHarness.run(
            scenario: .draftTweetHappyPath,
            calls: [
                .listWindows(app: "net.imput.helium"),
                .getWindowState(window: "w_helium_x"),
                .click(window: "w_helium_x", targetDisplayIndex: 4),
                .presentCompletion("done, i opened the composer"),
            ]
        )

        #expect(report.failures.contains(.completionClaimBeforePostActionObservation))
    }
}

private struct ComputerUseFlowScenario {
    let name: String
    let requiredRoutes: [String]
    let targetWindow: String
    var requiresInventoryBeforeAction = false
    var requiresStaleRecovery = false
    var requiresTextEntryObservation = false
    var forbidsFinalSubmit = true
    var requiresProgress = false

    static let draftTweetHappyPath = ComputerUseFlowScenario(
        name: "x_draft_tweet",
        requiredRoutes: ["list_windows", "get_window_state", "click", "type_text"],
        targetWindow: "w_helium_x",
        requiresInventoryBeforeAction: true,
        requiresTextEntryObservation: true
    )

    static let draftTweetBackgroundWindow = ComputerUseFlowScenario(
        name: "x_not_frontmost",
        requiredRoutes: ["list_windows", "get_window_state", "click", "type_text"],
        targetWindow: "w_helium_x",
        requiresInventoryBeforeAction: true,
        requiresTextEntryObservation: true
    )

    static let multiWindowHelium = ComputerUseFlowScenario(
        name: "multi_window_helium",
        requiredRoutes: ["list_windows", "get_window_state", "click"],
        targetWindow: "w_helium_x",
        requiresInventoryBeforeAction: true
    )

    static let staleWindowRecovery = ComputerUseFlowScenario(
        name: "stale_window_id",
        requiredRoutes: ["list_windows", "get_window_state", "click"],
        targetWindow: "w_helium_x",
        requiresStaleRecovery: true
    )

    static let textEntryGrounding = ComputerUseFlowScenario(
        name: "text_entry",
        requiredRoutes: ["get_window_state", "type_text"],
        targetWindow: "w_helium_x",
        requiresTextEntryObservation: true
    )

    static let sensitiveFinalAction = ComputerUseFlowScenario(
        name: "sensitive_final_action",
        requiredRoutes: ["get_window_state", "type_text", "review"],
        targetWindow: "w_helium_x",
        requiresTextEntryObservation: true,
        forbidsFinalSubmit: false
    )

    static let backgroundAction = ComputerUseFlowScenario(
        name: "background_action",
        requiredRoutes: ["list_windows", "get_window_state", "click"],
        targetWindow: "w_helium_x",
        requiresInventoryBeforeAction: true
    )

    static let visualProgress = ComputerUseFlowScenario(
        name: "visual_progress",
        requiredRoutes: ["progress", "list_windows", "get_window_state", "click"],
        targetWindow: "w_helium_x",
        requiresProgress: true
    )
}

private struct ComputerUseToolCall: Equatable {
    let route: String
    var app: String? = nil
    var window: String? = nil
    var stateToken: String? = nil
    var targetDisplayIndex: Int? = nil
    var text: String? = nil
    var textEntryDisplayIndex: Int? = nil
    var label: String? = nil

    static func listWindows(app: String?) -> ComputerUseToolCall {
        ComputerUseToolCall(route: "list_windows", app: app)
    }

    static func getWindowState(window: String, textEntryDisplayIndex: Int? = nil) -> ComputerUseToolCall {
        ComputerUseToolCall(route: "get_window_state", window: window, stateToken: "s1", textEntryDisplayIndex: textEntryDisplayIndex)
    }

    static func click(window: String, targetDisplayIndex: Int) -> ComputerUseToolCall {
        ComputerUseToolCall(route: "click", window: window, targetDisplayIndex: targetDisplayIndex)
    }

    static func typeText(window: String, stateToken: String?, targetDisplayIndex: Int, text: String) -> ComputerUseToolCall {
        ComputerUseToolCall(route: "type_text", window: window, stateToken: stateToken, targetDisplayIndex: targetDisplayIndex, text: text)
    }

    static func review(route: String, label: String) -> ComputerUseToolCall {
        ComputerUseToolCall(route: "review", label: label)
    }

    static func progress(_ label: String) -> ComputerUseToolCall {
        ComputerUseToolCall(route: "progress", label: label)
    }

    static func desktopAutomationEscape(_ route: String) -> ComputerUseToolCall {
        ComputerUseToolCall(route: route)
    }

    static func presentCompletion(_ text: String) -> ComputerUseToolCall {
        ComputerUseToolCall(route: "clicky_present", text: text)
    }
}

private struct ComputerUseFlowReport {
    var failures: [ComputerUseFlowFailure] = []
}

private enum ComputerUseFlowFailure: Equatable {
    case missingRoute(String)
    case actionBeforeInventory(String)
    case usedFrontmostAlias
    case wrongWindow(route: String, expected: String, actual: String?)
    case typedBeforeObservedTextEntryTarget
    case finalSubmitWithoutReview
    case staleWindowNotRecovered
    case missingProgressBeforeAction(String)
    case usedGenericDesktopAutomation(String)
    case completionClaimBeforePostActionObservation
    case listWindowsMissingApp
}

private enum ComputerUseFlowEvalHarness {
    static func run(
        scenario: ComputerUseFlowScenario,
        calls: [ComputerUseToolCall]
    ) -> ComputerUseFlowReport {
        var report = ComputerUseFlowReport()
        var observedTextEntriesByWindow: [String: Set<Int>] = [:]
        var hasListedWindows = false
        var sawStaleWindow = false
        var recoveredAfterStale = false
        var lastProgressIndex = -1
        var lastMutationIndex: Int?
        var lastObservationIndex: Int?
        let genericDesktopAutomationRoutes = Set(["exec", "process", "shell", "osascript", "browser"])

        for (index, call) in calls.enumerated() {
            if genericDesktopAutomationRoutes.contains(call.route) {
                report.failures.append(.usedGenericDesktopAutomation(call.route))
            }

            if call.route == "progress" {
                lastProgressIndex = index
                continue
            }

            if scenario.requiresProgress,
               ["list_windows", "get_window_state", "click", "type_text"].contains(call.route),
               lastProgressIndex != index - 1 {
                report.failures.append(.missingProgressBeforeAction(call.route))
            }

            if call.route == "list_windows" {
                if call.app?.isEmpty ?? true {
                    report.failures.append(.listWindowsMissingApp)
                }
                hasListedWindows = true
            }

            if call.route == "get_window_state" {
                lastObservationIndex = index
            }

            if call.window == "stale_window" {
                sawStaleWindow = true
            }

            if sawStaleWindow && call.route == "get_window_state" && call.window == scenario.targetWindow {
                recoveredAfterStale = true
            }

            if call.route == "get_window_state",
               let window = call.window,
               let textEntryDisplayIndex = call.textEntryDisplayIndex {
                observedTextEntriesByWindow[window, default: []].insert(textEntryDisplayIndex)
            }

            if ["click", "type_text", "press_key", "scroll", "set_value", "perform_secondary_action", "drag", "resize", "set_window_frame"].contains(call.route) {
                lastMutationIndex = index

                if scenario.requiresInventoryBeforeAction && !hasListedWindows {
                    report.failures.append(.actionBeforeInventory(call.route))
                }

                if call.window == "frontmost" || call.window == "current" || call.window == "active" {
                    report.failures.append(.usedFrontmostAlias)
                } else if call.window != scenario.targetWindow {
                    report.failures.append(.wrongWindow(route: call.route, expected: scenario.targetWindow, actual: call.window))
                }
            }

            if call.route == "clicky_present",
               let lastMutationIndex,
               (lastObservationIndex ?? -1) < lastMutationIndex,
               (call.text ?? "").localizedCaseInsensitiveContains("done") {
                report.failures.append(.completionClaimBeforePostActionObservation)
            }

            if call.route == "type_text" {
                let observedElements = observedTextEntriesByWindow[call.window ?? ""] ?? []
                if call.stateToken == nil || call.targetDisplayIndex == nil || !observedElements.contains(call.targetDisplayIndex ?? -1) {
                    report.failures.append(.typedBeforeObservedTextEntryTarget)
                }
            }

            if scenario.forbidsFinalSubmit,
               call.route == "click",
               (call.label ?? "").localizedCaseInsensitiveContains("post") {
                report.failures.append(.finalSubmitWithoutReview)
            }
        }

        for requiredRoute in scenario.requiredRoutes
            where !calls.contains(where: { $0.route == requiredRoute }) {
            report.failures.append(.missingRoute(requiredRoute))
        }

        if scenario.requiresStaleRecovery && !recoveredAfterStale {
            report.failures.append(.staleWindowNotRecovered)
        }

        return report
    }
}
