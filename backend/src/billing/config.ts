import { LAUNCH_PRODUCT_KEY } from "../launch/config"
import type { Env } from "../env"

type BillingOutcome = "success" | "cancel"

export function getLaunchCheckoutConfig(env: Env) {
  const apiBaseUrl = env.BETTER_AUTH_URL
  const appScheme = env.MAC_APP_SCHEME ?? "clicky"

  return {
    productKey: LAUNCH_PRODUCT_KEY,
    polarProductId: env.POLAR_LAUNCH_PRODUCT_ID ?? null,
    polarDiscountId: env.POLAR_LAUNCH_DISCOUNT_ID ?? null,
    successUrl: apiBaseUrl ? `${apiBaseUrl}/v1/billing/callback/success` : null,
    cancelUrl: apiBaseUrl ? `${apiBaseUrl}/v1/billing/callback/cancel` : null,
    nativeSuccessUrl: `${appScheme}://billing/success`,
    nativeCancelUrl: `${appScheme}://billing/cancel`,
  }
}

export function buildNativeBillingCallbackUrl(
  env: Env,
  outcome: BillingOutcome,
  searchParams?: URLSearchParams,
) {
  const appScheme = env.MAC_APP_SCHEME ?? "clicky"
  const url = new URL(`${appScheme}://billing/${outcome}`)

  if (searchParams) {
    for (const [key, value] of searchParams.entries()) {
      url.searchParams.set(key, value)
    }
  }

  return url.toString()
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
