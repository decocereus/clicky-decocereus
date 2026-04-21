import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

type ClickyShellRegistration = {
  agentIdentityName: string | null;
  bridgeVersion: string | null;
  clickyShellCapabilityVersion: string | null;
  capabilities: string[];
  clickyPresentationName: string | null;
  cursorPointingProtocol: string | null;
  lastHeartbeatAt: number;
  personaScope: "clicky-local-override" | "openclaw-identity";
  registeredAt: number;
  runtimeMode: string | null;
  screenContextTransport: string | null;
  sessionKey: string | null;
  shellId: string;
  shellLabel: string | null;
  shellProtocolVersion: string | null;
  shellTransportScope: "local-gateway" | "remote-gateway";
  speechOutputMode: string | null;
  supportsInlineTextBubble: boolean;
  promptContext: string | null;
};

type ClickyShellFreshnessState = "fresh" | "stale";
type ClickyShellTrustState = "trusted-local" | "trusted-remote";
type ClickyPresentationMode = "answer" | "point" | "walkthrough" | "tutorial";

type ClickyStructuredPoint = {
  x: number;
  y: number;
  label: string;
  bubbleText?: string;
  explanation?: string;
  screenNumber?: number;
};

type ClickyStructuredReply = {
  spokenText: string;
  points: ClickyStructuredPoint[];
};

type ClickyPresentationReply = ClickyStructuredReply & {
  mode: ClickyPresentationMode;
};

function freshnessStateForRegistration(
  registration: ClickyShellRegistration,
  registrationTtlMs: number
): ClickyShellFreshnessState {
  return Date.now() - registration.lastHeartbeatAt <= registrationTtlMs ? "fresh" : "stale";
}

function trustStateForRegistration(registration: ClickyShellRegistration): ClickyShellTrustState {
  return registration.shellTransportScope === "local-gateway" ? "trusted-local" : "trusted-remote";
}

function sessionBindingStateForRegistration(registration: ClickyShellRegistration) {
  return registration.sessionKey ? "bound" : "unbound";
}

function candidateSessionKeys(sessionKey: string | null | undefined) {
  if (!sessionKey) return [];

  const trimmedSessionKey = sessionKey.trim();
  if (!trimmedSessionKey) return [];

  const candidates = new Set<string>([trimmedSessionKey]);
  const segments = trimmedSessionKey.split(":");

  // Runtime hooks often see session keys in the internal form
  // "agent:<agentId>:<userSessionKey>", while Clicky binds the shorter
  // user-facing key. Treat both as the same session binding target.
  if (segments.length >= 3 && segments[0] === "agent") {
    const userSessionKey = segments.slice(2).join(":");
    candidates.add(userSessionKey);

    if (segments[2] === "explicit" && segments.length >= 4) {
      candidates.add(segments.slice(3).join(":"));
    }
  }

  if (segments[0] === "explicit" && segments.length >= 2) {
    candidates.add(segments.slice(1).join(":"));
  }

  return [...candidates];
}

function sessionKeysMatch(leftSessionKey: string | null | undefined, rightSessionKey: string | null | undefined) {
  const leftCandidates = candidateSessionKeys(leftSessionKey);
  const rightCandidates = new Set(candidateSessionKeys(rightSessionKey));

  return leftCandidates.some((candidate) => rightCandidates.has(candidate));
}

function findFreshShellRegistrationForSessionKey(
  sessionKey: string | undefined,
  registrationTtlMs: number
) {
  if (!sessionKey) return null;

  const registrations = [...clickyShellRegistrationsById.values()]
    .filter((registration) => sessionKeysMatch(registration.sessionKey, sessionKey))
    .sort((leftRegistration, rightRegistration) => rightRegistration.lastHeartbeatAt - leftRegistration.lastHeartbeatAt);

  const freshestRegistration = registrations[0] ?? null;
  if (!freshestRegistration) return null;

  return freshnessStateForRegistration(freshestRegistration, registrationTtlMs) === "fresh"
    ? freshestRegistration
    : null;
}

