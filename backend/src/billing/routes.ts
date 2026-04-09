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
