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

const registrationsByShellId = new Map<string, ShellRegistration>();

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
    "Desktop action tools: not exposed by this plugin.",
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
    "clicky desktop shell:",
    "- use clicky_present when a Clicky turn needs a structured final response for speech or cursor pointing.",
    "- desktop action tools are intentionally not exposed in this plugin right now. do not claim to click, type, scroll, or operate the user's Mac through Clicky.",
    "- if the user asks for desktop operation, give the safest manual guidance from the visible screen context.",
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

    api.registerTool({
      name: "clicky_present",
      description: "Finish a Clicky turn in answer, point, walkthrough, or tutorial mode.",
      parameters: presentToolParameters,
      async execute(_toolCallId, params) {
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
    });

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
