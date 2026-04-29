import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

type ShellRegistration = {
  agentIdentityName: string | null;
  bridgeVersion: string | null;
  clickyPresentationName: string | null;
  capabilities: string[];
  lastHeartbeatAt: number;
  promptContext: string | null;
  registeredAt: number;
  runtimeMode: string | null;
  screenContextTransport: string | null;
  sessionKey: string | null;
  shellId: string;
  shellLabel: string | null;
  shellTransportScope: "local-gateway" | "remote-gateway";
};

type PresentationMode = "answer" | "point" | "walkthrough" | "tutorial";
type ComputerUseRoute =
  | "list_apps"
  | "list_windows"
  | "get_window_state"
  | "click"
  | "type_text"
  | "press_key"
  | "scroll"
  | "set_value"
  | "perform_secondary_action"
  | "drag"
  | "resize"
  | "set_window_frame";

type QueuedComputerUseRequest = {
  createdAt: number;
  payload: Record<string, unknown>;
  requestId: string;
  resolve: (result: Record<string, unknown>) => void;
  route: ComputerUseRoute;
  sessionKey: string | null;
  shellId: string;
  timeout: ReturnType<typeof setTimeout>;
};

type WaitingPoll = {
  deadline: number;
  respond: (ok: boolean, payload: Record<string, unknown>) => void;
  sessionKey: string | null;
  shellId: string;
  timeout: ReturnType<typeof setTimeout>;
};

type ComputerUseCompletionProof = {
  lastMutationAt: number | null;
  lastMutationRoute: ComputerUseRoute | null;
  lastObservationAt: number | null;
  lastResultOk: boolean | null;
  lastRoute: ComputerUseRoute;
  lastUpdatedAt: number;
  startedAt: number;
};

const computerUseRoutes = [
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
] as const satisfies readonly ComputerUseRoute[];

const registrationsByShellId = new Map<string, ShellRegistration>();
const pendingComputerUseRequests = new Map<string, QueuedComputerUseRequest>();
const completionProofBySession = new Map<string, ComputerUseCompletionProof>();
const waitingPolls: WaitingPoll[] = [];
const completionProofTtlMs = 10 * 60 * 1000;

function normalizePluginConfig(config: unknown) {
  const record = config && typeof config === "object" && !Array.isArray(config)
    ? config as Record<string, unknown>
    : {};

  return {
    allowRemoteDesktopShell: record.allowRemoteDesktopShell === true,
    registrationTtlMs: typeof record.registrationTtlMs === "number"
      ? Math.max(5_000, Math.min(300_000, Math.floor(record.registrationTtlMs)))
      : 45_000,
  };
}

function candidateSessionKeys(sessionKey: string | null | undefined) {
  if (!sessionKey) return [];
  const trimmed = sessionKey.trim();
  if (!trimmed) return [];

  const candidates = new Set<string>([trimmed]);
  const segments = trimmed.split(":");
  if (segments.length >= 3 && segments[0] === "agent") {
    candidates.add(segments.slice(2).join(":"));
    if (segments[2] === "explicit" && segments.length >= 4) {
      candidates.add(segments.slice(3).join(":"));
    }
  }
  if (segments[0] === "explicit" && segments.length >= 2) {
    candidates.add(segments.slice(1).join(":"));
  }
  return [...candidates];
}

function sessionKeysMatch(left: string | null | undefined, right: string | null | undefined) {
  const rightCandidates = new Set(candidateSessionKeys(right));
  return candidateSessionKeys(left).some((candidate) => rightCandidates.has(candidate));
}

function primarySessionKey(sessionKey: string | null | undefined, shellId: string | null | undefined) {
  return candidateSessionKeys(sessionKey)[0] ?? (shellId ? `shell:${shellId}` : "unbound");
}

function completionProofKeys(sessionKey: string | null | undefined, shell: ShellRegistration | null | undefined) {
  const keys = new Set<string>();
  for (const candidate of candidateSessionKeys(sessionKey)) keys.add(candidate);
  for (const candidate of candidateSessionKeys(shell?.sessionKey)) keys.add(candidate);
  if (shell?.shellId) keys.add(`shell:${shell.shellId}`);
  if (keys.size === 0) keys.add("unbound");
  return [...keys];
}

function routeIsMutation(route: ComputerUseRoute) {
  return !["list_apps", "list_windows", "get_window_state"].includes(route);
}

function freshnessState(registration: ShellRegistration, ttlMs: number) {
  return Date.now() - registration.lastHeartbeatAt <= ttlMs ? "fresh" : "stale";
}

function serializeRegistration(registration: ShellRegistration, ttlMs: number) {
  return {
    ...registration,
    freshnessState: freshnessState(registration, ttlMs),
    sessionBindingState: registration.sessionKey ? "bound" : "unbound",
    trustState: registration.shellTransportScope === "local-gateway" ? "trusted-local" : "trusted-remote",
  };
}

function pruneExpiredRegistrations(ttlMs: number) {
  const now = Date.now();
  for (const [shellId, registration] of registrationsByShellId.entries()) {
    if (now - registration.lastHeartbeatAt > ttlMs) {
      registrationsByShellId.delete(shellId);
    }
  }
  for (const [key, proof] of completionProofBySession.entries()) {
    if (now - proof.lastUpdatedAt > completionProofTtlMs) {
      completionProofBySession.delete(key);
    }
  }
}

