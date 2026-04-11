export interface Env {
  APP_NAME: string
  BETTER_AUTH_SECRET?: string
  BETTER_AUTH_URL?: string
  DATABASE_URL?: string
  WEB_ORIGIN?: string
  MAC_APP_SCHEME?: string
  GOOGLE_CLIENT_ID?: string
  GOOGLE_CLIENT_SECRET?: string
  ASSEMBLYAI_API_KEY?: string
  ELEVENLABS_API_KEY?: string
  ELEVENLABS_MODEL_ID?: string
  ELEVENLABS_VOICE_ID?: string
  POLAR_ACCESS_TOKEN?: string
  POLAR_LAUNCH_PRODUCT_ID?: string
  POLAR_LAUNCH_DISCOUNT_ID?: string
  POLAR_WEBHOOK_SECRET?: string
  OPENCLAW_GATEWAY_URL?: string
  OPENCLAW_GATEWAY_AUTH_TOKEN?: string
  OPENCLAW_AGENT_ID?: string
  OPENCLAW_CLICKY_WEB_SHELL_ENABLED?: string
  OPENCLAW_CLICKY_WEB_PRESENTATION_NAME?: string
}

export function readEnvValue(env: Partial<Env> | undefined, key: keyof Env) {
  const explicitValue = env?.[key]

  if (typeof explicitValue === "string") {
    return explicitValue
  }

  if (typeof process !== "undefined" && process.env) {
    const processValue = process.env[key]
    if (typeof processValue === "string") {
      return processValue
    }
  }

  return explicitValue
}

export function requireEnvValue(env: Partial<Env> | undefined, key: keyof Env) {
  const value = readEnvValue(env, key)

  if (!value) {
    throw new Error(`${key} is required for auth configuration.`)
  }

  return value
}
