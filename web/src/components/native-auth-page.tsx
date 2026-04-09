import { startTransition, useMemo, useState } from "react"

import { Button } from "@/components/ui/button"
import { getBackendUrl } from "@/lib/backend"

type SubmitState =
  | { status: "idle" }
  | { status: "success"; email: string }
  | { status: "error"; message: string }

function readSearchParams() {
  if (typeof window === "undefined") {
    return new URLSearchParams()
  }

  return new URLSearchParams(window.location.search)
}

export function NativeAuthPage() {
  const searchParams = useMemo(readSearchParams, [])
  const state = searchParams.get("state")?.trim() ?? ""
  const callbackUrl = searchParams.get("callbackUrl")?.trim() ?? ""
  const backendUrl = getBackendUrl()

  const [email, setEmail] = useState("")
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [submitState, setSubmitState] = useState<SubmitState>({ status: "idle" })

  const isValid = state.length > 0 && callbackUrl.length > 0

  async function requestMagicLink() {
    if (!isValid || !email.trim()) {
      setSubmitState({
        status: "error",
        message: "A valid email, state, and callback URL are required.",
      })
      return
    }

    setIsSubmitting(true)

    try {
      const response = await fetch(`${backendUrl}/api/auth/sign-in/magic-link`, {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email: email.trim(),
          callbackURL: callbackUrl,
        }),
      })

      if (!response.ok) {
        const errorText = await response.text()
        throw new Error(errorText || "Magic link request failed.")
      }

      startTransition(() => {
        setSubmitState({
          status: "success",
          email: email.trim(),
        })
      })
    } catch (error) {
      startTransition(() => {
        setSubmitState({
          status: "error",
          message:
            error instanceof Error
              ? error.message
              : "Magic link request failed.",
        })
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="flex min-h-svh items-center justify-center p-6">
      <div className="w-full max-w-xl rounded-3xl border border-border bg-card p-8 shadow-lg">
        <div className="mb-8 space-y-3">
          <div className="text-sm font-mono uppercase tracking-[0.2em] text-muted-foreground">
            Clicky Native Sign-In
          </div>
          <h1 className="text-3xl font-semibold tracking-tight">
            Finish sign-in for the Mac app
          </h1>
          <p className="max-w-lg text-sm leading-6 text-muted-foreground">
            Enter your email and we&apos;ll send a secure sign-in link. After you open
            it, this browser will hand the session back to Clicky automatically.
          </p>
        </div>

        {!isValid ? (
          <div className="rounded-2xl border border-destructive/40 bg-destructive/10 p-4 text-sm text-destructive">
            This sign-in handoff is missing required state or callback information.
            Start the flow again from the Mac app.
          </div>
        ) : null}

        <div className="space-y-4">
          <label className="block space-y-2">
            <span className="text-sm font-medium">Email address</span>
            <input
              className="w-full rounded-2xl border border-input bg-background px-4 py-3 text-sm outline-none transition focus:border-primary"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="you@example.com"
              disabled={isSubmitting || !isValid}
            />
          </label>

          <Button
            className="w-full"
            disabled={isSubmitting || !isValid || email.trim().length === 0}
            onClick={requestMagicLink}
          >
            {isSubmitting ? "Sending magic link..." : "Email me a sign-in link"}
          </Button>
        </div>

        {submitState.status === "success" ? (
          <div className="mt-6 rounded-2xl border border-primary/30 bg-primary/10 p-4 text-sm text-foreground">
            Check <strong>{submitState.email}</strong> for your Clicky sign-in link.
            After opening it, this browser will return the session to the Mac app.
          </div>
        ) : null}

        {submitState.status === "error" ? (
          <div className="mt-6 rounded-2xl border border-destructive/40 bg-destructive/10 p-4 text-sm text-destructive">
            {submitState.message}
          </div>
        ) : null}

        <div className="mt-8 text-xs leading-6 text-muted-foreground">
          Backend: {backendUrl}
        </div>
      </div>
    </div>
  )
}