function parseString(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function parseShellRegistration(params: unknown): ShellRegistration | null {
  if (!params || typeof params !== "object" || Array.isArray(params)) return null;
  const record = params as Record<string, unknown>;
  const shellId = parseString(record.shellId);
  if (!shellId) return null;

  return {
    agentIdentityName: parseString(record.agentIdentityName),
    bridgeVersion: parseString(record.bridgeVersion),
    capabilities: Array.isArray(record.capabilities)
      ? record.capabilities.filter((value): value is string => typeof value === "string")
      : [],
    clickyPresentationName: parseString(record.clickyPresentationName),
    lastHeartbeatAt: Date.now(),
    promptContext: null,
    registeredAt: typeof record.registeredAt === "number" ? Math.floor(record.registeredAt) : Date.now(),
    runtimeMode: parseString(record.runtimeMode),
    screenContextTransport: parseString(record.screenContextTransport),
    sessionKey: parseString(record.sessionKey),
    shellId,
    shellLabel: parseString(record.shellLabel),
    shellTransportScope: record.shellTransportScope === "remote-gateway" ? "remote-gateway" : "local-gateway",
  };
}

function findFreshShell(sessionKey: string | null | undefined, ttlMs: number) {
  const registrations = [...registrationsByShellId.values()]
    .filter((registration) => freshnessState(registration, ttlMs) === "fresh")
    .sort((left, right) => right.lastHeartbeatAt - left.lastHeartbeatAt);

  const sessionMatch = registrations.find((registration) =>
    sessionKeysMatch(registration.sessionKey, sessionKey)
  );
  return sessionMatch ?? registrations[0] ?? null;
}

function statusSummary(config: unknown, includeRegistrations: boolean) {
  const normalized = normalizePluginConfig(config);
  pruneExpiredRegistrations(normalized.registrationTtlMs);
  const registrations = [...registrationsByShellId.values()];
  const lines = [
    registrations.length > 0
      ? `Clicky shell connected: ${registrations.length} active.`
      : "No Clicky desktop shell is currently connected.",
    "Computer use tools: list_apps, list_windows, get_window_state, click, type_text, press_key, scroll, set_value, perform_secondary_action, drag, resize, set_window_frame.",
  ];

  if (includeRegistrations) {
    lines.push(
      ...registrations.map((registration) =>
        `- ${registration.shellLabel ?? registration.shellId}: ${registration.sessionKey ?? "unbound"} (${freshnessState(registration, normalized.registrationTtlMs)})`
      )
    );
  }
  return lines.join("\n");
}

function buildPromptInstructions() {
  return [
    "clicky desktop tools:",
    "- use the computer-use tools directly. they execute through the connected Clicky desktop shell and return live runtime results.",
    "- do not use generic shell/process/exec/osascript/browser automation for desktop control. if a desktop action is needed, use these Clicky computer-use tools so Clicky can show cursor progress, apply policy, and verify state.",
    "- use an observe-act-observe loop: list_apps or list_windows when choosing a target, get_window_state before meaningful UI actions, perform one action, then observe again.",
    "- window must be the exact stable window ID from list_windows. do not pass frontmost, current, active, or a visible title as the window value.",
    "- choose windows and elements yourself from runtime state. Clicky does not perform semantic target scoring for you.",
    "- get_window_state returns compact live window state, element indices, focused element, stateToken, and screenshot metadata. after each action, call get_window_state again before deciding the next step.",
    "- normal computer-use tools return compact JSON only. screenshots, raw trees, gateway frames, and before/after artifacts are recorded by Clicky out-of-band for debugging, not stuffed into this model context.",
    "- keep observation calls cheap unless you truly need expansion: prefer visible traversal, omit menu bars, and request debug or full traversal only for targeted recovery.",
    "- actions require the exact window ID from list_windows. use target objects from the latest get_window_state, for example {kind:'display_index', value: 12}. pass stateToken when the runtime returned one, but do not invent it.",
    "- for text entry, call type_text with an observed text-entry target from get_window_state whenever possible. if the editor is not visible in the latest state, observe or recover before typing.",
    "- for draft flows, stop before final submit/publish unless the user explicitly asks and Review allows it.",
    "- routine actions run immediately when Clicky Studio is Auto Approved. Review may pause sensitive final actions like submit, delete, payment, or account/security changes.",
    "- after completing desktop work, verify the result with get_window_state before using clicky_present to say it is done.",
  ].join("\n");
}

const statusToolParameters = {
  type: "object",
  additionalProperties: false,
  properties: {
    includeRegistrations: { type: "boolean" },
  },
};

const presentToolParameters = {
  type: "object",
  additionalProperties: false,
  required: ["mode", "spokenText", "points"],
  properties: {
    mode: { type: "string", enum: ["answer", "point", "walkthrough", "tutorial"] },
    spokenText: { type: "string" },
    points: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["x", "y", "label"],
        properties: {
          x: { type: "integer" },
          y: { type: "integer" },
          label: { type: "string" },
          bubbleText: { type: "string" },
          explanation: { type: "string" },
          screenNumber: { type: "integer" },
        },
      },
    },
  },
};

const cursorParameter = {
  type: "object",
  additionalProperties: true,
  properties: {
    id: { type: "string" },
    name: { type: "string" },
    color: { type: "string" },
  },
};

const actionTargetParameter = {
  type: "object",
  additionalProperties: false,
  required: ["kind", "value"],
  properties: {
    kind: {
      type: "string",
      enum: ["display_index", "node_id", "refetch_fingerprint"],
      description: "Runtime target kind from get_window_state. Prefer display_index for visible projected-tree nodes.",
    },
    value: {
      description: "Target value. For display_index this must be the integer display index from get_window_state.",
      anyOf: [{ type: "integer" }, { type: "string" }],
    },
  },
};

const commonObservationProperties = {
  includeMenuBar: { type: "boolean", description: "Defaults to false for normal computer-use. Set true only when intentionally inspecting menus." },
  maxNodes: { type: "integer", description: "Defaults to a compact bound. Increase only for targeted recovery after a compact observation was insufficient." },
  imageMode: { type: "string", enum: ["path", "base64", "omit"], description: "Defaults to path. Inline base64 screenshots are not returned through OpenClaw tool results because they bloat and can poison provider history." },
  debug: { type: "boolean" },
};