function buildClickyPresentationPromptInstructions() {
  return [
    "clicky presentation tools:",
    "- finish clicky turns with the clicky_present tool whenever possible.",
    "- use clicky_present mode answer for spoken guidance with no pointing.",
    "- use clicky_present mode point for one grounded target with one detailed explanation.",
    "- use clicky_present mode walkthrough for multiple grounded targets with an explanation on each point.",
    "- use clicky_present mode tutorial for richer guided sequences that still need ordered point explanations.",
    "- after clicky_present returns, output exactly the JSON object from the tool result as the final assistant message and nothing else.",
    "- if tool use is unavailable, return clicky's structured response contract with ordered point targets.",
  ].join("\n");
}

function buildClickyShellPromptContext(
  registration: ClickyShellRegistration
) {
  const promptContext =
    typeof registration.promptContext === "string" && registration.promptContext.trim()
      ? registration.promptContext.trim()
      : null;

  if (promptContext) {
    return `${promptContext}\n\n${buildClickyPresentationPromptInstructions()}`;
  }

  return [
    "clicky shell is active for this run.",
    `upstream agent identity: ${registration.agentIdentityName ?? "unknown"}.`,
    `clicky-local presentation: ${registration.clickyPresentationName ?? registration.agentIdentityName ?? "unknown"}.`,
    `persona scope: ${registration.personaScope}.`,
    `shell capabilities: ${registration.capabilities.join(", ") || "none"}.`,
    `screen context transport: ${registration.screenContextTransport ?? "unknown"}.`,
    `cursor pointing protocol: ${registration.cursorPointingProtocol ?? "unknown"}.`,
    `speech output mode: ${registration.speechOutputMode ?? "unknown"}.`,
    buildClickyPresentationPromptInstructions(),
  ].join(" ");
}

