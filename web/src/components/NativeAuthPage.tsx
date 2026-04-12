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
  | { status: 'signed-in'; email: string; name: string }
  | { status: 'error'; message: string };

type CompletionState =
  | { status: 'idle' }
  | { status: 'opening' }
  | { status: 'ready' }
  | { status: 'error'; message: string };

function readSearchParams() {
  if (typeof window === 'undefined') {
    return new URLSearchParams();
  }

  return new URLSearchParams(window.location.search);
}

export function NativeAuthPage() {
  const searchParams = useMemo(readSearchParams, []);
  const pathname =
    typeof window === 'undefined' ? '/auth/native' : window.location.pathname;
  const state = searchParams.get('state')?.trim() ?? '';
  const callbackUrl = searchParams.get('callbackUrl')?.trim() ?? '';
  const nativeCallbackUrl = searchParams.get('nativeCallbackUrl')?.trim() ?? '';
  const backendUrl = getBackendUrl();
  const isCompletionPage = pathname === '/auth/native/complete';

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitState, setSubmitState] = useState<SubmitState>({ status: 'idle' });
  const [sessionState, setSessionState] = useState<ExistingSessionState>({
    status: 'checking',
  });
  const [completionState, setCompletionState] = useState<CompletionState>({
    status: 'idle',
  });

  const isValid = isCompletionPage
    ? nativeCallbackUrl.length > 0
    : state.length > 0 && callbackUrl.length > 0;

  useEffect(() => {
    if (isCompletionPage) {
      return;
    }

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
          user?: { email?: string; name?: string };
        };

        startTransition(() => {
          setSessionState({
            status: 'signed-in',
            email: data.user?.email ?? 'your account',
            name: data.user?.name ?? data.user?.email ?? 'your account',
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
  }, [backendUrl, isCompletionPage, isValid]);

  useEffect(() => {
    if (!isCompletionPage) {
      return;
    }

    if (!isValid) {
      setCompletionState({
        status: 'error',
        message: 'Missing native callback URL. Start the sign-in flow again from Clicky.',
      });
      return;
    }

    const attemptOpen = window.setTimeout(() => {
      startTransition(() => {
        setCompletionState({ status: 'opening' });
      });
      window.location.assign(nativeCallbackUrl);
      window.setTimeout(() => {
        startTransition(() => {
          setCompletionState({ status: 'ready' });
        });
      }, 900);
    }, 150);

    return () => {
      window.clearTimeout(attemptOpen);
    };
  }, [isCompletionPage, isValid, nativeCallbackUrl]);

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
      startTransition(() => {
        setSubmitState({ status: 'redirecting' });
      });

      const signInUrl = new URL(`${backendUrl}/v1/auth/native/google/start`);
      signInUrl.searchParams.set('callbackUrl', callbackUrl);
      window.location.href = signInUrl.toString();
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

  function openClickyAgain() {
    if (!nativeCallbackUrl) {
      startTransition(() => {
        setCompletionState({
          status: 'error',
          message: 'The Clicky callback URL is missing. Start sign-in again from the Mac app.',
        });
      });
      return;
    }

    startTransition(() => {
      setCompletionState({ status: 'opening' });
    });
    window.location.assign(nativeCallbackUrl);
    window.setTimeout(() => {
      startTransition(() => {
        setCompletionState({ status: 'ready' });
      });
    }, 900);
  }

  return (
    <div className="bg-warm min-h-screen text-charcoal">
      <div className="mx-auto flex min-h-screen max-w-3xl items-center px-6 py-16">
        <div className="card-elegant w-full p-8 md:p-12">
          {isCompletionPage ? (
            <>
              <div className="mb-8 space-y-4">
                <div className="font-mono text-xs uppercase tracking-[0.22em] text-muted-elegant">
                  Clicky Ready
                </div>
                <h1 className="text-charcoal max-w-2xl text-4xl font-medium leading-tight md:text-5xl">
                  Clicky is signed in.
                </h1>
                <p className="text-muted-elegant max-w-xl text-base leading-7">
                  We&apos;re handing the session back to the Mac app now. If Clicky
                  didn&apos;t jump forward automatically, open it again below.
                </p>
              </div>

              {!isValid ? (
                <div className="mb-6 rounded-3xl border border-red-200 bg-red-50 p-5 text-sm text-red-700">
                  This handoff is missing the native callback URL. Start sign-in again
                  from the Mac app.
                </div>
              ) : null}

              {completionState.status === 'opening' ? (
                <div className="mb-6 rounded-3xl border border-black/10 bg-black/5 p-5 text-sm text-muted-elegant">
                  Opening Clicky...
                </div>
              ) : null}

              {completionState.status === 'ready' ? (
                <div className="mb-6 rounded-3xl border border-black/10 bg-white p-5 text-sm leading-7 text-charcoal">
                  Clicky should be active now. If the app stayed in the background,
                  choose <strong>Open Clicky</strong> once more.
                </div>
              ) : null}

              {completionState.status === 'error' ? (
                <div className="mb-6 rounded-3xl border border-red-200 bg-red-50 p-5 text-sm text-red-700">
                  {completionState.message}
                </div>
              ) : null}

              <div className="space-y-5">
                <Button
                  size="lg"
                  className="rounded-full px-8"
                  disabled={!isValid}
                  onClick={openClickyAgain}
                >
                  Open Clicky
                </Button>
              </div>
            </>
          ) : (
            <>
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
                    <strong>{sessionState.name}</strong>. Continue and Clicky will pick
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
            </>
          )}
        </div>
      </div>
    </div>
  );
}
