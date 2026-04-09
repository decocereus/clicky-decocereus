import { Polar } from "@polar-sh/sdk"

import type { Env } from "../env"

function requireValue(value: string | undefined, name: string) {
  if (!value) {
    throw new Error(`${name} is required for Polar integration.`)
  }

  return value
}

export function createPolarClient(env: Env) {
  return new Polar({
    accessToken: requireValue(env.POLAR_ACCESS_TOKEN, "POLAR_ACCESS_TOKEN"),
  })
}