function runtimeToolParameters(route: ComputerUseRoute) {
  switch (route) {
  case "list_apps":
    return {
      type: "object",
      additionalProperties: false,
      properties: {},
    };
  case "list_windows":
    return {
      type: "object",
      additionalProperties: false,
      required: ["app"],
      properties: {
        app: { type: "string", description: "App name, bundle ID, or target query from list_apps." },
      },
    };
  case "get_window_state":
    return {
      type: "object",
      additionalProperties: false,
      required: ["window"],
      properties: {
        window: { type: "string", description: "Stable window ID returned by list_windows." },
        menuPath: { type: "array", items: { type: "string" } },
        webTraversal: { type: "string", enum: ["visible", "full"], description: "Defaults to visible. Use full only for targeted recovery because it can produce very large state." },
        includeRawScreenshot: { type: "boolean" },
        debugMode: { type: "string", enum: ["none", "summary", "full"] },
        includeDiagnostics: { type: "boolean" },
        includePlatformProfile: { type: "boolean" },
        includeRawCapture: { type: "boolean" },
        includeSemanticTree: { type: "boolean" },
        includeProjectedTree: { type: "boolean", description: "Defaults to true but model-visible output is compacted. Full debug trees are stored in Clicky traces." },
        ...commonObservationProperties,
      },
    };
  case "click":
    return {
      type: "object",
      additionalProperties: false,
      required: ["window"],
      anyOf: [
        { required: ["target"] },
        { required: ["x", "y"] },
      ],
      properties: {
        window: { type: "string", description: "Stable window ID returned by list_windows." },
        stateToken: { type: "string", description: "Optional state token returned by the latest get_window_state for this window." },
        target: actionTargetParameter,
        x: { type: "number" },
        y: { type: "number" },
        mode: { type: "string", enum: ["single", "double"] },
        clickCount: { type: "integer", enum: [1, 2] },
        mouseButton: { type: "string", enum: ["left", "right", "middle"] },
        cursor: cursorParameter,
        ...commonObservationProperties,
      },
    };
  case "type_text":
    return actionSchema(["window", "text"], {
      stateToken: { type: "string" },
      target: actionTargetParameter,
      text: { type: "string" },
      focusAssistMode: { type: "string", enum: ["none", "focus", "focus_and_caret_end"], description: "Optional assist after the observed target is chosen." },
      ...commonObservationProperties,
    });
  case "press_key":
    return actionSchema(["window", "key"], {
      stateToken: { type: "string" },
      key: { type: "string", description: "Keyboard key or shortcut, e.g. Enter, Escape, Meta+L." },
      ...commonObservationProperties,
    });
  case "scroll":
    return actionSchema(["window", "target", "direction"], {
      stateToken: { type: "string" },
      target: actionTargetParameter,
      direction: { type: "string", enum: ["up", "down", "left", "right"] },
      pages: { type: "integer" },
      verificationMode: { type: "string", enum: ["strict", "fast"] },
      ...commonObservationProperties,
    });
  case "set_value":
    return actionSchema(["window", "target", "value"], {
      stateToken: { type: "string" },
      target: actionTargetParameter,
      value: { type: "string" },
      ...commonObservationProperties,
    });
  case "perform_secondary_action":
    return actionSchema(["window", "target", "action"], {
      stateToken: { type: "string" },
      target: actionTargetParameter,
      action: { type: "string", description: "Exact public label from the target node secondaryActions array." },
      actionID: { type: "string" },
      menuPath: { type: "array", items: { type: "string" } },
      webTraversal: { type: "string", enum: ["visible", "full"] },
      ...commonObservationProperties,
    });
  case "drag":
    return actionSchema(["window", "toX", "toY"], {
      toX: { type: "number" },
      toY: { type: "number" },
    });
  case "resize":
    return actionSchema(["window", "handle", "toX", "toY"], {
      handle: { type: "string", enum: ["left", "right", "top", "bottom", "topLeft", "topRight", "bottomLeft", "bottomRight"] },
      toX: { type: "number" },
      toY: { type: "number" },
    });
  case "set_window_frame":
    return actionSchema(["window", "x", "y", "width", "height"], {
      x: { type: "number" },
      y: { type: "number" },
      width: { type: "number" },
      height: { type: "number" },
      animate: { type: "boolean" },
    });
  }
}

function actionSchema(required: string[], properties: Record<string, unknown>) {
  return {
    type: "object",
    additionalProperties: false,
    required,
    properties: {
      window: { type: "string", description: "Stable window ID returned by list_windows." },
      cursor: cursorParameter,
      ...properties,
    },
  };
}

function hasString(record: Record<string, unknown>, key: string) {
  return typeof record[key] === "string" && Boolean((record[key] as string).trim());
}

function hasNumber(record: Record<string, unknown>, key: string) {
  return typeof record[key] === "number" && Number.isFinite(record[key] as number);
}

function hasInteger(record: Record<string, unknown>, key: string) {
  return Number.isInteger(record[key]);
}

function hasTarget(record: Record<string, unknown>, key: string) {
  const value = record[key];
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const target = value as Record<string, unknown>;
  if (!["display_index", "node_id", "refetch_fingerprint"].includes(String(target.kind))) {
    return false;
  }
  if (target.kind === "display_index") {
    if (Number.isInteger(target.value) && (target.value as number) >= 0) return true;
    if (typeof target.value === "string" && /^\d+$/.test(target.value.trim())) return true;
    return false;
  }
  return typeof target.value === "string" && Boolean(target.value.trim());
}

