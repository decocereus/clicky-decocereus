import type { Auth } from "better-auth"
import type { Context } from "hono"

import { createAuth } from "./config"
import type { Env } from "../env"

type AuthSession = Awaited<ReturnType<Auth["api"]["getSession"]>>

export async function getSession(c: Context<{ Bindings: Env }>): Promise<AuthSession> {
  const auth = createAuth(c.env)

  return auth.api.getSession({
    headers: c.req.raw.headers,
  })
}

export async function requireSession(c: Context<{ Bindings: Env }>) {
  const session = await getSession(c)

  if (!session) {
    return {
      ok: false as const,
      response: c.json(
        {
          error: "Authentication required.",
        },
        401,
      ),
    }
  }

  return {
    ok: true as const,
    session,
  }
}
