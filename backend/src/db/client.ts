import { drizzle } from "drizzle-orm/neon-http"

import * as authSchema from "../../auth-schema"
import { readEnvValue, type Env } from "../env"
import * as appSchema from "./schema"

const schema = {
  ...authSchema,
  ...appSchema,
}

export function createDb(env: Env) {
  const databaseUrl = readEnvValue(env, "DATABASE_URL")

  if (!databaseUrl) {
    throw new Error("DATABASE_URL is not configured.")
  }

  return drizzle(databaseUrl, { schema })
}

export type ClickyDb = ReturnType<typeof createDb>
