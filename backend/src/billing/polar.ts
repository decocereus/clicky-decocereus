import { Polar } from "@polar-sh/sdk"

import { readEnvValue, type Env } from "../env"

function requireValue(value: string | undefined, name: string) {
  if (!value) {
    throw new Error(`${name} is required for Polar integration.`)
  }

  return value
}

export function createPolarClient(env: Env) {
  return new Polar({
    accessToken: requireValue(readEnvValue(env, "POLAR_ACCESS_TOKEN"), "POLAR_ACCESS_TOKEN"),
  })
}
