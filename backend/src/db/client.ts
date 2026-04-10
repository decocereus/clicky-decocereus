import { drizzle } from "drizzle-orm/neon-http"

import * as authSchema from "../../auth-schema"
import type { Env } from "../env"
import * as appSchema from "./schema"

const schema = {
  ...authSchema,
  ...appSchema,
}

export function createDb(env: Env) {
  if (!env.DATABASE_URL) {
    throw new Error("DATABASE_URL is not configured.")
  }

  return drizzle(env.DATABASE_URL, { schema })
}

export type ClickyDb = ReturnType<typeof createDb>
