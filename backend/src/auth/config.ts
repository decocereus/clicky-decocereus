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

function isLoopbackOrIpAddress(hostname: string) {
  if (!hostname) {
    return true
  }

  if (hostname === "localhost") {
    return true
  }

  return /^\d{1,3}(?:\.\d{1,3}){3}$/.test(hostname)
}

function resolveSharedCookieDomain(env: Env) {
  const authUrl = readEnvValue(env, "BETTER_AUTH_URL")
  const webOrigin = readEnvValue(env, "WEB_ORIGIN")

  if (!authUrl || !webOrigin) {
    return null
  }

  try {
    const authHostname = new URL(authUrl).hostname
    const webHostname = new URL(webOrigin).hostname

    if (isLoopbackOrIpAddress(authHostname) || isLoopbackOrIpAddress(webHostname)) {
      return null
    }

    if (authHostname === webHostname) {
      return null
    }

    if (authHostname.endsWith(`.${webHostname}`)) {
      return webHostname
    }

    if (webHostname.endsWith(`.${authHostname}`)) {
      return authHostname
    }

    return null
  } catch {
    return null
  }
}

export function createAuth(env: Env) {
  const sharedCookieDomain = resolveSharedCookieDomain(env)

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
    advanced: {
      crossSubDomainCookies: sharedCookieDomain
        ? {
            enabled: true,
            domain: sharedCookieDomain,
          }
        : undefined,
    },
    plugins: [
      bearer(),
    ],
  })
}
