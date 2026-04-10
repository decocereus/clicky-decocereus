import type { Env } from "../env"

const ASSEMBLYAI_BASE_URL = "https://api.assemblyai.com/v2"
const POLL_INTERVAL_MS = 1_000
const TRANSCRIPTION_TIMEOUT_MS = 45_000

function requireAssemblyAIKey(env: Env) {
  const apiKey = env.ASSEMBLYAI_API_KEY?.trim()
  if (!apiKey) {
    throw new Error("ASSEMBLYAI_API_KEY is not configured.")
  }

  return apiKey
}

async function uploadAudioToAssemblyAI(
  apiKey: string,
  audioBuffer: ArrayBuffer,
) {
  const response = await fetch(`${ASSEMBLYAI_BASE_URL}/upload`, {
    method: "POST",
    headers: {
      Authorization: apiKey,
      "Content-Type": "application/octet-stream",
    },
    body: audioBuffer,
  })

  if (!response.ok) {
    throw new Error(
      `AssemblyAI upload failed with ${response.status}: ${await response.text()}`,
    )
  }

  const payload = (await response.json()) as { upload_url?: string }
  const uploadUrl = payload.upload_url?.trim()
  if (!uploadUrl) {
    throw new Error("AssemblyAI upload did not return an upload_url.")
  }

  return uploadUrl
}

async function createAssemblyAITranscript(
  apiKey: string,
  uploadUrl: string,
) {
  const response = await fetch(`${ASSEMBLYAI_BASE_URL}/transcript`, {
    method: "POST",
    headers: {
      Authorization: apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      audio_url: uploadUrl,
      format_text: true,
      language_detection: true,
      punctuate: true,
      speech_models: ["universal-2"],
    }),
  })

  if (!response.ok) {
    throw new Error(
      `AssemblyAI transcript creation failed with ${response.status}: ${await response.text()}`,
    )
  }

  const payload = (await response.json()) as { id?: string }
  const transcriptId = payload.id?.trim()
  if (!transcriptId) {
    throw new Error("AssemblyAI transcript creation did not return an id.")
  }

  return transcriptId
}

async function pollAssemblyAITranscript(
  apiKey: string,
  transcriptId: string,
) {
  const startedAt = Date.now()

  while (Date.now() - startedAt < TRANSCRIPTION_TIMEOUT_MS) {
    const response = await fetch(`${ASSEMBLYAI_BASE_URL}/transcript/${transcriptId}`, {
      headers: {
        Authorization: apiKey,
      },
    })

    if (!response.ok) {
      throw new Error(
        `AssemblyAI transcript polling failed with ${response.status}: ${await response.text()}`,
      )
    }

    const payload = (await response.json()) as {
      error?: string
      status?: string
      text?: string
    }

    if (payload.status === "completed") {
      return (payload.text ?? "").trim()
    }

    if (payload.status === "error") {
      throw new Error(payload.error?.trim() || "AssemblyAI transcription failed.")
    }

    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS))
  }

  throw new Error("AssemblyAI transcription timed out.")
}

async function deleteAssemblyAITranscript(
  apiKey: string,
  transcriptId: string,
) {
  await fetch(`${ASSEMBLYAI_BASE_URL}/transcript/${transcriptId}`, {
    method: "DELETE",
    headers: {
      Authorization: apiKey,
    },
  }).catch(() => {
    // Best effort cleanup only.
  })
}

export async function transcribeWebCompanionAudio(
  env: Env,
  audioBuffer: ArrayBuffer,
) {
  const apiKey = requireAssemblyAIKey(env)
  const uploadUrl = await uploadAudioToAssemblyAI(apiKey, audioBuffer)
  const transcriptId = await createAssemblyAITranscript(apiKey, uploadUrl)

  try {
    return await pollAssemblyAITranscript(apiKey, transcriptId)
  } finally {
    void deleteAssemblyAITranscript(apiKey, transcriptId)
  }
}