function extractNonEmptyString(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function extractInteger(value: unknown) {
  return typeof value === "number" && Number.isInteger(value) ? value : null;
}

function extractClickyPoint(point: unknown): ClickyStructuredPoint | null {
  if (!point || typeof point !== "object" || Array.isArray(point)) {
    return null;
  }

  const pointRecord = point as Record<string, unknown>;
  const x = extractInteger(pointRecord.x);
  const y = extractInteger(pointRecord.y);
  const label = extractNonEmptyString(pointRecord.label);

  if (x === null || y === null || !label) {
    return null;
  }

  const bubbleText = extractNonEmptyString(pointRecord.bubbleText) ?? undefined;
  const explanation = extractNonEmptyString(pointRecord.explanation) ?? undefined;
  const screenNumber = extractInteger(pointRecord.screenNumber);

  return {
    x,
    y,
    label,
    bubbleText,
    explanation,
    screenNumber: screenNumber && screenNumber > 0 ? screenNumber : undefined,
  };
}

function presentationModeRequiresPoints(mode: ClickyPresentationMode) {
  return mode !== "answer";
}

function presentationModeRequiresPointExplanations(mode: ClickyPresentationMode) {
  return mode !== "answer";
}

function buildClickyPresentationReply(params: unknown) {
  if (!params || typeof params !== "object" || Array.isArray(params)) {
    return {
      ok: false as const,
      error: "clicky_present parameters were missing or invalid",
    };
  }

  const paramsRecord = params as Record<string, unknown>;
  const mode = extractNonEmptyString(paramsRecord.mode);
  const spokenText = extractNonEmptyString(paramsRecord.spokenText);

  if (!mode || !["answer", "point", "walkthrough", "tutorial"].includes(mode)) {
    return {
      ok: false as const,
      error: "clicky_present mode must be one of: answer, point, walkthrough, tutorial",
    };
  }

  if (!spokenText) {
    return {
      ok: false as const,
      error: "clicky_present spokenText was empty",
    };
  }

  const points = Array.isArray(paramsRecord.points)
    ? paramsRecord.points
        .map((point) => extractClickyPoint(point))
        .filter((point): point is ClickyStructuredPoint => point !== null)
    : [];

  const presentationReply: ClickyPresentationReply = {
    mode: mode as ClickyPresentationMode,
    spokenText,
    points,
  };

  const validationIssues = validateStructuredReply(
    presentationReply,
    presentationModeRequiresPoints(presentationReply.mode),
    presentationModeRequiresPointExplanations(presentationReply.mode)
  );

  if (presentationReply.mode === "answer" && presentationReply.points.length > 0) {
    validationIssues.push("clicky_present answer mode must not include points");
  }

  if (presentationReply.mode === "point" && presentationReply.points.length !== 1) {
    validationIssues.push("clicky_present point mode must include exactly one point");
  }

  if (presentationReply.mode === "walkthrough" && presentationReply.points.length < 2) {
    validationIssues.push("clicky_present walkthrough mode must include at least two points");
  }

  if (presentationReply.mode === "tutorial" && presentationReply.points.length < 1) {
    validationIssues.push("clicky_present tutorial mode must include at least one point");
  }

  if (validationIssues.length > 0) {
    return {
      ok: false as const,
      error: validationIssues.join("; "),
    };
  }

  return {
    ok: true as const,
    reply: presentationReply,
    replyText: JSON.stringify(presentationReply),
  };
}

function validateStructuredReply(
  structuredReply: ClickyStructuredReply,
  requiresPoints: boolean,
  requiresPointExplanations: boolean
) {
  const issues: string[] = [];

  if (typeof structuredReply.spokenText !== "string" || !structuredReply.spokenText.trim()) {
    issues.push("spokenText was empty");
  }

  if (!Array.isArray(structuredReply.points)) {
    issues.push("points was not an array");
    return issues;
  }

  if (requiresPoints && structuredReply.points.length === 0) {
    issues.push("points array was empty even though the request required pointing");
  }

  structuredReply.points.forEach((point, index) => {
    if (typeof point?.x !== "number" || !Number.isFinite(point.x)) {
      issues.push(`point ${index + 1} was missing a valid x coordinate`);
    }
    if (typeof point?.y !== "number" || !Number.isFinite(point.y)) {
      issues.push(`point ${index + 1} was missing a valid y coordinate`);
    }
    if (typeof point?.label !== "string" || !point.label.trim()) {
      issues.push(`point ${index + 1} was missing a label`);
    }

    if (requiresPointExplanations) {
      const explanation = typeof point?.explanation === "string" ? point.explanation.trim() : "";
      if (!explanation) {
        issues.push(`point ${index + 1} was missing an explanation`);
      }
    }
  });

  return issues;
}

function serializeShellRegistration(
  registration: ClickyShellRegistration,
  registrationTtlMs: number = defaultRegistrationTtlMs
) {
  return {
    agentIdentityName: registration.agentIdentityName,
    bridgeVersion: registration.bridgeVersion,
    clickyShellCapabilityVersion: registration.clickyShellCapabilityVersion,
    capabilities: registration.capabilities,
    clickyPresentationName: registration.clickyPresentationName,
    cursorPointingProtocol: registration.cursorPointingProtocol,
    lastHeartbeatAt: registration.lastHeartbeatAt,
    personaScope: registration.personaScope,
    registeredAt: registration.registeredAt,
    runtimeMode: registration.runtimeMode,
    screenContextTransport: registration.screenContextTransport,
    sessionKey: registration.sessionKey,
    shellId: registration.shellId,
    shellLabel: registration.shellLabel,
    shellProtocolVersion: registration.shellProtocolVersion,
    shellTransportScope: registration.shellTransportScope,
    speechOutputMode: registration.speechOutputMode,
    supportsInlineTextBubble: registration.supportsInlineTextBubble,
    freshnessState: freshnessStateForRegistration(registration, registrationTtlMs),
    trustState: trustStateForRegistration(registration),
    sessionBindingState: sessionBindingStateForRegistration(registration),
  };
}

const clickyShellRegistrationsById = new Map<string, ClickyShellRegistration>();
const defaultRegistrationTtlMs = 60_000;

// OpenClaw accepts plain JSON Schema objects for tool parameters here, which
// keeps this local source plugin self-contained when it is loaded in place.
const clickyStatusToolParameters = {
  type: "object",
  additionalProperties: false,
  properties: {
    includeRegistrations: {
      type: "boolean",
    },
  },
} as const;

const clickyPresentToolParameters = {
  type: "object",
  additionalProperties: false,
  required: ["mode", "spokenText", "points"],
  properties: {
    mode: {
      type: "string",
      enum: ["answer", "point", "walkthrough", "tutorial"],
    },
    spokenText: {
      type: "string",
      description: "The spoken intro or full answer text for this Clicky turn.",
    },
    points: {
      type: "array",
      description: "Ordered Clicky point targets. Leave empty for answer mode.",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["x", "y", "label"],
        properties: {
          x: {
            type: "integer",
          },
          y: {
            type: "integer",
          },
          label: {
            type: "string",
          },
          bubbleText: {
            type: "string",
          },
          explanation: {
            type: "string",
          },
          screenNumber: {
            type: "integer",
            minimum: 1,
          },
        },
      },
    },
  },
} as const;

