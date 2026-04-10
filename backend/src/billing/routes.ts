import { checkoutSessionAudits } from "../db/schema"
import { createDb } from "../db/client"
import type { Context } from "hono"

import { requireSession } from "../auth/session"
import {
  buildNativeBillingCallbackUrl,
  getLaunchCheckoutConfig,
  getMissingCheckoutConfiguration,
} from "./config"
import { createPolarClient } from "./polar"
import { reconcileLaunchEntitlementFromPolar } from "./reconcile"
import { processPolarWebhook } from "./webhooks"
import type { Env } from "../env"

export async function handleCreateCheckout(c: Context<{ Bindings: Env }>) {
  try {
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

    const polarClient = createPolarClient(c.env)
    const db = createDb(c.env)
    const checkout = await polarClient.checkouts.create({
      products: [checkoutConfig.polarProductId!],
      externalCustomerId: sessionResult.session.user.id,
      customerEmail: sessionResult.session.user.email,
      successUrl: `${checkoutConfig.successUrl}?checkout_id={CHECKOUT_ID}`,
      returnUrl: checkoutConfig.cancelUrl,
      discountId: checkoutConfig.polarDiscountId,
      allowDiscountCodes: checkoutConfig.polarDiscountId ? false : true,
      metadata: {
        userId: sessionResult.session.user.id,
        productKey: checkoutConfig.productKey,
      },
      customerMetadata: {
        userId: sessionResult.session.user.id,
      },
    })

    await db.insert(checkoutSessionAudits).values({
      userId: sessionResult.session.user.id,
      provider: "polar",
      providerCheckoutId: checkout.id,
      productKey: checkoutConfig.productKey,
      status: "created",
      metadata: {
        checkoutUrl: checkout.url,
        customerEmail: sessionResult.session.user.email,
        discountId: checkout.discountId,
      },
    })

    return c.json(
      {
        checkout: {
          id: checkout.id,
          url: checkout.url,
          productKey: checkoutConfig.productKey,
          productId: checkoutConfig.polarProductId,
          discountId: checkout.discountId,
          successUrl: checkout.successUrl,
          returnUrl: checkout.returnUrl,
        },
      },
    )
  } catch (error) {
    const statusCode = typeof error === "object" && error !== null && "statusCode" in error
      ? Number((error as { statusCode: unknown }).statusCode)
      : 500
    const message = error instanceof Error ? error.message : "Polar checkout creation failed."

    return c.json(
      {
        error: message,
      },
      { status: statusCode as 400 | 401 | 422 | 500 },
    )
  }
}

export async function handleRestoreBilling(c: Context<{ Bindings: Env }>) {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const restoreResult = await reconcileLaunchEntitlementFromPolar(
    c.env,
    sessionResult.session.user.id,
  )

  return c.json({
    userId: sessionResult.session.user.id,
    entitlement: restoreResult.entitlement,
    providerState: restoreResult.providerState,
    restored: restoreResult.providerState.didCheckProvider,
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

export async function handlePolarWebhook(c: Context<{ Bindings: Env }>) {
  const body = await c.req.text()

  try {
    const result = await processPolarWebhook(c.env, body, c.req.raw.headers)

    return c.json({
      ok: true,
      duplicate: result.duplicate,
      eventType: result.eventType,
    })
  } catch (error) {
    return c.json(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Polar webhook processing failed.",
      },
      400,
    )
  }
}
