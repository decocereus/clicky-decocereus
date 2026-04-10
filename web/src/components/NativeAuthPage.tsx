import { startTransition, useEffect, useMemo, useState } from 'react';

import { Button } from '@/components/ui/button';
import { getBackendUrl } from '@/lib/backend';

type SubmitState =
  | { status: 'idle' }
  | { status: 'redirecting' }
  | { status: 'error'; message: string };

type ExistingSessionState =
  | { status: 'checking' }
  | { status: 'signed-out' }
  | { status: 'signed-in'; email: string }
  | { status: 'error'; message: string };

function readSearchParams() {
  if (typeof window === 'undefined') {
    return new URLSearchParams();
  }

  return new URLSearchParams(window.location.search);
}

export function NativeAuthPage() {
  const searchParams = useMemo(readSearchParams, []);
  const state = searchParams.get('state')?.trim() ?? '';
  const callbackUrl = searchParams.get('callbackUrl')?.trim() ?? '';
  const backendUrl = getBackendUrl();

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitState, setSubmitState] = useState<SubmitState>({ status: 'idle' });
  const [sessionState, setSessionState] = useState<ExistingSessionState>({
    status: 'checking',
  });

  const isValid = state.length > 0 && callbackUrl.length > 0;

  useEffect(() => {
    if (!isValid) {
      setSessionState({
        status: 'error',
        message: 'Missing native auth state or callback URL.',
      });
      return;
    }

    let isCancelled = false;

    void (async () => {
      try {
        const response = await fetch(`${backendUrl}/v1/me`, {
          credentials: 'include',
        });

        if (isCancelled) {
          return;
        }

        if (response.status === 401) {
          startTransition(() => {
            setSessionState({ status: 'signed-out' });
          });
          return;
        }

        if (!response.ok) {
          throw new Error('Failed to inspect existing browser session.');
        }

        const data = (await response.json()) as {
          user?: { email?: string };
        };

        startTransition(() => {
          setSessionState({
            status: 'signed-in',
            email: data.user?.email ?? 'your account',
          });
        });
      } catch (error) {
        if (isCancelled) {
          return;
        }

        startTransition(() => {
          setSessionState({
            status: 'error',
            message:
              error instanceof Error
                ? error.message
                : 'Failed to inspect existing browser session.',
          });
        });
      }
    })();

    return () => {
      isCancelled = true;
    };
  }, [backendUrl, isValid]);

  async function continueWithGoogle() {
    if (!isValid) {
      setSubmitState({
        status: 'error',
        message: 'A valid native auth state and callback URL are required.',
      });
      return;
    }

    setIsSubmitting(true);

    try {
      const response = await fetch(`${backendUrl}/api/auth/sign-in/social`, {
        method: 'POST',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          provider: 'google',
          disableRedirect: true,
          callbackURL: callbackUrl,
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(errorText || 'Google sign-in request failed.');
      }

      const data = (await response.json()) as { url?: string };

      if (!data.url) {
        throw new Error('Google sign-in URL was missing from the backend response.');
      }

      startTransition(() => {
        setSubmitState({ status: 'redirecting' });
      });

      window.location.href = data.url;
    } catch (error) {
      startTransition(() => {
        setSubmitState({
          status: 'error',
          message:
            error instanceof Error
              ? error.message
              : 'Google sign-in request failed.',
        });
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  function continueWithExistingSession() {
    window.location.href = callbackUrl;
  }

  return (
    <div className="bg-warm min-h-screen text-charcoal">
      <div className="mx-auto flex min-h-screen max-w-3xl items-center px-6 py-16">
        <div className="card-elegant w-full p-8 md:p-12">
          <div className="mb-8 space-y-4">
            <div className="font-mono text-xs uppercase tracking-[0.22em] text-muted-elegant">
              Clicky Native Sign-In
            </div>
            <h1 className="text-charcoal max-w-2xl text-4xl font-medium leading-tight md:text-5xl">
              Finish sign-in for the Mac app.
            </h1>
            <p className="text-muted-elegant max-w-xl text-base leading-7">
              The Mac app started this auth handoff. Continue with Google here and
              this browser will hand the session back to Clicky automatically.
            </p>
          </div>

          {!isValid ? (
            <div className="mb-6 rounded-3xl border border-red-200 bg-red-50 p-5 text-sm text-red-700">
              This auth handoff is missing the required state or callback URL. Start
              the sign-in flow again from the Mac app.
            </div>
          ) : null}

          {sessionState.status === 'checking' ? (
            <div className="mb-6 rounded-3xl border border-black/10 bg-black/5 p-5 text-sm text-muted-elegant">
              Checking whether this browser is already signed in...
            </div>
          ) : null}

          {sessionState.status === 'signed-in' ? (
            <div className="space-y-5">
              <div className="rounded-3xl border border-black/10 bg-white p-5 text-sm leading-7 text-charcoal">
                This browser is already signed in as{' '}
                <strong>{sessionState.email}</strong>. Continue and Clicky will pick
                up that session right away.
              </div>

              <Button
                size="lg"
                className="rounded-full px-8"
                disabled={!isValid}
                onClick={continueWithExistingSession}
              >
                Continue to Clicky
              </Button>
            </div>
          ) : null}

          {(sessionState.status === 'signed-out' ||
            sessionState.status === 'error') && (
            <div className="space-y-5">
              {sessionState.status === 'error' ? (
                <div className="rounded-3xl border border-red-200 bg-red-50 p-5 text-sm text-red-700">
                  {sessionState.message}
                </div>
              ) : null}

              <Button
                size="lg"
                className="rounded-full px-8"
                disabled={isSubmitting || !isValid}
                onClick={continueWithGoogle}
              >
                {isSubmitting ? 'Redirecting to Google...' : 'Continue with Google'}
              </Button>
            </div>
          )}

          {submitState.status === 'redirecting' ? (
            <div className="mt-6 rounded-3xl border border-black/10 bg-black/5 p-5 text-sm text-muted-elegant">
              Redirecting you to Google sign-in...
            </div>
          ) : null}

          {submitState.status === 'error' ? (
            <div className="mt-6 rounded-3xl border border-red-200 bg-red-50 p-5 text-sm text-red-700">
              {submitState.message}
            </div>
          ) : null}

          <div className="mt-10 text-xs leading-6 text-muted-elegant">
            Backend: {backendUrl}
          </div>
        </div>
      </div>
    </div>
  );
}
