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
  RESEND_API_KEY: process.env.RESEND_API_KEY ?? "resend-key-not-configured",
  RESEND_FROM_EMAIL: process.env.RESEND_FROM_EMAIL ?? "Clicky <signin@example.com>",
}

export const auth = createAuth(cliEnv)
