import type { Context } from "hono"

import { requireSession } from "../auth/session"
import { reconcileLaunchEntitlementFromPolar } from "../billing/reconcile"
import { getLaunchEntitlementSnapshot } from "./service"
import type { Env } from "../env"

function entitlementResponse(userId: string, entitlement: Awaited<ReturnType<typeof getLaunchEntitlementSnapshot>>) {
  return {
    userId,
    entitlement,
  }
}

export async function handleGetEntitlements(c: Context<{ Bindings: Env }>) {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const launchEntitlement = await getLaunchEntitlementSnapshot(
    c.env,
    sessionResult.session.user.id,
  )

  return c.json(entitlementResponse(sessionResult.session.user.id, launchEntitlement))
}

export async function handleRefreshEntitlements(c: Context<{ Bindings: Env }>) {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const refreshResult = await reconcileLaunchEntitlementFromPolar(
    c.env,
    sessionResult.session.user.id,
  )

  return c.json({
    ...entitlementResponse(sessionResult.session.user.id, refreshResult.entitlement),
    providerState: refreshResult.providerState,
    refreshed: refreshResult.providerState.didCheckProvider,
  })
}
