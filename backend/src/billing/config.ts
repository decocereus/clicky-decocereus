import { LAUNCH_PRODUCT_KEY } from "../launch/config"
import type { Env } from "../env"

export function getLaunchCheckoutConfig(env: Env) {
  const apiBaseUrl = env.BETTER_AUTH_URL
  const appScheme = env.MAC_APP_SCHEME ?? "clicky"

  return {
    productKey: LAUNCH_PRODUCT_KEY,
    polarProductId: env.POLAR_LAUNCH_PRODUCT_ID ?? null,
    successUrl: apiBaseUrl ? `${apiBaseUrl}/v1/billing/callback/success` : null,
    cancelUrl: apiBaseUrl ? `${apiBaseUrl}/v1/billing/callback/cancel` : null,
    nativeSuccessUrl: `${appScheme}://billing/success`,
    nativeCancelUrl: `${appScheme}://billing/cancel`,
  }
}

export function getMissingCheckoutConfiguration(env: Env) {
  const missing: string[] = []

  if (!env.BETTER_AUTH_URL) {
    missing.push("BETTER_AUTH_URL")
  }

  if (!env.POLAR_ACCESS_TOKEN) {
    missing.push("POLAR_ACCESS_TOKEN")
  }

  if (!env.POLAR_LAUNCH_PRODUCT_ID) {
    missing.push("POLAR_LAUNCH_PRODUCT_ID")
  }

  return missing
}