function normalizePluginConfig(pluginConfig: Record<string, unknown>) {
  const shellLabel =
    typeof pluginConfig.shellLabel === "string" && pluginConfig.shellLabel.trim()
      ? pluginConfig.shellLabel.trim()
      : "Clicky";

  const registrationTtlMs =
    typeof pluginConfig.registrationTtlMs === "number" && Number.isFinite(pluginConfig.registrationTtlMs)
      ? Math.max(5_000, Math.min(300_000, Math.floor(pluginConfig.registrationTtlMs)))
      : defaultRegistrationTtlMs;

  const allowRemoteDesktopShell = pluginConfig.allowRemoteDesktopShell === true;

  return {
    allowRemoteDesktopShell,
    registrationTtlMs,
    shellLabel,
  };
}

function pruneExpiredShellRegistrations(registrationTtlMs: number) {
  const now = Date.now();

  for (const [shellId, registration] of clickyShellRegistrationsById.entries()) {
    if (now - registration.lastHeartbeatAt > registrationTtlMs) {
      clickyShellRegistrationsById.delete(shellId);
    }
  }
}

function formatStatusSummary(pluginConfig: Record<string, unknown>, includeRegistrations: boolean) {
  const normalizedPluginConfig = normalizePluginConfig(pluginConfig);
  const registrations = [...clickyShellRegistrationsById.values()].sort(
    (leftRegistration, rightRegistration) => rightRegistration.lastHeartbeatAt - leftRegistration.lastHeartbeatAt
  );

  const summaryLines = [
    `clicky shell label: ${normalizedPluginConfig.shellLabel}`,
    `remote desktop shells: ${normalizedPluginConfig.allowRemoteDesktopShell ? "allowed" : "local-first"}`,
    `registration ttl: ${normalizedPluginConfig.registrationTtlMs}ms`,
    `active shells: ${registrations.length}`,
  ];

  if (includeRegistrations && registrations.length > 0) {
    for (const registration of registrations) {
      const freshnessState = freshnessStateForRegistration(registration, normalizedPluginConfig.registrationTtlMs);
      const trustState = trustStateForRegistration(registration);
      const sessionBindingState = sessionBindingStateForRegistration(registration);
      summaryLines.push(
        `- ${registration.shellId} agent=${registration.agentIdentityName ?? "unknown"} clicky=${registration.clickyPresentationName ?? registration.agentIdentityName ?? "unknown"} scope=${registration.personaScope} trust=${trustState} freshness=${freshnessState} binding=${sessionBindingState} session=${registration.sessionKey ?? "none"} capabilities=${registration.capabilities.join(", ") || "none"}`
      );
    }
  }

  if (includeRegistrations && registrations.length === 0) {
    summaryLines.push("- no Clicky shells registered yet");
  }

  return summaryLines.join("\n");
}

