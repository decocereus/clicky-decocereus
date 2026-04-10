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
    ...expandLocalhostOrigin(env.BETTER_AUTH_URL),
    ...expandLocalhostOrigin(env.WEB_ORIGIN),
  ]
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
