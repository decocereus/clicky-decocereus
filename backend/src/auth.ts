import { createAuth } from "./auth/config"
import type { Env } from "./env"

const cliEnv: Env = {
  APP_NAME: process.env.APP_NAME ?? "Clicky Backend",
  BETTER_AUTH_SECRET:
    process.env.BETTER_AUTH_SECRET ??
    "development-secret-development-secret",
  BETTER_AUTH_URL: process.env.BETTER_AUTH_URL ?? "http://localhost:8787",
  DATABASE_URL:
    process.env.DATABASE_URL ??
    "postgres://clicky:clicky@localhost:5432/clicky",
  WEB_ORIGIN: process.env.WEB_ORIGIN ?? "http://localhost:5173",
  MAC_APP_SCHEME: process.env.MAC_APP_SCHEME ?? "clicky",
  GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID ?? "google-client-id-not-configured",
  GOOGLE_CLIENT_SECRET: process.env.GOOGLE_CLIENT_SECRET ?? "google-client-secret-not-configured",
  ELEVENLABS_API_KEY: process.env.ELEVENLABS_API_KEY,
  ELEVENLABS_MODEL_ID: process.env.ELEVENLABS_MODEL_ID,
  ELEVENLABS_VOICE_ID: process.env.ELEVENLABS_VOICE_ID,
  OPENCLAW_GATEWAY_URL: process.env.OPENCLAW_GATEWAY_URL,
  OPENCLAW_GATEWAY_AUTH_TOKEN: process.env.OPENCLAW_GATEWAY_AUTH_TOKEN,
  OPENCLAW_AGENT_ID: process.env.OPENCLAW_AGENT_ID,
  OPENCLAW_CLICKY_WEB_SHELL_ENABLED: process.env.OPENCLAW_CLICKY_WEB_SHELL_ENABLED,
  OPENCLAW_CLICKY_WEB_PRESENTATION_NAME: process.env.OPENCLAW_CLICKY_WEB_PRESENTATION_NAME,
}

export const auth = createAuth(cliEnv)
