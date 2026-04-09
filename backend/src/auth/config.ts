import { betterAuth } from "better-auth"
import { drizzleAdapter } from "better-auth/adapters/drizzle"
import { bearer } from "better-auth/plugins"

import { createDb } from "../db/client"
import type { Env } from "../env"

function requireValue(value: string | undefined, name: string) {
  if (!value) {
    throw new Error(`${name} is required for auth configuration.`)
  }

  return value
}

function trustedOrigins(env: Env) {
  return [
    env.BETTER_AUTH_URL,
    env.WEB_ORIGIN,
  ].filter((value): value is string => Boolean(value))
}

export function createAuth(env: Env) {
  return betterAuth({
    appName: env.APP_NAME,
    baseURL: requireValue(env.BETTER_AUTH_URL, "BETTER_AUTH_URL"),
    secret: requireValue(env.BETTER_AUTH_SECRET, "BETTER_AUTH_SECRET"),
    trustedOrigins: trustedOrigins(env),
    database: drizzleAdapter(createDb(env), {
      provider: "pg",
    }),
    socialProviders: {
      google: {
        clientId: requireValue(env.GOOGLE_CLIENT_ID, "GOOGLE_CLIENT_ID"),
        clientSecret: requireValue(env.GOOGLE_CLIENT_SECRET, "GOOGLE_CLIENT_SECRET"),
      },
    },
    emailAndPassword: {
      enabled: false,
    },
    plugins: [
      bearer(),
    ],
  })
}