function validatePayload(route: ComputerUseRoute, params: unknown) {
  if (!params || typeof params !== "object" || Array.isArray(params)) {
    return { ok: false as const, error: "tool parameters must be a JSON object." };
  }
  const payload = { ...(params as Record<string, unknown>) };
  const missing = (field: string) => ({ ok: false as const, error: `${route} requires ${field}.` });
  const invalid = (message: string) => ({ ok: false as const, error: `${route}: ${message}` });

  switch (route) {
  case "list_apps":
    break;
  case "list_windows":
    if (!hasString(payload, "app")) return missing("app");
    break;
  case "get_window_state":
    if (!hasString(payload, "window")) return missing("window");
    break;
  case "click":
    if (!hasString(payload, "window")) return missing("window");
    if (!hasTarget(payload, "target") && !(hasNumber(payload, "x") && hasNumber(payload, "y"))) {
      return invalid("provide target, or provide both x and y.");
    }
    break;
  case "type_text":
    if (!hasString(payload, "window")) return missing("window");
    if (!hasString(payload, "text")) return missing("text");
    if (payload.target !== undefined && !hasTarget(payload, "target")) return invalid("target must use kind and value.");
    break;
  case "press_key":
    if (!hasString(payload, "window")) return missing("window");
    if (!hasString(payload, "key")) return missing("key");
    break;
  case "scroll":
    if (!hasString(payload, "window")) return missing("window");
    if (!hasTarget(payload, "target")) return missing("target");
    if (!hasString(payload, "direction")) return missing("direction");
    break;
  case "set_value":
    if (!hasString(payload, "window")) return missing("window");
    if (!hasTarget(payload, "target")) return missing("target");
    if (!hasString(payload, "value")) return missing("value");
    break;
  case "perform_secondary_action":
    if (!hasString(payload, "window")) return missing("window");
    if (!hasTarget(payload, "target")) return missing("target");
    if (!hasString(payload, "action")) return missing("action");
    break;
  case "drag":
    if (!hasString(payload, "window")) return missing("window");
    if (!hasNumber(payload, "toX") || !hasNumber(payload, "toY")) return invalid("provide toX and toY.");
    break;
  case "resize":
    if (!hasString(payload, "window")) return missing("window");
    if (!hasString(payload, "handle")) return missing("handle");
    if (!hasNumber(payload, "toX") || !hasNumber(payload, "toY")) return invalid("provide toX and toY.");
    break;
  case "set_window_frame":
    if (!hasString(payload, "window")) return missing("window");
    for (const field of ["x", "y", "width", "height"]) {
      if (!hasNumber(payload, field)) return missing(field);
    }
    break;
  }

  return { ok: true as const, payload: normalizeComputerUsePayloadForModel(route, payload) };
}

function normalizeComputerUsePayloadForModel(route: ComputerUseRoute, payload: Record<string, unknown>) {
  const normalized = { ...payload };
  if (!["get_window_state", "click", "type_text", "press_key", "scroll", "set_value", "perform_secondary_action"].includes(route)) {
    return normalized;
  }

  const explicitDebug = normalized.debug === true || normalized.debugMode === "full";
  if (normalized.imageMode === undefined || normalized.imageMode === "base64") {
    normalized.imageMode = "path";
  }
  if (normalized.includeMenuBar === undefined) {
    normalized.includeMenuBar = false;
  }

  if (route === "get_window_state") {
    if (normalized.webTraversal === undefined) {
      normalized.webTraversal = "visible";
    }
    if (normalized.includeProjectedTree === undefined) {
      normalized.includeProjectedTree = true;
    }
    if (normalized.maxNodes === undefined || !Number.isFinite(normalized.maxNodes as number)) {
      normalized.maxNodes = explicitDebug ? 6500 : 180;
    } else if (!explicitDebug && typeof normalized.maxNodes === "number") {
      normalized.maxNodes = Math.max(40, Math.min(220, Math.floor(normalized.maxNodes)));
    }
  } else {
    if (normalized.maxNodes === undefined || !Number.isFinite(normalized.maxNodes as number)) {
      normalized.maxNodes = explicitDebug ? 6500 : 180;
    } else if (!explicitDebug && typeof normalized.maxNodes === "number") {
      normalized.maxNodes = Math.max(40, Math.min(220, Math.floor(normalized.maxNodes)));
    }
  }

  return normalized;
}

function humanRouteLabel(route: ComputerUseRoute) {
  switch (route) {
  case "list_apps":
  case "list_windows":
  case "get_window_state":
    return "looking";
  case "click":
    return "clicking";
  case "type_text":
    return "typing";
  case "press_key":
    return "pressing keys";
  case "scroll":
    return "scrolling";
  case "set_value":
    return "updating a field";
  case "perform_secondary_action":
    return "opening an action";
  case "drag":
    return "dragging";
  case "resize":
    return "resizing";
  case "set_window_frame":
    return "moving the window";
  }
}

function runtimeToolDescription(route: ComputerUseRoute) {
  switch (route) {
  case "list_apps":
    return "List running apps visible to Clicky's desktop runtime.";
  case "list_windows":
    return "List live windows for an app name, bundle ID, or app identifier from list_apps.";
  case "get_window_state":
    return "Observe one live window and return its stateToken, screenshot metadata, AX tree, focused element, and element indices. Pass the exact stable window ID returned by list_windows.";
  case "click":
    return "Click an observed target or screenshot coordinate. Prefer target from the latest get_window_state, such as {kind:'display_index', value: 12}.";
  case "type_text":
    return "Type text into an observed text-entry target. Prefer target from the latest get_window_state; omit target only when intentionally typing into the already-focused field.";
  case "press_key":
    return "Send a key or shortcut to the target window, such as Enter, Escape, or Meta+L.";
  case "scroll":
    return "Scroll an observed scrollable element in a target window.";
  case "set_value":
    return "Set the value of an observed value-bearing element.";
  case "perform_secondary_action":
    return "Perform a secondary action exposed by an observed target, using the exact action label or actionID from get_window_state.";
  case "drag":
    return "Move a window by dragging it to a destination origin.";
  case "resize":
    return "Resize a window from a handle to a destination point.";
  case "set_window_frame":
    return "Set a window frame directly with x, y, width, and height.";
  }
}

