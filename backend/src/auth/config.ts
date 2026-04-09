import { betterAuth } from "better-auth"
import { drizzleAdapter } from "better-auth/adapters/drizzle"
import { bearer, magicLink } from "better-auth/plugins"

import { createDb } from "../db/client"
import type { Env } from "../env"
import { sendMagicLinkEmail } from "../email/resend"

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
    emailAndPassword: {
      enabled: false,
    },
    plugins: [
      bearer(),
      magicLink({
        sendMagicLink: async ({ email, url }) => {
          await sendMagicLinkEmail(env, { email, url })
        },
      }),
    ],
  })
}
