#!/usr/bin/env python3
"""Static evals for Clicky's OpenClaw-first computer-use contract.

These checks intentionally model the runtime-native API. They do not preserve
the removed final-JSON computer-use envelope.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_TOOLS = [
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
GENERIC_DESKTOP_AUTOMATION_TOOLS = {"exec", "process", "shell", "osascript", "browser"}


@dataclass(frozen=True)
class ToolCall:
    route: str
    app: str | None = None
    window: str | None = None
    target_display_index: int | None = None
    state_token: str | None = None
    text_entry_display_index: int | None = None
    label: str | None = None


@dataclass
class Scenario:
    name: str
    calls: list[ToolCall]
    required_routes: list[str]
    target_window: str = "w_helium_x"
    require_inventory_before_action: bool = False
    require_text_entry_observation: bool = False
    require_progress: bool = False
    failures: list[str] = field(default_factory=list)

    def run(self) -> "Scenario":
        seen_routes = {call.route for call in self.calls}
        for route in self.required_routes:
            if route not in seen_routes:
                self.failures.append(f"missing route {route}")

        listed_windows = False
        observed_text_entries: dict[str, set[int]] = {}
        last_progress_index = -1
        for index, call in enumerate(self.calls):
            if call.route in GENERIC_DESKTOP_AUTOMATION_TOOLS:
                self.failures.append(f"generic desktop automation escape: {call.route}")

            if call.route == "progress":
                last_progress_index = index
                continue

            if self.require_progress and call.route in RUNTIME_TOOLS and last_progress_index != index - 1:
                self.failures.append(f"missing progress before {call.route}")

            if call.route == "list_windows":
                if not call.app:
                    self.failures.append("list_windows missing app")
                listed_windows = True

            if call.route == "get_window_state" and call.window and call.text_entry_display_index is not None:
                observed_text_entries.setdefault(call.window, set()).add(call.text_entry_display_index)

            if call.route in {
                "click",
                "type_text",
                "press_key",
                "scroll",
                "set_value",
                "perform_secondary_action",
                "drag",
                "resize",
                "set_window_frame",
            }:
                if self.require_inventory_before_action and not listed_windows:
                    self.failures.append(f"action before inventory: {call.route}")
                if call.window in {"frontmost", "current", "active"}:
                    self.failures.append(f"frontmost alias used for {call.route}")
                if call.window and call.window != self.target_window:
                    self.failures.append(f"wrong window for {call.route}: {call.window}")

            if call.route == "type_text" and self.require_text_entry_observation:
                observed = observed_text_entries.get(call.window or "", set())
                if call.state_token is None or call.target_display_index not in observed:
                    self.failures.append("type_text before observed text-entry target")

            if call.route == "click" and (call.label or "").lower() in {"post", "submit", "publish"}:
                self.failures.append("final submit click without review")
        return self


def eval_plugin_contract() -> list[str]:
    failures: list[str] = []
    manifest = json.loads((ROOT / "plugins/openclaw-clicky-shell/openclaw.plugin.json").read_text())
    tools = manifest["contracts"]["tools"]
    for tool in RUNTIME_TOOLS:
        if tool not in tools:
            failures.append(f"manifest missing {tool}")
    for removed in ["clicky_request_computer_use", "computerUseAction"]:
        if removed in (ROOT / "plugins/openclaw-clicky-shell/index.ts").read_text():
            failures.append(f"plugin still contains removed contract token {removed}")
    source = (ROOT / "plugins/openclaw-clicky-shell/index.ts").read_text()
    if "prependSystemContext: context" not in source:
        failures.append("plugin prompt hook does not return prependSystemContext")
    if "ctx.systemMessages.push" in source:
        failures.append("plugin prompt hook still mutates unavailable systemMessages")
    if "parameters: runtimeToolParameters(route)" not in source:
        failures.append("plugin tools do not use route-specific parameter schemas")
    if "formatToolResult(route, result)" not in source:
        failures.append("plugin does not render runtime JSON into model-visible tool text")
    if "Clicky computer-use result for" in source or "Use this JSON as the source of truth" in source:
        failures.append("plugin tool text still wraps runtime JSON in prose")
    if "return JSON.stringify(compact, null, 2)" not in source:
        failures.append("plugin tool text is not pure JSON")
    if "rememberCompletionProof(shell, route, result, ctx?.sessionKey)" not in source:
        failures.append("plugin does not record runtime completion proof after tool results")
    if "validatePresentationAgainstCompletionProof(params, ctx?.sessionKey, shell)" not in source:
        failures.append("clicky_present is not gated by runtime completion proof")
    if "clicky_present cannot claim completion yet" not in source:
        failures.append("plugin does not force a post-action observation before completion claims")
    if "verify the result with get_window_state before using clicky_present" not in source:
        failures.append("plugin prompt does not require verified state before final presentation")
    if 'case "list_windows":\n    if (!hasString(payload, "app")) return missing("app");' not in source:
        failures.append("list_windows must require app to match the BackgroundComputerUse route contract")
    if "do not use generic shell/process/exec/osascript/browser automation" not in source:
        failures.append("plugin prompt does not forbid generic desktop automation escape hatches")
    agent_source = (ROOT / "leanring-buddy/OpenClawGatewayCompanionAgent.swift").read_text()
    if '"execSecurity": "deny"' not in agent_source:
        failures.append("OpenClaw Clicky sessions do not deny generic exec by default")
    if '"execAsk": "always"' not in agent_source:
        failures.append("OpenClaw Clicky sessions do not force review for generic exec fallback")
    if 'enum: ["display_index", "node_id", "refetch_fingerprint"]' not in source:
        failures.append("plugin does not expose upstream action target kinds")
    if "do not pass frontmost, current, active, or a visible title" not in source:
        failures.append("plugin prompt does not forbid stale frontmost/title window values")
    if "function validatePayload(route: ComputerUseRoute, params: unknown)" not in source:
        failures.append("plugin does not validate route-specific payload shape before forwarding")
    if "provide target, or provide both x and y" not in source:
        failures.append("click schema does not require upstream target or coordinates")
    if 'actionSchema(["window", "target", "direction"]' not in source:
        failures.append("scroll schema does not use upstream target object")
    if 'actionSchema(["window", "target", "value"]' not in source:
        failures.append("set_value schema does not use upstream target object")
    if 'if (!hasTarget(payload, "target")) return missing("target")' not in source:
        failures.append("plugin does not validate required target payloads")
    if 'Defaults to path' not in source:
        failures.append("plugin schema does not default screenshot transport to path")
    if "sanitizeToolResultForModel(result)" not in source:
        failures.append("plugin does not sanitize runtime results before returning structuredContent")
    if "compactToolResultForModel(route, result)" not in source:
        failures.append("plugin does not compact runtime results before returning them to the model")
    if "normalizeComputerUsePayloadForModel(route, payload)" not in source:
        failures.append("plugin does not normalize expensive computer-use observation defaults")
    if "function screenshotDataUrl(result: Record<string, unknown>)" in source:
        failures.append("plugin still attaches inline screenshots to tool results")
    if 'content.push({ type: "image", url: screenshotUrl })' in source:
        failures.append("plugin still exposes screenshots as image tool-result content")

    if "_ = try await connect()\n            defer { cancel() }" not in agent_source:
        failures.append("OpenClaw companion session is not canceled on timeout/error exits")

    manager_source = (ROOT / "leanring-buddy/CompanionManager.swift").read_text()
    if "computerUseActivityFinishTask" not in manager_source:
        failures.append("computer-use cursor activity does not debounce per-tool finish")
    if "minimumComputerUseStatusDisplayInterval" not in manager_source:
        failures.append("computer-use cursor status updates are not rate-limited")
    if 'body["imageMode"] = "path"' not in manager_source:
        failures.append("Clicky does not default OpenClaw screenshots to path")
    if "preparedCompactObservationPayload" not in manager_source:
        failures.append("Clicky does not apply compact observation defaults before runtime calls")
    if 'body["includeMenuBar"] = false' not in manager_source:
        failures.append("Clicky still defaults computer-use observations to include menu bar")
    if '"id": "clicky-openclaw-operator"' not in manager_source:
        failures.append("Clicky does not provide a stable runtime cursor for action routes")
    if "validateOpenClawComputerUsePayload(route: route, payload: payload)" not in manager_source:
        failures.append("Clicky does not enforce the OpenClaw action payload contract before forwarding")
    trace_source = (ROOT / "leanring-buddy/ClickyComputerUseDebugTrace.swift").read_text()
    gateway_source = (ROOT / "leanring-buddy/OpenClawGatewayCompanionAgent.swift").read_text()
    provider_source = (ROOT / "leanring-buddy/OpenClawAssistantProvider.swift").read_text()
    if "ComputerUseTraces" not in trace_source:
        failures.append("Clicky does not persist computer-use debug traces")
    if "recordOpenClawFrame" not in gateway_source:
        failures.append("Clicky does not trace OpenClaw gateway frames")
    if "recordOpenClawDispatch" not in provider_source:
        failures.append("Clicky does not trace the exact OpenClaw dispatch payload")
    if "beginToolStep" not in manager_source or "finishToolStep" not in manager_source:
        failures.append("Clicky does not trace before/after screenshots around computer-use tool calls")
    return failures


def scenarios() -> list[Scenario]:
    return [
        Scenario(
            name="x draft tweet",
            required_routes=["list_windows", "get_window_state", "click", "type_text"],
            require_inventory_before_action=True,
            require_text_entry_observation=True,
            calls=[
                ToolCall("list_windows", app="net.imput.helium"),
                ToolCall("get_window_state", window="w_helium_x", state_token="s1"),
                ToolCall("click", window="w_helium_x", target_display_index=4),
                ToolCall("get_window_state", window="w_helium_x", state_token="s2", text_entry_display_index=17),
                ToolCall("type_text", window="w_helium_x", state_token="s2", target_display_index=17),
            ],
        ),
        Scenario(
            name="visual progress",
            required_routes=["progress", "list_windows", "get_window_state", "click"],
            require_progress=True,
            calls=[
                ToolCall("progress"),
                ToolCall("list_windows", app="net.imput.helium"),
                ToolCall("progress"),
                ToolCall("get_window_state", window="w_helium_x"),
                ToolCall("progress"),
                ToolCall("click", window="w_helium_x", target_display_index=4),
            ],
        ),
        Scenario(
            name="mutation catches ungrounded type",
            required_routes=["type_text"],
            require_text_entry_observation=True,
            calls=[
                ToolCall("type_text", window="w_helium_x", target_display_index=17),
            ],
        ),
        Scenario(
            name="mutation catches generic desktop automation escape",
            required_routes=["list_windows", "get_window_state"],
            require_inventory_before_action=True,
            calls=[
                ToolCall("list_windows", app="net.imput.helium"),
                ToolCall("get_window_state", window="w_helium_x"),
                ToolCall("exec"),
            ],
        ),
    ]


def main() -> int:
    failures = eval_plugin_contract()
    for scenario in scenarios():
        scenario.run()
        if scenario.name == "mutation catches ungrounded type":
            if "type_text before observed text-entry target" not in scenario.failures:
                failures.append("mutation did not catch ungrounded type_text")
        elif scenario.name == "mutation catches generic desktop automation escape":
            if "generic desktop automation escape: exec" not in scenario.failures:
                failures.append("mutation did not catch generic desktop automation escape")
        else:
            failures.extend(f"{scenario.name}: {failure}" for failure in scenario.failures)

    if failures:
        print("clicky computer-use eval failures:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("clicky computer-use evals passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
