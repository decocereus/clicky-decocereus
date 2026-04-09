import "dotenv/config"

import { defineConfig } from "drizzle-kit"

const databaseUrl =
  process.env.DATABASE_URL ??
  "postgres://clicky:clicky@localhost:5432/clicky"

export default defineConfig({
  out: "./drizzle",
  schema: "./src/db/schema-all.ts",
  dialect: "postgresql",
  dbCredentials: {
    url: databaseUrl,
  },
})
