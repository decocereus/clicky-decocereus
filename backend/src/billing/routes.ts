import type { Context } from "hono"

import { requireSession } from "../auth/session"
import {
  buildNativeBillingCallbackUrl,
  getLaunchCheckoutConfig,
  getMissingCheckoutConfiguration,
} from "./config"
import { getLaunchEntitlementSnapshot } from "../entitlements/service"
import type { Env } from "../env"

export async function handleCreateCheckout(c: Context<{ Bindings: Env }>) {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const checkoutConfig = getLaunchCheckoutConfig(c.env)
  const missingConfiguration = getMissingCheckoutConfiguration(c.env)

  if (missingConfiguration.length > 0) {
    return c.json(
      {
        error: "Polar checkout is not fully configured.",
        missingConfiguration,
        checkout: checkoutConfig,
      },
      501,
    )
  }

  return c.json(
    {
      error: "Polar checkout session creation is not implemented yet.",
      checkout: checkoutConfig,
      nextStep: "Create a Polar hosted checkout session and persist a checkout audit record.",
    },
    501,
  )
}

export async function handleRestoreBilling(c: Context<{ Bindings: Env }>) {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const launchEntitlement = await getLaunchEntitlementSnapshot(
    c.env,
    sessionResult.session.user.id,
  )

  return c.json({
    userId: sessionResult.session.user.id,
    entitlement: launchEntitlement,
    restored: false,
    nextStep: "Provider-backed restore is not implemented yet.",
  })
}

export function handleBillingSuccessCallback(c: Context<{ Bindings: Env }>) {
  const callbackUrl = buildNativeBillingCallbackUrl(
    c.env,
    "success",
    new URL(c.req.url).searchParams,
  )

  return c.redirect(callbackUrl, 302)
}

export function handleBillingCancelCallback(c: Context<{ Bindings: Env }>) {
  const callbackUrl = buildNativeBillingCallbackUrl(
    c.env,
    "cancel",
    new URL(c.req.url).searchParams,
  )

  return c.redirect(callbackUrl, 302)
}
