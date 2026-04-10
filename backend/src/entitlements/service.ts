import { and, eq } from "drizzle-orm"

import { createDb } from "../db/client"
import { entitlements } from "../db/schema"
import type { Env } from "../env"
import {
  LAUNCH_PRODUCT_KEY,
  OFFLINE_UNLOCK_GRACE_DAYS,
} from "../launch/config"

function addDays(date: Date, days: number) {
  const nextDate = new Date(date)
  nextDate.setUTCDate(nextDate.getUTCDate() + days)
  return nextDate
}

function serializeDate(value: Date | null | undefined) {
  return value ? value.toISOString() : null
}

export async function getLaunchEntitlementSnapshot(env: Env, userId: string) {
  const db = createDb(env)

  const entitlement = await db.query.entitlements.findFirst({
    where: and(
      eq(entitlements.userId, userId),
      eq(entitlements.productKey, LAUNCH_PRODUCT_KEY),
    ),
  })

  if (!entitlement) {
    return {
      productKey: LAUNCH_PRODUCT_KEY,
      status: "inactive",
      hasAccess: false,
      source: null,
      grantedAt: null,
      refreshedAt: null,
      expiresAt: null,
      rawReference: null,
      gracePeriodEndsAt: null,
    }
  }

  const gracePeriodEndsAt =
    entitlement.status === "active"
      ? addDays(entitlement.refreshedAt, OFFLINE_UNLOCK_GRACE_DAYS)
      : null

  return {
    productKey: entitlement.productKey,
    status: entitlement.status,
    hasAccess: entitlement.status === "active",
    source: entitlement.source,
    grantedAt: serializeDate(entitlement.grantedAt),
    refreshedAt: serializeDate(entitlement.refreshedAt),
    expiresAt: serializeDate(entitlement.expiresAt),
    rawReference: entitlement.rawReference,
    gracePeriodEndsAt: serializeDate(gracePeriodEndsAt),
  }
}
