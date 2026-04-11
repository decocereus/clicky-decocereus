import { serve } from "@hono/node-server"

import app from "./index"
import type { Env } from "./env"

const port = Number.parseInt(process.env.PORT ?? "8788", 10)

function nodeBindings(): Env {
  return {
    APP_NAME: process.env.APP_NAME ?? "Clicky Backend",
    BETTER_AUTH_SECRET: process.env.BETTER_AUTH_SECRET,
    BETTER_AUTH_URL: process.env.BETTER_AUTH_URL,
    DATABASE_URL: process.env.DATABASE_URL,
    WEB_ORIGIN: process.env.WEB_ORIGIN,
    MAC_APP_SCHEME: process.env.MAC_APP_SCHEME,
    GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID,
    GOOGLE_CLIENT_SECRET: process.env.GOOGLE_CLIENT_SECRET,
    ASSEMBLYAI_API_KEY: process.env.ASSEMBLYAI_API_KEY,
    ELEVENLABS_API_KEY: process.env.ELEVENLABS_API_KEY,
    ELEVENLABS_MODEL_ID: process.env.ELEVENLABS_MODEL_ID,
    ELEVENLABS_VOICE_ID: process.env.ELEVENLABS_VOICE_ID,
    POLAR_ACCESS_TOKEN: process.env.POLAR_ACCESS_TOKEN,
    POLAR_LAUNCH_PRODUCT_ID: process.env.POLAR_LAUNCH_PRODUCT_ID,
    POLAR_LAUNCH_DISCOUNT_ID: process.env.POLAR_LAUNCH_DISCOUNT_ID,
    POLAR_WEBHOOK_SECRET: process.env.POLAR_WEBHOOK_SECRET,
    OPENCLAW_GATEWAY_URL: process.env.OPENCLAW_GATEWAY_URL,
    OPENCLAW_GATEWAY_AUTH_TOKEN: process.env.OPENCLAW_GATEWAY_AUTH_TOKEN,
    OPENCLAW_AGENT_ID: process.env.OPENCLAW_AGENT_ID,
    OPENCLAW_CLICKY_WEB_SHELL_ENABLED: process.env.OPENCLAW_CLICKY_WEB_SHELL_ENABLED,
    OPENCLAW_CLICKY_WEB_PRESENTATION_NAME: process.env.OPENCLAW_CLICKY_WEB_PRESENTATION_NAME,
  }
}

serve({
  fetch: (request) => app.fetch(request, nodeBindings()),
  port,
})

console.log(`[clicky-backend] listening on port ${port}`)
