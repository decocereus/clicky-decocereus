import { startTransition, useEffect, useMemo, useState } from "react"

import { Button } from "@/components/ui/button"
import { getBackendUrl } from "@/lib/backend"

type SubmitState =
  | { status: "idle" }
  | { status: "redirecting" }
  | { status: "error"; message: string }

type ExistingSessionState =
  | { status: "checking" }
  | { status: "signed-out" }
  | { status: "signed-in"; email: string }
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

  const [isSubmitting, setIsSubmitting] = useState(false)
  const [submitState, setSubmitState] = useState<SubmitState>({ status: "idle" })
  const [sessionState, setSessionState] = useState<ExistingSessionState>({
    status: "checking",
  })

  const isValid = state.length > 0 && callbackUrl.length > 0

  useEffect(() => {
    if (!isValid) {
      setSessionState({
        status: "error",
        message: "Missing native auth state or callback URL.",
      })
      return
    }

    let isCancelled = false

    void (async () => {
      try {
        const response = await fetch(`${backendUrl}/v1/me`, {
          credentials: "include",
        })

        if (isCancelled) {
          return
        }

        if (response.status === 401) {
          startTransition(() => {
            setSessionState({ status: "signed-out" })
          })
          return
        }

        if (!response.ok) {
          throw new Error("Failed to inspect existing session.")
        }

        const data = (await response.json()) as {
          user?: { email?: string }
        }

        startTransition(() => {
          setSessionState({
            status: "signed-in",
            email: data.user?.email ?? "your account",
          })
        })
      } catch (error) {
        if (isCancelled) {
          return
        }

        startTransition(() => {
          setSessionState({
            status: "error",
            message:
              error instanceof Error
                ? error.message
                : "Failed to inspect existing session.",
          })
        })
      }
    })()

    return () => {
      isCancelled = true
    }
  }, [backendUrl, isValid])

  async function continueWithGoogle() {
    if (!isValid) {
      setSubmitState({
        status: "error",
        message: "A valid native auth state and callback URL are required.",
      })
      return
    }

    setIsSubmitting(true)

    try {
      const response = await fetch(`${backendUrl}/api/auth/sign-in/social`, {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          provider: "google",
          disableRedirect: true,
          callbackURL: callbackUrl,
        }),
      })

      if (!response.ok) {
        const errorText = await response.text()
        throw new Error(errorText || "Google sign-in request failed.")
      }

      const data = (await response.json()) as { url?: string }
      if (!data.url) {
        throw new Error("Google sign-in URL was missing from the backend response.")
      }

      startTransition(() => {
        setSubmitState({
          status: "redirecting",
        })
      })

      window.location.href = data.url
    } catch (error) {
      startTransition(() => {
        setSubmitState({
          status: "error",
          message:
            error instanceof Error
              ? error.message
              : "Google sign-in request failed.",
        })
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  function continueWithExistingSession() {
    window.location.href = callbackUrl
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
            Continue with Google in your browser. After Google finishes, this browser
            will hand the session back to Clicky automatically.
          </p>
        </div>

        {!isValid ? (
          <div className="rounded-2xl border border-destructive/40 bg-destructive/10 p-4 text-sm text-destructive">
            This sign-in handoff is missing required state or callback information.
            Start the flow again from the Mac app.
          </div>
        ) : null}

        {sessionState.status === "checking" ? (
          <div className="rounded-2xl border border-border bg-muted/50 p-4 text-sm text-muted-foreground">
            Checking whether this browser is already signed in...
          </div>
        ) : null}

        {sessionState.status === "signed-in" ? (
          <div className="space-y-4">
            <div className="rounded-2xl border border-primary/30 bg-primary/10 p-4 text-sm text-foreground">
              This browser is already signed in as <strong>{sessionState.email}</strong>.
              Continue and we&apos;ll return that session to Clicky.
            </div>

            <Button className="w-full" disabled={!isValid} onClick={continueWithExistingSession}>
              Continue to Clicky
            </Button>
          </div>
        ) : null}

        {sessionState.status === "signed-out" || sessionState.status === "error" ? (
          <div className="space-y-4">
            {sessionState.status === "error" ? (
              <div className="rounded-2xl border border-destructive/40 bg-destructive/10 p-4 text-sm text-destructive">
                {sessionState.message}
              </div>
            ) : null}

            <Button
              className="w-full"
              disabled={isSubmitting || !isValid}
              onClick={continueWithGoogle}
            >
              {isSubmitting ? "Redirecting to Google..." : "Continue with Google"}
            </Button>
          </div>
        ) : null}

        {submitState.status === "redirecting" ? (
          <div className="mt-6 rounded-2xl border border-primary/30 bg-primary/10 p-4 text-sm text-foreground">
            Redirecting you to Google sign-in...
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
