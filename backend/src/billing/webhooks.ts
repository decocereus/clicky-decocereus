import { validateEvent } from "@polar-sh/sdk/webhooks"
import { and, eq, sql } from "drizzle-orm"

import { createDb } from "../db/client"
import {
  billingWebhookEvents,
  entitlements,
  polarCustomerLinks,
} from "../db/schema"
import type { Env } from "../env"
import { LAUNCH_ENTITLEMENT_DURATION_DAYS, LAUNCH_PRODUCT_KEY } from "../launch/config"

function requireWebhookSecret(env: Env) {
  if (!env.POLAR_WEBHOOK_SECRET) {
    throw new Error("POLAR_WEBHOOK_SECRET is required for Polar webhooks.")
  }

  return env.POLAR_WEBHOOK_SECRET
}

function addDays(date: Date, days: number) {
  const nextDate = new Date(date)
  nextDate.setUTCDate(nextDate.getUTCDate() + days)
  return nextDate
}

export async function processPolarWebhook(
  env: Env,
  body: string,
  headers: Headers,
) {
  const webhookSecret = requireWebhookSecret(env)
  const headerRecord = Object.fromEntries(headers.entries())
  const db = createDb(env)
  const event = validateEvent(body, headerRecord, webhookSecret)
  const eventId = headers.get("webhook-id")

  if (!eventId) {
    throw new Error("Polar webhook-id header is missing.")
  }

  const existingEvent = await db.query.billingWebhookEvents.findFirst({
    where: and(
      eq(billingWebhookEvents.provider, "polar"),
      eq(billingWebhookEvents.eventId, eventId),
    ),
  })

  if (existingEvent?.status === "processed") {
    return {
      duplicate: true,
      eventType: event.type,
    }
  }

  await db
    .insert(billingWebhookEvents)
    .values({
      provider: "polar",
      eventId,
      eventType: event.type,
      payload: event,
      status: "received",
    })
    .onConflictDoNothing({
      target: [billingWebhookEvents.provider, billingWebhookEvents.eventId],
    })

  if (event.type === "order.paid" && event.data.customer.externalId) {
    const userId = event.data.customer.externalId
    const refreshedAt = new Date()
    const grantedAt = event.data.createdAt
    const expiresAt = addDays(refreshedAt, LAUNCH_ENTITLEMENT_DURATION_DAYS)

    await db
      .insert(polarCustomerLinks)
      .values({
        userId,
        polarCustomerId: event.data.customerId,
        emailAtLinkTime: event.data.customer.email,
      })
      .onConflictDoUpdate({
        target: polarCustomerLinks.userId,
        set: {
          polarCustomerId: event.data.customerId,
          emailAtLinkTime: event.data.customer.email,
          updatedAt: sql`now()`,
        },
      })

    await db
      .insert(entitlements)
      .values({
        userId,
        productKey: LAUNCH_PRODUCT_KEY,
        status: "active",
        source: "polar",
        grantedAt,
        refreshedAt,
        expiresAt,
        rawReference: event.data.id,
        metadata: {
          checkoutId: event.data.checkoutId,
          customerId: event.data.customerId,
          orderId: event.data.id,
          discountId: event.data.discountId,
        },
      })
      .onConflictDoUpdate({
        target: [entitlements.userId, entitlements.productKey],
        set: {
          status: "active",
          source: "polar",
          grantedAt,
          refreshedAt,
          expiresAt,
          rawReference: event.data.id,
          metadata: {
            checkoutId: event.data.checkoutId,
            customerId: event.data.customerId,
            orderId: event.data.id,
            discountId: event.data.discountId,
          },
          updatedAt: sql`now()`,
        },
      })
  }

  if (event.type === "order.refunded" && event.data.customer.externalId) {
    const userId = event.data.customer.externalId
    await db
      .insert(entitlements)
      .values({
        userId,
        productKey: LAUNCH_PRODUCT_KEY,
        status: "refunded",
        source: "polar",
        refreshedAt: new Date(),
        expiresAt: new Date(),
        rawReference: event.data.id,
        metadata: {
          checkoutId: event.data.checkoutId,
          customerId: event.data.customerId,
          orderId: event.data.id,
          refundedAmount: event.data.refundedAmount,
        },
      })
      .onConflictDoUpdate({
        target: [entitlements.userId, entitlements.productKey],
        set: {
          status: "refunded",
          refreshedAt: new Date(),
          expiresAt: new Date(),
          rawReference: event.data.id,
          metadata: {
            checkoutId: event.data.checkoutId,
            customerId: event.data.customerId,
            orderId: event.data.id,
            refundedAmount: event.data.refundedAmount,
          },
          updatedAt: sql`now()`,
        },
      })
  }

  await db
    .update(billingWebhookEvents)
    .set({
      status: "processed",
      processedAt: new Date(),
      lastError: null,
    })
    .where(
      and(
        eq(billingWebhookEvents.provider, "polar"),
        eq(billingWebhookEvents.eventId, eventId),
      ),
    )

  return {
    duplicate: false,
    eventType: event.type,
  }
}
