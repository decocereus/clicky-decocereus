import type { Context } from "hono"

import { requireSession } from "../auth/session"
import type { Env } from "../env"
import {
  activateLaunchTrial,
  consumeLaunchTrialCredit,
  getLaunchTrialSnapshot,
  markLaunchTrialPaywalled,
} from "./service"

export async function handleGetTrial(c: Context<{ Bindings: Env }>) {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const trial = await getLaunchTrialSnapshot(c.env, sessionResult.session.user.id)

  return c.json({
    userId: sessionResult.session.user.id,
    trial,
  })
}

export async function handleActivateTrial(c: Context<{ Bindings: Env }>) {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const trial = await activateLaunchTrial(c.env, sessionResult.session.user.id)

  return c.json({
    userId: sessionResult.session.user.id,
    trial,
  })
}

export async function handleConsumeTrialCredit(c: Context<{ Bindings: Env }>) {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const result = await consumeLaunchTrialCredit(c.env, sessionResult.session.user.id)

  if (!result.ok) {
    return c.json(
      {
        userId: sessionResult.session.user.id,
        reason: result.reason,
        trial: result.trial ?? null,
      },
      409,
    )
  }

  return c.json({
    userId: sessionResult.session.user.id,
    paywallArmed: result.paywallArmed,
    trial: result.trial,
  })
}

export async function handleMarkTrialPaywalled(c: Context<{ Bindings: Env }>) {
  const sessionResult = await requireSession(c)

  if (!sessionResult.ok) {
    return sessionResult.response
  }

  const trial = await markLaunchTrialPaywalled(c.env, sessionResult.session.user.id)

  if (!trial) {
    return c.json(
      {
        error: "Launch trial is not activated for this user.",
      },
      404,
    )
  }

  return c.json({
    userId: sessionResult.session.user.id,
    trial,
  })
}
