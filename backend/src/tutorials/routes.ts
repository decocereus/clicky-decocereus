import type { Context } from "hono"

import { requireSession } from "../auth/session"
import { readEnvValue, type Env } from "../env"

function getContentIngestionConfig(env: Env) {
  const baseURL = readEnvValue(env, "CONTENT_INGESTION_BASE_URL")?.trim()
  const apiKey = readEnvValue(env, "CONTENT_INGESTION_API_KEY")?.trim()

  if (!baseURL) {
    throw new Error("Tutorial extraction is not configured.")
  }

  if (!apiKey) {
    throw new Error("Tutorial extraction API key is not configured.")
  }

  return {
    baseURL: baseURL.endsWith("/") ? baseURL.slice(0, -1) : baseURL,
    apiKey,
  }
}

async function proxyContentIngestionRequest(
  env: Env,
  path: string,
  init: RequestInit,
) {
  const { baseURL, apiKey } = getContentIngestionConfig(env)
  const response = await fetch(`${baseURL}${path}`, {
    ...init,
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      ...(init.headers ?? {}),
    },
  })

  const text = await response.text()
  const contentType = response.headers.get("content-type") ?? "application/json"

  return {
    status: response.status,
    contentType,
    text,
  }
}

export async function handleStartTutorialExtraction(
  c: Context<{ Bindings: Env }>,
) {
  const sessionResult = await requireSession(c)
  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const body = (await c.req.json().catch(() => null)) as
    | {
        url?: unknown
        language?: unknown
        maxFrames?: unknown
      }
    | null

  const payload = {
    url: typeof body?.url === "string" ? body.url : "",
    language: typeof body?.language === "string" ? body.language : "en",
    max_frames: typeof body?.maxFrames === "number" ? body.maxFrames : 8,
  }

  const result = await proxyContentIngestionRequest(c.env, "/tutorials/extract", {
    method: "POST",
    body: JSON.stringify(payload),
  })

  return new Response(result.text, {
    status: result.status,
    headers: {
      "content-type": result.contentType,
    },
  })
}

export async function handleGetTutorialExtractionJob(
  c: Context<{ Bindings: Env }>,
) {
  const sessionResult = await requireSession(c)
  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const jobId = c.req.param("jobId")
  if (!jobId) {
    return c.json({ error: "Missing tutorial extraction job id." }, 400)
  }

  const result = await proxyContentIngestionRequest(
    c.env,
    `/tutorials/extract/${encodeURIComponent(jobId)}`,
    { method: "GET" },
  )

  return new Response(result.text, {
    status: result.status,
    headers: {
      "content-type": result.contentType,
    },
  })
}

export async function handleGetTutorialEvidence(
  c: Context<{ Bindings: Env }>,
) {
  const sessionResult = await requireSession(c)
  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const videoId = c.req.param("videoId")
  if (!videoId) {
    return c.json({ error: "Missing tutorial video id." }, 400)
  }

  const result = await proxyContentIngestionRequest(
    c.env,
    `/tutorials/evidence/${encodeURIComponent(videoId)}`,
    { method: "GET" },
  )

  return new Response(result.text, {
    status: result.status,
    headers: {
      "content-type": result.contentType,
    },
  })
}
