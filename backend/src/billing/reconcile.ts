import type { Customer } from "@polar-sh/sdk/models/components/customer.js"
import type { Order } from "@polar-sh/sdk/models/components/order.js"
import { and, eq, sql } from "drizzle-orm"

import { createDb } from "../db/client"
import { entitlements, polarCustomerLinks } from "../db/schema"
import type { Env } from "../env"
import { getLaunchEntitlementSnapshot } from "../entitlements/service"
import {
  LAUNCH_ENTITLEMENT_DURATION_DAYS,
  LAUNCH_PRODUCT_KEY,
} from "../launch/config"
import { createPolarClient } from "./polar"

type LaunchProviderStatus =
  | "active"
  | "inactive"
  | "refunded"
  | "unconfigured"

type LaunchProviderState = {
  checkedAt: string
  customerId: string | null
  didCheckProvider: boolean
  orderId: string | null
  status: LaunchProviderStatus
}

function addDays(date: Date, days: number) {
  const nextDate = new Date(date)
  nextDate.setUTCDate(nextDate.getUTCDate() + days)
  return nextDate
}

function extractStatusCode(error: unknown) {
  if (typeof error !== "object" || error === null) {
    return undefined
  }

  if ("statusCode" in error) {
    return Number((error as { statusCode: unknown }).statusCode)
  }

  if ("status" in error) {
    return Number((error as { status: unknown }).status)
  }

  return undefined
}

function isNotFoundError(error: unknown) {
  return extractStatusCode(error) === 404
}

function resolveLaunchProviderState(orders: Order[]) {
  const latestOrder = [...orders]
    .sort((leftOrder, rightOrder) => rightOrder.createdAt.getTime() - leftOrder.createdAt.getTime())
    .at(0) ?? null

  if (!latestOrder) {
    return {
      latestOrder: null,
      status: "inactive" as const,
    }
  }

  if (
    latestOrder.status === "refunded"
    || latestOrder.refundedAmount >= latestOrder.totalAmount
  ) {
    return {
      latestOrder,
      status: "refunded" as const,
    }
  }

  if (latestOrder.paid || latestOrder.status === "paid" || latestOrder.status === "partially_refunded") {
    return {
      latestOrder,
      status: "active" as const,
    }
  }

  return {
    latestOrder,
    status: "inactive" as const,
  }
}

async function upsertPolarCustomerLink(env: Env, userId: string, customer: Customer) {
  const db = createDb(env)

  await db
    .insert(polarCustomerLinks)
    .values({
      userId,
      polarCustomerId: customer.id,
      emailAtLinkTime: customer.email,
    })
    .onConflictDoUpdate({
      target: polarCustomerLinks.userId,
      set: {
        polarCustomerId: customer.id,
        emailAtLinkTime: customer.email,
        updatedAt: sql`now()`,
      },
    })
}

async function resolvePolarCustomer(env: Env, userId: string) {
  const db = createDb(env)
  const polarClient = createPolarClient(env)
  const existingLink = await db.query.polarCustomerLinks.findFirst({
    where: eq(polarCustomerLinks.userId, userId),
  })

  if (existingLink) {
    try {
      const linkedCustomer = await polarClient.customers.get({
        id: existingLink.polarCustomerId,
      })
      await upsertPolarCustomerLink(env, userId, linkedCustomer)
      return linkedCustomer
    } catch (error) {
      if (!isNotFoundError(error)) {
        throw error
      }
    }
  }

  try {
    const customer = await polarClient.customers.getExternal({
      externalId: userId,
    })
    await upsertPolarCustomerLink(env, userId, customer)
    return customer
  } catch (error) {
    if (isNotFoundError(error)) {
      return null
    }

    throw error
  }
}

async function listLaunchOrdersForCustomer(
  env: Env,
  customerId: string,
  productId: string,
) {
  const polarClient = createPolarClient(env)
  const pages = await polarClient.orders.list({
    customerId,
    productId,
    limit: 100,
  })
  const orders: Order[] = []

  for await (const page of pages) {
    orders.push(...page.result.items)
  }

  return orders
}