function isLargeInlineMediaString(value: string) {
  if (/^data:image\/[a-z0-9.+-]+;base64,/i.test(value)) return true;
  if (value.length > 500 && /^[A-Za-z0-9+/=\r\n]+$/.test(value)) return true;
  return false;
}

function sanitizeToolResultForModel(value: unknown, depth = 0): unknown {
  if (typeof value === "string" && isLargeInlineMediaString(value)) {
    return `[omitted inline image ${value.length} chars]`;
  }
  if (typeof value === "string" && value.length > 12000) {
    return `${value.slice(0, 12000)}[truncated ${value.length - 12000} chars]`;
  }
  if (depth > 7) return "[truncated-depth]";
  if (Array.isArray(value)) {
    return value.slice(0, 300).map((item) => sanitizeToolResultForModel(item, depth + 1));
  }
  if (!value || typeof value !== "object") return value;

  const record = value as Record<string, unknown>;
  const sanitized: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(record)) {
    if (["imageBase64", "base64", "data", "dataUrl", "image_url", "url"].includes(key) && typeof item === "string" && isLargeInlineMediaString(item)) {
      sanitized[key] = `[omitted ${item.length} chars]`;
      continue;
    }
    if (key === "screenshot" && item && typeof item === "object" && !Array.isArray(item)) {
      const screenshot = item as Record<string, unknown>;
      const image = screenshot.image && typeof screenshot.image === "object" && !Array.isArray(screenshot.image)
        ? screenshot.image as Record<string, unknown>
        : null;
      sanitized[key] = {
        ...sanitizeToolResultForModel(screenshot, depth + 1) as Record<string, unknown>,
        image: image
          ? {
              mimeType: image.mimeType,
              width: image.width,
              height: image.height,
              path: image.path,
              filePath: image.filePath,
              imageBase64: typeof image.imageBase64 === "string" ? `[omitted ${image.imageBase64.length} chars]` : undefined,
            }
          : sanitizeToolResultForModel(screenshot.image, depth + 1),
      };
      continue;
    }
    sanitized[key] = sanitizeToolResultForModel(item, depth + 1);
  }
  return sanitized;
}

function formatToolResult(route: ComputerUseRoute, result: Record<string, unknown>) {
  const compact = compactToolResultForModel(route, result);
  return JSON.stringify(compact, null, 2);
}

function compactToolResultForModel(route: ComputerUseRoute, result: Record<string, unknown>) {
  const sanitized = sanitizeToolResultForModel(result) as Record<string, unknown>;
  const base = pickDefined(sanitized, [
    "ok",
    "route",
    "requestId",
    "statusCode",
    "classification",
    "summary",
    "error",
    "failureDomain",
    "needsApproval",
    "needsPermissions",
    "stateToken",
    "preStateToken",
    "postStateToken",
    "contractVersion",
  ]);

  const warnings = compactStringArray(sanitized.warnings, 4, 240);
  if (warnings.length) base.warnings = warnings;
  const recovery = compactStringArray(sanitized.recovery, 4, 240);
  if (recovery.length) base.recovery = recovery;
  const notes = compactStringArray(sanitized.notes, 3, 180);
  if (notes.length) base.notes = notes;

  if (sanitized.app) base.app = compactObject(sanitized.app, ["name", "bundleID", "pid", "launchDate"]);
  if (sanitized.window) base.window = compactObject(sanitized.window, [
    "windowID",
    "title",
    "bundleID",
    "pid",
    "windowNumber",
    "isFocused",
    "isMain",
    "isOnScreen",
    "isMinimized",
    "frameAppKit",
    "resolutionStrategy",
  ]);
  if (Array.isArray(sanitized.apps)) base.apps = sanitized.apps.slice(0, 80).map((app) =>
    compactObject(app, ["name", "bundleID", "pid", "isRunning", "activationPolicy"])
  );
  if (Array.isArray(sanitized.windows)) base.windows = sanitized.windows.slice(0, 80).map((window) =>
    compactObject(window, [
      "windowID",
      "title",
      "bundleID",
      "pid",
      "windowNumber",
      "isFocused",
      "isMain",
      "isOnScreen",
      "isMinimized",
      "frameAppKit",
    ])
  );

  if (sanitized.focusedElement) {
    base.focusedElement = compactObject(sanitized.focusedElement, [
      "index",
      "displayIndex",
      "canonicalIndex",
      "displayRole",
      "role",
      "title",
      "description",
      "valuePreview",
      "secondaryActions",
    ]);
  }
  if (sanitized.selectionSummary) base.selectionSummary = sanitized.selectionSummary;
  if (sanitized.screenshot) base.screenshot = compactScreenshot(sanitized.screenshot);
  if (sanitized.target) base.target = compactObject(sanitized.target, [
    "projectedIndex",
    "displayIndex",
    "canonicalIndex",
    "nodeID",
    "refetchFingerprint",
    "displayRole",
    "title",
    "description",
  ]);
  if (sanitized.cursor) base.cursor = compactObject(sanitized.cursor, [
    "moved",
    "movement",
    "targetPointAppKit",
    "targetPointSource",
    "moveDurationMs",
    "session",
  ]);
  if (sanitized.verification) {
    base.verification = compactObject(sanitized.verification, [
      "expectedOutcome",
      "exactValueMatch",
      "exactSelectionMatch",
      "targetRelocated",
      "refreshedTargetMatchStrategy",
      "verificationNotes",
    ]);
  }

  if (route === "get_window_state" && sanitized.tree && typeof sanitized.tree === "object" && !Array.isArray(sanitized.tree)) {
    const tree = sanitized.tree as Record<string, unknown>;
    const renderedText = typeof tree.renderedText === "string" ? tree.renderedText : null;
    base.tree = {
      renderedText: renderedText ? truncateString(renderedText, 8000) : undefined,
      truncated: renderedText ? renderedText.length > 8000 : undefined,
    };
  }

  if (route !== "get_window_state" && sanitized.postActionObservation && typeof sanitized.postActionObservation === "object") {
    const observation = sanitized.postActionObservation as Record<string, unknown>;
    base.postActionObservation = compactObject(observation, [
      "ok",
      "stateToken",
      "focusedElement",
      "selectionSummary",
      "screenshot",
    ]);
  }

  return removeUndefined(base);
}