function parseShellRegistration(params: unknown): ClickyShellRegistration | null {
  if (typeof params !== "object" || params === null || Array.isArray(params)) {
    return null;
  }

  const record = params as Record<string, unknown>;
  const shellId = typeof record.shellId === "string" ? record.shellId.trim() : "";
  if (!shellId) return null;

  return {
    agentIdentityName: typeof record.agentIdentityName === "string" && record.agentIdentityName.trim() ? record.agentIdentityName.trim() : null,
    bridgeVersion: typeof record.bridgeVersion === "string" && record.bridgeVersion.trim() ? record.bridgeVersion.trim() : null,
    clickyShellCapabilityVersion: typeof record.clickyShellCapabilityVersion === "string" && record.clickyShellCapabilityVersion.trim() ? record.clickyShellCapabilityVersion.trim() : null,
    capabilities: Array.isArray(record.capabilities)
      ? record.capabilities.filter((capability): capability is string => typeof capability === "string").map((capability) => capability.trim()).filter(Boolean)
      : [],
    clickyPresentationName: typeof record.clickyPresentationName === "string" && record.clickyPresentationName.trim() ? record.clickyPresentationName.trim() : null,
    cursorPointingProtocol: typeof record.cursorPointingProtocol === "string" && record.cursorPointingProtocol.trim() ? record.cursorPointingProtocol.trim() : null,
    lastHeartbeatAt: Date.now(),
    personaScope:
      record.personaScope === "clicky-local-override"
        ? "clicky-local-override"
        : "openclaw-identity",
    registeredAt:
      typeof record.registeredAt === "number" && Number.isFinite(record.registeredAt)
        ? Math.floor(record.registeredAt)
        : Date.now(),
    runtimeMode: typeof record.runtimeMode === "string" && record.runtimeMode.trim() ? record.runtimeMode.trim() : null,
    screenContextTransport: typeof record.screenContextTransport === "string" && record.screenContextTransport.trim() ? record.screenContextTransport.trim() : null,
    sessionKey: typeof record.sessionKey === "string" && record.sessionKey.trim() ? record.sessionKey.trim() : null,
    shellId,
    shellLabel: typeof record.shellLabel === "string" && record.shellLabel.trim() ? record.shellLabel.trim() : null,
    shellProtocolVersion: typeof record.shellProtocolVersion === "string" && record.shellProtocolVersion.trim() ? record.shellProtocolVersion.trim() : null,
    shellTransportScope: record.shellTransportScope === "remote-gateway" ? "remote-gateway" : "local-gateway",
    speechOutputMode: typeof record.speechOutputMode === "string" && record.speechOutputMode.trim() ? record.speechOutputMode.trim() : null,
    supportsInlineTextBubble: record.supportsInlineTextBubble === true,
    promptContext: null,
  };
}

function readShellIdFromParams(params: unknown): string {
  if (typeof params !== "object" || params === null || Array.isArray(params)) {
    return "";
  }

  const shellId = typeof (params as Record<string, unknown>).shellId === "string"
    ? (params as Record<string, unknown>).shellId.trim()
    : "";

  return shellId;
}

