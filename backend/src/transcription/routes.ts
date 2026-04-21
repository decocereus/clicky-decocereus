import type { Context } from "hono"
import type { ContentfulStatusCode } from "hono/utils/http-status"

import { readEnvValue, type Env } from "../env"

export async function handleCreateAssemblyAIToken(c: Context<{ Bindings: Env }>) {
  const apiKey = readEnvValue(c.env, "ASSEMBLYAI_API_KEY")?.trim()

  if (!apiKey) {
    return c.json(
      {
        error: "ASSEMBLYAI_API_KEY is not configured on the backend.",
      },
      500,
    )
  }

  const response = await fetch(
    "https://streaming.assemblyai.com/v3/token?expires_in_seconds=480",
    {
      method: "GET",
      headers: {
        authorization: apiKey,
      },
    },
  )

  if (!response.ok) {
    const errorBody = await response.text()
    console.error(`[backend:/v1/transcription/assemblyai-token] AssemblyAI token error ${response.status}: ${errorBody}`)

    return c.body(errorBody, response.status as ContentfulStatusCode, {
      "content-type": response.headers.get("content-type") ?? "application/json",
    })
  }

  const payload = await response.text()
  return c.body(payload, 200, {
    "content-type": "application/json",
    "cache-control": "no-store",
  })
}
