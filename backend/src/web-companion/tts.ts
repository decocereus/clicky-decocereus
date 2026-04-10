import type { Env } from "../env"

const DEFAULT_ELEVENLABS_MODEL_ID = "eleven_flash_v2_5"

function normalizeText(value: string | undefined) {
  return value?.trim() ?? ""
}

export async function synthesizeElevenLabsAudio(
  env: Env,
  text: string,
) {
  const apiKey = normalizeText(env.ELEVENLABS_API_KEY)
  const voiceId = normalizeText(env.ELEVENLABS_VOICE_ID)
  const modelId = normalizeText(env.ELEVENLABS_MODEL_ID) || DEFAULT_ELEVENLABS_MODEL_ID

  if (!apiKey || !voiceId) {
    return null
  }

  const response = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
    {
      method: "POST",
      headers: {
        accept: "audio/mpeg",
        "content-type": "application/json",
        "xi-api-key": apiKey,
      },
      body: JSON.stringify({
        model_id: modelId,
        text,
        voice_settings: {
          similarity_boost: 0.72,
          stability: 0.35,
        },
      }),
    },
  )

  if (!response.ok) {
    throw new Error(
      `ElevenLabs synthesis failed with ${response.status}: ${await response.text()}`,
    )
  }

  const audioBuffer = await response.arrayBuffer()
  if (!audioBuffer.byteLength) {
    return null
  }

  return {
    audioBase64: Buffer.from(audioBuffer).toString("base64"),
    fileExtension: "mp3",
    mimeType: response.headers.get("content-type") || "audio/mpeg",
    provider: "elevenlabs",
  }
}