async function persistInactiveLaunchEntitlement(env: Env, userId: string) {
  const db = createDb(env)
  const existingEntitlement = await db.query.entitlements.findFirst({
    where: and(
      eq(entitlements.userId, userId),
      eq(entitlements.productKey, LAUNCH_PRODUCT_KEY),
    ),
  })

  if (!existingEntitlement) {
    return
  }

  if (existingEntitlement.status !== "active") {
    return
  }

  const now = new Date()
  const existingMetadata =
    (existingEntitlement.metadata as Record<string, unknown> | undefined) ?? {}

  await db
    .insert(entitlements)
    .values({
      userId,
      productKey: LAUNCH_PRODUCT_KEY,
      status: "revoked",
      source: "polar",
      grantedAt: existingEntitlement.grantedAt,
      refreshedAt: now,
      expiresAt: now,
      rawReference: existingEntitlement.rawReference,
      metadata: {
        ...existingMetadata,
        syncReason: "polar_refresh_no_purchase",
      },
    })
    .onConflictDoUpdate({
      target: [entitlements.userId, entitlements.productKey],
      set: {
        status: "revoked",
        refreshedAt: now,
        expiresAt: now,
        metadata: {
          ...existingMetadata,
          syncReason: "polar_refresh_no_purchase",
        },
        updatedAt: sql`now()`,
      },
    })
}

async function persistLaunchEntitlementOrder(
  env: Env,
  userId: string,
  customer: Customer,
  order: Order,
  status: "active" | "refunded",
) {
  const db = createDb(env)
  const refreshedAt = new Date()
  const expiresAt = status === "active"
    ? addDays(refreshedAt, LAUNCH_ENTITLEMENT_DURATION_DAYS)
    : refreshedAt

  await db
    .insert(entitlements)
    .values({
      userId,
      productKey: LAUNCH_PRODUCT_KEY,
      status,
      source: "polar",
      grantedAt: order.createdAt,
      refreshedAt,
      expiresAt,
      rawReference: order.id,
      metadata: {
        checkoutId: order.checkoutId,
        customerId: customer.id,
        orderId: order.id,
        orderStatus: order.status,
        refundedAmount: order.refundedAmount,
        syncedVia: "polar-refresh",
      },
    })
    .onConflictDoUpdate({
      target: [entitlements.userId, entitlements.productKey],
      set: {
        status,
        source: "polar",
        grantedAt: order.createdAt,
        refreshedAt,
        expiresAt,
        rawReference: order.id,
        metadata: {
          checkoutId: order.checkoutId,
          customerId: customer.id,
          orderId: order.id,
          orderStatus: order.status,
          refundedAmount: order.refundedAmount,
          syncedVia: "polar-refresh",
        },
        updatedAt: sql`now()`,
      },
    })
}

export async function reconcileLaunchEntitlementFromPolar(env: Env, userId: string) {
  const checkedAt = new Date().toISOString()
  const launchProductId = env.POLAR_LAUNCH_PRODUCT_ID?.trim()

  if (!env.POLAR_ACCESS_TOKEN || !launchProductId) {
    return {
      entitlement: await getLaunchEntitlementSnapshot(env, userId),
      providerState: {
        checkedAt,
        customerId: null,
        didCheckProvider: false,
        orderId: null,
        status: "unconfigured" as const,
      },
    }
  }

  const customer = await resolvePolarCustomer(env, userId)

  if (!customer) {
    await persistInactiveLaunchEntitlement(env, userId)

    return {
      entitlement: await getLaunchEntitlementSnapshot(env, userId),
      providerState: {
        checkedAt,
        customerId: null,
        didCheckProvider: true,
        orderId: null,
        status: "inactive" as const,
      },
    }
  }

  const orders = await listLaunchOrdersForCustomer(env, customer.id, launchProductId)
  const providerResolution = resolveLaunchProviderState(orders)

  if (providerResolution.status === "active" && providerResolution.latestOrder) {
    await persistLaunchEntitlementOrder(
      env,
      userId,
      customer,
      providerResolution.latestOrder,
      "active",
    )
  } else if (providerResolution.status === "refunded" && providerResolution.latestOrder) {
    await persistLaunchEntitlementOrder(
      env,
      userId,
      customer,
      providerResolution.latestOrder,
      "refunded",
    )
  } else {
    await persistInactiveLaunchEntitlement(env, userId)
  }

  return {
    entitlement: await getLaunchEntitlementSnapshot(env, userId),
    providerState: {
      checkedAt,
      customerId: customer.id,
      didCheckProvider: true,
      orderId: providerResolution.latestOrder?.id ?? null,
      status: providerResolution.status,
    } satisfies LaunchProviderState,
  }
}
