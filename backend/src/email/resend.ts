import type { Env } from "../env"

function requireValue(value: string | undefined, name: string) {
  if (!value) {
    throw new Error(`${name} is required for email delivery.`)
  }

  return value
}

export async function sendMagicLinkEmail(
  env: Env,
  input: {
    email: string
    url: string
  },
) {
  const apiKey = requireValue(env.RESEND_API_KEY, "RESEND_API_KEY")
  const from = requireValue(env.RESEND_FROM_EMAIL, "RESEND_FROM_EMAIL")

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [input.email],
      subject: "Sign in to Clicky",
      html: `
        <div style="font-family: Inter, system-ui, sans-serif; line-height: 1.6; color: #111827;">
          <h1 style="font-size: 20px; margin-bottom: 12px;">Sign in to Clicky</h1>
          <p style="margin-bottom: 16px;">
            Continue your Clicky sign-in by opening the secure link below.
          </p>
          <p style="margin-bottom: 24px;">
            <a
              href="${input.url}"
              style="display: inline-block; background: #111827; color: white; padding: 12px 16px; border-radius: 10px; text-decoration: none; font-weight: 600;"
            >
              Continue to Clicky
            </a>
          </p>
          <p style="font-size: 14px; color: #6b7280;">
            If the button does not work, copy and paste this URL into your browser:
          </p>
          <p style="font-size: 14px; word-break: break-all; color: #374151;">
            ${input.url}
          </p>
        </div>
      `,
    }),
  })

  if (!response.ok) {
    const errorBody = await response.text()
    throw new Error(`Resend email delivery failed: ${response.status} ${errorBody}`)
  }
}
