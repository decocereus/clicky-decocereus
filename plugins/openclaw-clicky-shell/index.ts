import { Type } from "@sinclair/typebox";
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
};

type ClickyShellFreshnessState = "fresh" | "stale";
type ClickyShellTrustState = "trusted-local" | "trusted-remote";

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

function findFreshShellRegistrationForSessionKey(
  sessionKey: string | undefined,
  registrationTtlMs: number
) {
  if (!sessionKey) return null;

  const registrations = [...clickyShellRegistrationsById.values()]
    .filter((registration) => registration.sessionKey === sessionKey)
    .sort((leftRegistration, rightRegistration) => rightRegistration.lastHeartbeatAt - leftRegistration.lastHeartbeatAt);

  const freshestRegistration = registrations[0] ?? null;
  if (!freshestRegistration) return null;

  return freshnessStateForRegistration(freshestRegistration, registrationTtlMs) === "fresh"
    ? freshestRegistration
    : null;
}

function buildClickyShellPromptContext(
  registration: ClickyShellRegistration
) {
  return [
    "clicky shell is active for this run.",
    `upstream agent identity: ${registration.agentIdentityName ?? "unknown"}.`,
    `clicky-local presentation: ${registration.clickyPresentationName ?? registration.agentIdentityName ?? "unknown"}.`,
    `persona scope: ${registration.personaScope}.`,
    `shell capabilities: ${registration.capabilities.join(", ") || "none"}.`,
    `screen context transport: ${registration.screenContextTransport ?? "unknown"}.`,
    `cursor pointing protocol: ${registration.cursorPointingProtocol ?? "unknown"}.`,
    `speech output mode: ${registration.speechOutputMode ?? "unknown"}.`,
    "when visual guidance would help, use the clicky point-tag format at the end of your reply.",
  ].join(" ");
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
      parameters: Type.Object({
        includeRegistrations: Type.Optional(Type.Boolean()),
      }),
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

    api.on("before_prompt_build", async (_event, ctx) => {
      const normalizedPluginConfig = normalizePluginConfig(api.pluginConfig);
      const registration = findFreshShellRegistrationForSessionKey(
        ctx.sessionKey,
        normalizedPluginConfig.registrationTtlMs
      );

      if (!registration) {
        return;
      }

      return {
        prependSystemContext: buildClickyShellPromptContext(registration),
      };
    });
  },
});