function pickDefined(record: Record<string, unknown>, keys: string[]) {
  const picked: Record<string, unknown> = {};
  for (const key of keys) {
    if (record[key] !== undefined) picked[key] = record[key];
  }
  return picked;
}

function compactObject(value: unknown, keys: string[]) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return value;
  return removeUndefined(pickDefined(value as Record<string, unknown>, keys));
}

function compactScreenshot(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return value;
  const screenshot = value as Record<string, unknown>;
  const compact = compactObject(screenshot, ["path", "filePath", "width", "height", "capturedAt", "displayFrame", "image"]);
  if (compact && typeof compact === "object" && !Array.isArray(compact) && "image" in compact) {
    const record = compact as Record<string, unknown>;
    record.image = compactObject(record.image, ["path", "filePath", "width", "height", "mimeType"]);
  }
  return compact;
}

function compactStringArray(value: unknown, maxItems: number, maxChars: number) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === "string" && item.trim().length > 0)
    .slice(0, maxItems)
    .map((item) => truncateString(item, maxChars));
}

function truncateString(value: string, maxChars: number) {
  if (value.length <= maxChars) return value;
  return `${value.slice(0, maxChars)}[truncated ${value.length - maxChars} chars]`;
}

function removeUndefined<T extends Record<string, unknown>>(record: T) {
  for (const key of Object.keys(record)) {
    if (record[key] === undefined) delete record[key];
  }
  return record;
}

function resultSucceeded(result: Record<string, unknown>) {
  return result.ok !== false;
}

function rememberCompletionProof(
  shell: ShellRegistration,
  route: ComputerUseRoute,
  result: Record<string, unknown>,
  sessionKey: string | null | undefined
) {
  const now = Date.now();
  const isMutation = routeIsMutation(route);
  const isObservation = route === "get_window_state";
  const ok = resultSucceeded(result);

  for (const key of completionProofKeys(sessionKey, shell)) {
    const previous = completionProofBySession.get(key);
    completionProofBySession.set(key, {
      lastMutationAt: isMutation ? now : previous?.lastMutationAt ?? null,
      lastMutationRoute: isMutation ? route : previous?.lastMutationRoute ?? null,
      lastObservationAt: isObservation && ok ? now : previous?.lastObservationAt ?? null,
      lastResultOk: ok,
      lastRoute: route,
      lastUpdatedAt: now,
      startedAt: previous?.startedAt ?? now,
    });
  }
}

function findCompletionProof(sessionKey: string | null | undefined, shell: ShellRegistration | null | undefined) {
  const now = Date.now();
  for (const key of completionProofKeys(sessionKey, shell)) {
    const proof = completionProofBySession.get(key);
    if (proof && now - proof.lastUpdatedAt <= completionProofTtlMs) {
      return proof;
    }
  }
  return null;
}

function textClaimsCompletion(text: string) {
  const normalized = text.toLowerCase();
  return /\b(done|completed|finished|opened|typed|created|wrote|filled|drafted|ready)\b/.test(normalized) &&
    !/\b(can'?t|cannot|could not|unable|failed|did not|didn'?t|not able|not yet|still need)\b/.test(normalized);
}

function validatePresentationAgainstCompletionProof(
  params: unknown,
  sessionKey: string | null | undefined,
  shell: ShellRegistration | null | undefined
) {
  if (!params || typeof params !== "object" || Array.isArray(params)) return null;
  const spokenText = parseString((params as Record<string, unknown>).spokenText);
  if (!spokenText || !textClaimsCompletion(spokenText)) return null;

  const proof = findCompletionProof(sessionKey, shell);
  if (!proof) return null;
  if (proof.lastResultOk === false) {
    return "clicky_present cannot claim completion because the latest computer-use runtime result failed. Explain the failure or recover with observe-act-observe.";
  }
  if (proof.lastMutationAt && (!proof.lastObservationAt || proof.lastObservationAt < proof.lastMutationAt)) {
    return "clicky_present cannot claim completion yet. Call get_window_state after the latest computer-use action, inspect the runtime state, then present the verified result.";
  }
  return null;
}

function resolveWaitingPollForRequest(request: QueuedComputerUseRequest) {
  const pollIndex = waitingPolls.findIndex((poll) =>
    poll.shellId === request.shellId &&
    (!poll.sessionKey || !request.sessionKey || sessionKeysMatch(poll.sessionKey, request.sessionKey))
  );
  if (pollIndex < 0) return false;

  const [poll] = waitingPolls.splice(pollIndex, 1);
  clearTimeout(poll.timeout);
  poll.respond(true, {
    ok: true,
    request: {
      payload: request.payload,
      requestId: request.requestId,
      route: request.route,
      statusText: humanRouteLabel(request.route),
    },
  });
  return true;
}

function queueComputerUseRequest(
  shell: ShellRegistration,
  route: ComputerUseRoute,
  payload: Record<string, unknown>
) {
  const requestId = `cu_${Date.now()}_${Math.random().toString(36).slice(2)}`;

  return new Promise<Record<string, unknown>>((resolve) => {
    const timeout = setTimeout(() => {
      pendingComputerUseRequests.delete(requestId);
      resolve({
        ok: false,
        error: "Clicky did not return a computer-use result before the tool timed out.",
        recovery: ["Make sure the Clicky app is running and connected to this OpenClaw session."],
        requestId,
        route,
      });
    }, 300_000);

    const request: QueuedComputerUseRequest = {
      createdAt: Date.now(),
      payload,
      requestId,
      resolve,
      route,
      sessionKey: shell.sessionKey,
      shellId: shell.shellId,
      timeout,
    };
    pendingComputerUseRequests.set(requestId, request);
    resolveWaitingPollForRequest(request);
  });
}

