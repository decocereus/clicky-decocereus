import { betterAuth } from "better-auth"
import { drizzleAdapter } from "better-auth/adapters/drizzle"
import { bearer } from "better-auth/plugins"

import { createDb } from "../db/client"
import { readEnvValue, requireEnvValue, type Env } from "../env"

function expandLocalhostOrigin(origin: string | undefined) {
  if (!origin) {
    return []
  }

  const trimmedOrigin = origin.trim()
  if (!trimmedOrigin) {
    return []
  }

  const origins = new Set([trimmedOrigin])

  try {
    const url = new URL(trimmedOrigin)
    const isLoopbackHost =
      url.hostname === "localhost" || url.hostname === "127.0.0.1"

    if (isLoopbackHost) {
      const alternateUrl = new URL(url.toString())
      alternateUrl.hostname = url.hostname === "localhost" ? "127.0.0.1" : "localhost"
      origins.add(alternateUrl.origin)
    }
  } catch {
    // Ignore invalid URLs and just keep the original value.
  }

  return [...origins]
}

function trustedOrigins(env: Env) {
  return [
    ...expandLocalhostOrigin(readEnvValue(env, "BETTER_AUTH_URL")),
    ...expandLocalhostOrigin(readEnvValue(env, "WEB_ORIGIN")),
  ]
}

export function createAuth(env: Env) {
  return betterAuth({
    appName: readEnvValue(env, "APP_NAME") ?? "Clicky Backend",
    baseURL: requireEnvValue(env, "BETTER_AUTH_URL"),
    secret: requireEnvValue(env, "BETTER_AUTH_SECRET"),
    trustedOrigins: trustedOrigins(env),
    database: drizzleAdapter(createDb(env), {
      provider: "pg",
    }),
    socialProviders: {
      google: {
        clientId: requireEnvValue(env, "GOOGLE_CLIENT_ID"),
        clientSecret: requireEnvValue(env, "GOOGLE_CLIENT_SECRET"),
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
