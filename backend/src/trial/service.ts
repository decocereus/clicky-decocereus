import { and, eq, gt, sql } from "drizzle-orm"

import { createDb } from "../db/client"
import { launchTrialStates } from "../db/schema"
import type { Env } from "../env"
import { LAUNCH_TRIAL_INITIAL_CREDITS } from "../launch/config"

function defaultTrialSnapshot() {
  return {
    status: "inactive",
    initialCredits: LAUNCH_TRIAL_INITIAL_CREDITS,
    remainingCredits: LAUNCH_TRIAL_INITIAL_CREDITS,
    setupCompletedAt: null,
    trialActivatedAt: null,
    lastCreditConsumedAt: null,
    welcomePromptDeliveredAt: null,
    paywallActivatedAt: null,
  }
}

function isMissingLaunchTrialSchema(error: unknown) {
  if (typeof error !== "object" || error === null) {
    return false
  }

  const candidate = error as {
    cause?: { code?: string; message?: string }
    message?: string
  }

  const postgresCode = candidate.cause?.code
  const message = `${candidate.message ?? ""} ${candidate.cause?.message ?? ""}`.toLowerCase()

  if (postgresCode === "42P01" || postgresCode === "42704") {
    return message.includes("launch_trial_state") || message.includes("launch_trial_status")
  }

  return false
}

function serializeDate(value: Date | null | undefined) {
  return value ? value.toISOString() : null
}

function formatTrialState(trialState: {
  status: string
  initialCredits: number
  remainingCredits: number
  setupCompletedAt: Date | null
  trialActivatedAt: Date | null
  lastCreditConsumedAt: Date | null
  welcomePromptDeliveredAt: Date | null
  paywallActivatedAt: Date | null
}) {
  return {
    status: trialState.status,
    initialCredits: trialState.initialCredits,
    remainingCredits: trialState.remainingCredits,
    setupCompletedAt: serializeDate(trialState.setupCompletedAt),
    trialActivatedAt: serializeDate(trialState.trialActivatedAt),
    lastCreditConsumedAt: serializeDate(trialState.lastCreditConsumedAt),
    welcomePromptDeliveredAt: serializeDate(trialState.welcomePromptDeliveredAt),
    paywallActivatedAt: serializeDate(trialState.paywallActivatedAt),
  }
}

export async function getLaunchTrialSnapshot(env: Env, userId: string) {
  const db = createDb(env)
  let trialState: typeof launchTrialStates.$inferSelect | undefined

  try {
    trialState = await db.query.launchTrialStates.findFirst({
      where: eq(launchTrialStates.userId, userId),
    })
  } catch (error) {
    if (isMissingLaunchTrialSchema(error)) {
      console.warn("[clicky-backend] launch trial schema missing; returning default snapshot")
      return defaultTrialSnapshot()
    }

    throw error
  }

  if (!trialState) {
    return defaultTrialSnapshot()
  }

  return formatTrialState(trialState)
}

export async function activateLaunchTrial(env: Env, userId: string) {
  const db = createDb(env)
  const now = new Date()

  const [trialState] = await db
    .insert(launchTrialStates)
    .values({
      userId,
      status: "active",
      initialCredits: LAUNCH_TRIAL_INITIAL_CREDITS,
      remainingCredits: LAUNCH_TRIAL_INITIAL_CREDITS,
      setupCompletedAt: now,
      trialActivatedAt: now,
    })
    .onConflictDoUpdate({
      target: launchTrialStates.userId,
      set: {
        setupCompletedAt: sql`coalesce(${launchTrialStates.setupCompletedAt}, ${now})`,
        trialActivatedAt: sql`coalesce(${launchTrialStates.trialActivatedAt}, ${now})`,
        updatedAt: now,
      },
    })
    .returning()

  return formatTrialState(trialState)
}

export async function consumeLaunchTrialCredit(env: Env, userId: string) {
  const db = createDb(env)
  const now = new Date()

  const [updatedTrialState] = await db
    .update(launchTrialStates)
    .set({
      remainingCredits: sql`${launchTrialStates.remainingCredits} - 1`,
      status: sql`case when ${launchTrialStates.remainingCredits} - 1 <= 0 then 'armed'::launch_trial_status else 'active'::launch_trial_status end`,
      lastCreditConsumedAt: now,
      updatedAt: now,
    })
    .where(
      and(
        eq(launchTrialStates.userId, userId),
        gt(launchTrialStates.remainingCredits, 0),
      ),
    )
    .returning()

  if (!updatedTrialState) {
    const existingTrialState = await db.query.launchTrialStates.findFirst({
      where: eq(launchTrialStates.userId, userId),
    })

    if (!existingTrialState) {
      return {
        ok: false as const,
        reason: "trial_not_activated",
      }
    }

    return {
      ok: false as const,
      reason: existingTrialState.status === "paywalled" ? "paywall_active" : "no_credits_remaining",
      trial: formatTrialState(existingTrialState),
    }
  }

  return {
    ok: true as const,
    paywallArmed: updatedTrialState.remainingCredits == 0,
    trial: formatTrialState(updatedTrialState),
  }
}

export async function markLaunchTrialPaywalled(env: Env, userId: string) {
  const db = createDb(env)
  const now = new Date()

  const [updatedTrialState] = await db
    .update(launchTrialStates)
    .set({
      status: "paywalled",
      paywallActivatedAt: now,
      updatedAt: now,
    })
    .where(eq(launchTrialStates.userId, userId))
    .returning()

  if (!updatedTrialState) {
    return null
  }

  return formatTrialState(updatedTrialState)
}

export async function markLaunchTrialWelcomeDelivered(env: Env, userId: string) {
  const db = createDb(env)
  const now = new Date()

  const [updatedTrialState] = await db
    .update(launchTrialStates)
    .set({
      welcomePromptDeliveredAt: sql`coalesce(${launchTrialStates.welcomePromptDeliveredAt}, ${now})`,
      updatedAt: now,
    })
    .where(eq(launchTrialStates.userId, userId))
    .returning()

  if (!updatedTrialState) {
    return null
  }

  return formatTrialState(updatedTrialState)
}