function takeNextRequest(shellId: string, sessionKey: string | null) {
  const matches = [...pendingComputerUseRequests.values()]
    .filter((request) =>
      request.shellId === shellId &&
      (!sessionKey || !request.sessionKey || sessionKeysMatch(sessionKey, request.sessionKey))
    )
    .sort((left, right) => left.createdAt - right.createdAt);
  return matches[0] ?? null;
}

function buildPresentationReply(params: unknown) {
  if (!params || typeof params !== "object" || Array.isArray(params)) {
    return { ok: false as const, error: "clicky_present parameters must be a JSON object." };
  }
  const record = params as Record<string, unknown>;
  const mode = parseString(record.mode) as PresentationMode | null;
  const spokenText = parseString(record.spokenText);
  const points = Array.isArray(record.points) ? record.points : [];
  if (!mode || !["answer", "point", "walkthrough", "tutorial"].includes(mode)) {
    return { ok: false as const, error: "mode must be answer, point, walkthrough, or tutorial." };
  }
  if (!spokenText) {
    return { ok: false as const, error: "spokenText is required." };
  }
  const reply = { mode, spokenText, points };
  return { ok: true as const, reply, replyText: JSON.stringify(reply) };
}

function makeRuntimeTool(route: ComputerUseRoute, api: any, ctx: any) {
  return {
    name: route,
    description: `${runtimeToolDescription(route)} Executes through Clicky's local BackgroundComputerUse runtime. Use observe-act-observe: observe before actions and observe again after actions.`,
    parameters: runtimeToolParameters(route),
    async execute(_toolCallId: string, params: unknown) {
      const validation = validatePayload(route, params);
      if (!validation.ok) {
        return { content: [{ type: "text", text: validation.error }], isError: true };
      }

      const normalizedConfig = normalizePluginConfig(api.pluginConfig);
      const shell = findFreshShell(ctx?.sessionKey, normalizedConfig.registrationTtlMs);
      if (!shell) {
        return {
          content: [{ type: "text", text: "No fresh Clicky desktop shell is connected for computer use." }],
          isError: true,
          structuredContent: { ok: false, error: "no_fresh_clicky_shell", route },
        };
      }

      api.logger.info(`clicky-shell: computer_use route=${route} shell=${shell.shellId}`);
      const result = await queueComputerUseRequest(shell, route, validation.payload);
      rememberCompletionProof(shell, route, result, ctx?.sessionKey);
      const sanitizedResult = compactToolResultForModel(route, result) as Record<string, unknown>;
      const content: Record<string, string>[] = [{ type: "text", text: formatToolResult(route, result) }];
      return {
        content,
        structuredContent: sanitizedResult,
        isError: result.ok === false,
      };
    },
  };
}