export default definePluginEntry({
  id: "clicky-shell",
  name: "Clicky Shell",
  description: "Connects OpenClaw to the Clicky desktop shell.",
  configSchema: {
    type: "object",
    additionalProperties: false,
    properties: {
      shellLabel: {
        type: "string",
      },
      registrationTtlMs: {
        type: "integer",
        minimum: 5000,
        maximum: 300000,
      },
      allowRemoteDesktopShell: {
        type: "boolean",
      },
    },
  },
  register(api) {
    api.registerGatewayMethod(
      "clicky.status",
      async ({ respond }) => {
        try {
          pruneExpiredShellRegistrations(normalizePluginConfig(api.pluginConfig).registrationTtlMs);
          const summary = formatStatusSummary(api.pluginConfig, true);
          respond(true, {
            activeShellCount: clickyShellRegistrationsById.size,
            registrations: [...clickyShellRegistrationsById.values()].map((registration) =>
              serializeShellRegistration(registration, normalizePluginConfig(api.pluginConfig).registrationTtlMs)
            ),
            summary,
          });
        } catch (error) {
          respond(false, { error: error instanceof Error ? error.message : String(error) });
        }
      },
      { scope: "operator.read" }
    );

    api.registerGatewayMethod(
      "clicky.shell.register",
      async ({ params, respond }) => {
        try {
          const normalizedPluginConfig = normalizePluginConfig(api.pluginConfig);
          const shellRegistration = parseShellRegistration(params);
          if (!shellRegistration) {
            respond(false, { error: "shellId required" });
            return;
          }

          if (shellRegistration.shellTransportScope === "remote-gateway" && !normalizedPluginConfig.allowRemoteDesktopShell) {
            respond(false, { error: "remote clicky shells are not allowed by current plugin policy" });
            return;
          }

          clickyShellRegistrationsById.set(shellRegistration.shellId, shellRegistration);
          respond(true, {
            ok: true,
            registration: {
              ...serializeShellRegistration(shellRegistration, normalizedPluginConfig.registrationTtlMs),
              freshnessState: freshnessStateForRegistration(shellRegistration, normalizedPluginConfig.registrationTtlMs),
            },
            shellId: shellRegistration.shellId,
            summary: formatStatusSummary(api.pluginConfig, true),
          });
        } catch (error) {
          respond(false, { error: error instanceof Error ? error.message : String(error) });
        }
      },
      { scope: "operator.write" }
    );

    api.registerGatewayMethod(
      "clicky.shell.heartbeat",
      async ({ params, respond }) => {
        try {
          const normalizedPluginConfig = normalizePluginConfig(api.pluginConfig);
          const shellId = readShellIdFromParams(params);

          if (!shellId) {
            respond(false, { error: "shellId required" });
            return;
          }

          const existingRegistration = clickyShellRegistrationsById.get(shellId);
          if (!existingRegistration) {
            respond(false, { error: "shell not registered" });
            return;
          }

          existingRegistration.lastHeartbeatAt = Date.now();
          clickyShellRegistrationsById.set(shellId, existingRegistration);
          respond(true, {
            ok: true,
            registration: {
              ...serializeShellRegistration(existingRegistration, normalizedPluginConfig.registrationTtlMs),
              freshnessState: freshnessStateForRegistration(existingRegistration, normalizedPluginConfig.registrationTtlMs),
            },
            shellId,
          });
        } catch (error) {
          respond(false, { error: error instanceof Error ? error.message : String(error) });
        }
      },
      { scope: "operator.write" }
    );

    api.registerGatewayMethod(
      "clicky.shell.set_prompt_context",
      async ({ params, respond }) => {
        try {
          const shellId = readShellIdFromParams(params);
          if (!shellId) {
            respond(false, { error: "shellId required" });
            return;
          }

          const existingRegistration = clickyShellRegistrationsById.get(shellId);
          if (!existingRegistration) {
            respond(false, { error: "shell not registered" });
            return;
          }

          const promptContext =
            typeof (params as Record<string, unknown>).promptContext === "string" &&
            (params as Record<string, unknown>).promptContext.trim()
              ? (params as Record<string, unknown>).promptContext.trim()
              : null;

          if (!promptContext) {
            respond(false, { error: "promptContext required" });
            return;
          }

          const sessionKey =
            typeof (params as Record<string, unknown>).sessionKey === "string" &&
            (params as Record<string, unknown>).sessionKey.trim()
              ? (params as Record<string, unknown>).sessionKey.trim()
              : existingRegistration.sessionKey;

          existingRegistration.promptContext = promptContext;
          existingRegistration.sessionKey = sessionKey;
          existingRegistration.lastHeartbeatAt = Date.now();
          clickyShellRegistrationsById.set(shellId, existingRegistration);

          respond(true, {
            ok: true,
            shellId,
          });
        } catch (error) {
          respond(false, { error: error instanceof Error ? error.message : String(error) });
        }
      },
      { scope: "operator.write" }
    );

    api.registerGatewayMethod(
      "clicky.shell.status",
      async ({ params, respond }) => {
        try {
          const normalizedPluginConfig = normalizePluginConfig(api.pluginConfig);
          const shellId = readShellIdFromParams(params);
          if (!shellId) {
            respond(true, {
              found: false,
              summary: formatStatusSummary(api.pluginConfig, true),
            });
            return;
          }

          const existingRegistration = clickyShellRegistrationsById.get(shellId);
          if (!existingRegistration) {
            respond(true, {
              found: false,
              shellId,
              summary: formatStatusSummary(api.pluginConfig, true),
            });
            return;
          }

          respond(true, {
            found: true,
            registration: {
              ...serializeShellRegistration(existingRegistration, normalizedPluginConfig.registrationTtlMs),
              freshnessState: freshnessStateForRegistration(existingRegistration, normalizedPluginConfig.registrationTtlMs),
              trustState: trustStateForRegistration(existingRegistration),
              sessionBindingState: sessionBindingStateForRegistration(existingRegistration),
            },
            shellId,
            summary: formatStatusSummary(api.pluginConfig, true),
          });
        } catch (error) {
          respond(false, { error: error instanceof Error ? error.message : String(error) });
        }
      },
      { scope: "operator.read" }
    );

    api.registerGatewayMethod(
      "clicky.shell.bind_session",
      async ({ params, respond }) => {
        try {
          const shellId = readShellIdFromParams(params);
          if (!shellId) {
            respond(false, { error: "shellId required" });
            return;
          }

          const existingRegistration = clickyShellRegistrationsById.get(shellId);
          if (!existingRegistration) {
            respond(false, { error: "shell not registered" });
            return;
          }

          const sessionKey =
            typeof (params as Record<string, unknown>).sessionKey === "string" &&
            (params as Record<string, unknown>).sessionKey.trim()
              ? (params as Record<string, unknown>).sessionKey.trim()
              : null;

          existingRegistration.sessionKey = sessionKey;
          existingRegistration.promptContext = null;
          existingRegistration.lastHeartbeatAt = Date.now();
          clickyShellRegistrationsById.set(shellId, existingRegistration);

          respond(true, {
            ok: true,
            registration: serializeShellRegistration(existingRegistration, normalizePluginConfig(api.pluginConfig).registrationTtlMs),
            shellId,
            summary: formatStatusSummary(api.pluginConfig, true),
          });
        } catch (error) {
          respond(false, { error: error instanceof Error ? error.message : String(error) });
        }
      },
      { scope: "operator.write" }
    );

    api.registerCommand({
      name: "clicky",
      description: "Show Clicky shell integration status.",
      acceptsArgs: false,
      requireAuth: false,
      handler: async () => {
        return {
          text: formatStatusSummary(api.pluginConfig, true),
        };
      },
    });

    api.registerTool({
      name: "clicky_status",
      description: "Inspect whether a Clicky desktop shell is connected and what shell capabilities it exposes.",
      parameters: clickyStatusToolParameters,
      async execute(_toolCallId, params) {
        const includeRegistrations = params.includeRegistrations !== false;
        return {
          content: [
            {
              type: "text",
              text: formatStatusSummary(api.pluginConfig, includeRegistrations),
            },
          ],
        };
      },
    });

    api.registerTool({
      name: "clicky_present",
      description: "Finish a Clicky turn in one of four modes: answer, point, walkthrough, or tutorial. Use this as the final presentation step for Clicky shell responses.",
      parameters: clickyPresentToolParameters,
      async execute(_toolCallId, params) {
        const presentationResult = buildClickyPresentationReply(params);
        if (!presentationResult.ok) {
          return {
            content: [
              {
                type: "text",
                text: presentationResult.error,
              },
            ],
            isError: true,
          };
        }

        api.logger.info(
          `clicky-shell: captured clicky_present tool output mode=${presentationResult.reply.mode}`
        );

        const finalResponseInstruction = [
          "Clicky presentation accepted.",
          "For the final assistant message, output exactly this JSON object and nothing else:",
          presentationResult.replyText,
        ].join("\n");

        return {
          content: [
            {
              type: "text",
              text: finalResponseInstruction,
            },
          ],
          structuredContent: presentationResult.reply,
        };
      },
    });

    api.on("before_prompt_build", async (_event, ctx) => {
      api.logger.info(
        `clicky-shell: before_prompt_build sessionKey=${ctx.sessionKey ?? "none"} sessionId=${ctx.sessionId ?? "none"}`
      );

      const normalizedPluginConfig = normalizePluginConfig(api.pluginConfig);
      const registration = findFreshShellRegistrationForSessionKey(
        ctx.sessionKey,
        normalizedPluginConfig.registrationTtlMs
      );

      if (!registration) {
        api.logger.info(`clicky-shell: before_prompt_build no fresh registration for ${ctx.sessionKey ?? "none"}`);
        return;
      }

      api.logger.info(
        `clicky-shell: before_prompt_build appending prompt context for shellId=${registration.shellId} boundSession=${registration.sessionKey ?? "none"}`
      );

      return {
        appendSystemContext: buildClickyShellPromptContext(registration),
      };
    });
  },
});
