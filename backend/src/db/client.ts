import { drizzle } from "drizzle-orm/neon-http"

import type { Env } from "../env"
import * as schema from "./schema"

export function createDb(env: Env) {
  if (!env.DATABASE_URL) {
    throw new Error("DATABASE_URL is not configured.")
  }

  return drizzle(env.DATABASE_URL, { schema })
}

export type ClickyDb = ReturnType<typeof createDb>