export default definePluginEntry({
  id: "clicky-shell",
  name: "Clicky Shell",
  description: "Connects OpenClaw to the Clicky desktop shell.",
  configSchema: {
    type: "object",
    additionalProperties: false,
    properties: {
      shellLabel: { type: "string" },
      registrationTtlMs: { type: "integer", minimum: 5000, maximum: 300000 },
      allowRemoteDesktopShell: { type: "boolean" },
    },
  },
  register(api) {
    api.registerGatewayMethod("clicky.status", async ({ respond }) => {
      respond(true, {
        registrations: [...registrationsByShellId.values()].map((registration) =>
          serializeRegistration(registration, normalizePluginConfig(api.pluginConfig).registrationTtlMs)
        ),
        summary: statusSummary(api.pluginConfig, true),
      });
    }, { scope: "operator.read" });

    api.registerGatewayMethod("clicky.shell.register", async ({ params, respond }) => {
      const registration = parseShellRegistration(params);
      if (!registration) {
        respond(false, { error: "shellId required" });
        return;
      }
      const config = normalizePluginConfig(api.pluginConfig);
      if (registration.shellTransportScope === "remote-gateway" && !config.allowRemoteDesktopShell) {
        respond(false, { error: "remote Clicky shells are not allowed" });
        return;
      }
      registrationsByShellId.set(registration.shellId, registration);
      respond(true, {
        ok: true,
        registration: serializeRegistration(registration, config.registrationTtlMs),
        shellId: registration.shellId,
        summary: statusSummary(api.pluginConfig, true),
      });
    }, { scope: "operator.write" });

    api.registerGatewayMethod("clicky.shell.heartbeat", async ({ params, respond }) => {
      const shellId = params && typeof params === "object" ? parseString((params as Record<string, unknown>).shellId) : null;
      const registration = shellId ? registrationsByShellId.get(shellId) : null;
      if (!shellId || !registration) {
        respond(false, { error: "shell not registered" });
        return;
      }
      registration.lastHeartbeatAt = Date.now();
      registrationsByShellId.set(shellId, registration);
      respond(true, { ok: true, shellId });
    }, { scope: "operator.write" });

    api.registerGatewayMethod("clicky.shell.set_prompt_context", async ({ params, respond }) => {
      const record = params && typeof params === "object" ? params as Record<string, unknown> : {};
      const shellId = parseString(record.shellId);
      const registration = shellId ? registrationsByShellId.get(shellId) : null;
      const promptContext = parseString(record.promptContext);
      if (!shellId || !registration || !promptContext) {
        respond(false, { error: "shellId and promptContext required" });
        return;
      }
      registration.promptContext = promptContext;
      registration.sessionKey = parseString(record.sessionKey) ?? registration.sessionKey;
      registration.lastHeartbeatAt = Date.now();
      registrationsByShellId.set(shellId, registration);
      respond(true, { ok: true, shellId });
    }, { scope: "operator.write" });

    api.registerGatewayMethod("clicky.shell.status", async ({ params, respond }) => {
      const shellId = params && typeof params === "object" ? parseString((params as Record<string, unknown>).shellId) : null;
      const registration = shellId ? registrationsByShellId.get(shellId) : null;
      respond(true, {
        found: Boolean(registration),
        registration: registration
          ? serializeRegistration(registration, normalizePluginConfig(api.pluginConfig).registrationTtlMs)
          : null,
        shellId,
        summary: statusSummary(api.pluginConfig, true),
      });
    }, { scope: "operator.read" });

    api.registerGatewayMethod("clicky.shell.bind_session", async ({ params, respond }) => {
      const record = params && typeof params === "object" ? params as Record<string, unknown> : {};
      const shellId = parseString(record.shellId);
      const registration = shellId ? registrationsByShellId.get(shellId) : null;
      if (!shellId || !registration) {
        respond(false, { error: "shell not registered" });
        return;
      }
      registration.sessionKey = parseString(record.sessionKey);
      registration.promptContext = null;
      registration.lastHeartbeatAt = Date.now();
      registrationsByShellId.set(shellId, registration);
      respond(true, {
        ok: true,
        registration: serializeRegistration(registration, normalizePluginConfig(api.pluginConfig).registrationTtlMs),
        shellId,
        summary: statusSummary(api.pluginConfig, true),
      });
    }, { scope: "operator.write" });

    api.registerGatewayMethod("clicky.shell.next_computer_use_action", async ({ params, respond }) => {
      const record = params && typeof params === "object" ? params as Record<string, unknown> : {};
      const shellId = parseString(record.shellId);
      const sessionKey = parseString(record.sessionKey);
      const timeoutMs = typeof record.timeoutMs === "number"
        ? Math.max(250, Math.min(25_000, Math.floor(record.timeoutMs)))
        : 20_000;
      if (!shellId) {
        respond(false, { error: "shellId required" });
        return;
      }
      const request = takeNextRequest(shellId, sessionKey);
      if (request) {
        respond(true, {
          ok: true,
          request: {
            payload: request.payload,
            requestId: request.requestId,
            route: request.route,
            statusText: humanRouteLabel(request.route),
          },
        });
        return;
      }

      const poll: WaitingPoll = {
        deadline: Date.now() + timeoutMs,
        respond,
        sessionKey,
        shellId,
        timeout: setTimeout(() => {
          const index = waitingPolls.indexOf(poll);
          if (index >= 0) waitingPolls.splice(index, 1);
          respond(true, { ok: true, request: null });
        }, timeoutMs),
      };
      waitingPolls.push(poll);
    }, { scope: "operator.write" });

    api.registerGatewayMethod("clicky.shell.complete_computer_use_action", async ({ params, respond }) => {
      const record = params && typeof params === "object" ? params as Record<string, unknown> : {};
      const requestId = parseString(record.requestId);
      const request = requestId ? pendingComputerUseRequests.get(requestId) : null;
      if (!requestId || !request) {
        respond(false, { error: "computer-use request not found" });
        return;
      }
      pendingComputerUseRequests.delete(requestId);
      clearTimeout(request.timeout);
      const result = record.result && typeof record.result === "object" && !Array.isArray(record.result)
        ? record.result as Record<string, unknown>
        : { ok: false, error: "Clicky returned an invalid computer-use result." };
      request.resolve({
        ...result,
        requestId,
        route: request.route,
      });
      respond(true, { ok: true, requestId });
    }, { scope: "operator.write" });

    api.registerCommand({
      name: "clicky",
      description: "Show Clicky shell integration status.",
      acceptsArgs: false,
      requireAuth: false,
      handler: async () => ({ text: statusSummary(api.pluginConfig, true) }),
    });

    api.registerTool({
      name: "clicky_status",
      description: "Inspect whether a Clicky desktop shell is connected.",
      parameters: statusToolParameters,
      async execute(_toolCallId, params) {
        return {
          content: [{ type: "text", text: statusSummary(api.pluginConfig, params?.includeRegistrations !== false) }],
        };
      },
    });

    api.registerTool((ctx) => ({
      name: "clicky_present",
      description: "Finish a Clicky turn in answer, point, walkthrough, or tutorial mode.",
      parameters: presentToolParameters,
      async execute(_toolCallId, params) {
        const normalized = normalizePluginConfig(api.pluginConfig);
        const shell = findFreshShell(ctx?.sessionKey, normalized.registrationTtlMs);
        const completionError = validatePresentationAgainstCompletionProof(params, ctx?.sessionKey, shell);
        if (completionError) {
          return { content: [{ type: "text", text: completionError }], isError: true };
        }

        const result = buildPresentationReply(params);
        if (!result.ok) {
          return { content: [{ type: "text", text: result.error }], isError: true };
        }
        return {
          content: [{
            type: "text",
            text: [
              "Clicky presentation accepted.",
              "For the final assistant message, output exactly this JSON object and nothing else:",
              result.replyText,
            ].join("\n"),
          }],
          structuredContent: result.reply,
        };
      },
    }), { names: ["clicky_present"] });

    for (const route of computerUseRoutes) {
      api.registerTool((ctx) => makeRuntimeTool(route, api, ctx), { names: [route] });
    }

    api.on("before_prompt_build", async (_event, ctx) => {
      const normalized = normalizePluginConfig(api.pluginConfig);
      const shell = findFreshShell(ctx.sessionKey, normalized.registrationTtlMs);
      if (!shell) return;
      const context = shell.promptContext?.trim()
        ? `${shell.promptContext.trim()}\n\n${buildPromptInstructions()}`
        : buildPromptInstructions();
      return { prependSystemContext: context };
    });
  },
});
