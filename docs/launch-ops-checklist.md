# Launch Ops Checklist

Status note:

- this checklist is still current
- the items here remain mostly operational verification work rather than missing application code

Use this as the operational checklist before shipping a new Clicky build.

## Launch Run Order

When we are ready to do the real launch pass, run the steps in this order:

- [ ] Confirm production auth, backend, Polar, and Sparkle configuration.
- [ ] Build and ship one real Clicky release artifact plus updated `appcast.xml`.
- [ ] Verify one real Google sign-in flow in the Mac app.
- [ ] Verify one real Polar purchase from the Mac app with webhook delivery.
- [ ] Verify entitlement refresh after purchase.
- [ ] Verify restore on a returning or reinstalled app.
- [ ] Verify one real Sparkle update check against the published Clicky appcast.
- [ ] Write down every failure or awkward edge before touching polish.

## 1. Google Auth

- Confirm the Better Auth backend is deployed and reachable at the production API base URL.
- Verify the Google OAuth client is configured with the production Better Auth callback URL.
- Verify the native handoff route is reachable:
  - `GET /v1/auth/native/start`
  - `GET /v1/auth/native/callback`
  - `POST /v1/auth/native/exchange`

## 2. Backend Environment

- Confirm `BETTER_AUTH_SECRET` is set.
- Confirm `BETTER_AUTH_URL` points at the production backend hostname.
- Confirm `WEB_ORIGIN` matches the production website origin.
- Confirm `DATABASE_URL` points at the production Neon database.
- Confirm `MAC_APP_SCHEME` matches `clicky`.
- Confirm `POLAR_ACCESS_TOKEN` is set.
- Confirm `POLAR_LAUNCH_PRODUCT_ID` is set.
- Confirm `POLAR_WEBHOOK_SECRET` is set.
- Confirm any optional discount or OpenClaw environment values are correct for production.

## 3. Polar

- Confirm the launch product exists in Polar and matches the one-time launch offer.
- Confirm the public backend webhook URL is configured in Polar.
- Confirm the webhook secret in Polar matches `POLAR_WEBHOOK_SECRET`.
- Confirm the success and cancel callback URLs point back through the backend billing callback routes.

## 4. Sparkle / Updates

- Confirm the real Sparkle package is resolved in Xcode.
- Confirm `SUFeedURL` in the app points at the Clicky appcast feed.
- Confirm `SUPublicEDKey` matches the EdDSA key used by the release script.
- Confirm `appcast.xml` in the repo references Clicky DMGs, not legacy artifacts.
- Confirm the running app starts Sparkle without runtime loader errors.
- Confirm the `Check for Updates…` command is present and enabled.

## 5. Release Preparation

- Build the app in Xcode at least once so Sparkle tools are present in DerivedData.
- Confirm your Developer ID signing identity is available on this Mac.
- Confirm notarization credentials are stored with `xcrun notarytool`.
- Confirm `gh auth login` is valid for `decocereus/clicky-decocereus`.
- Confirm `create-dmg` and `gh` are installed.

## 6. Release Run

- Run `./scripts/release.sh`.
- Verify the script:
  - archives the `leanring-buddy` scheme
  - exports a signed app
  - creates and notarizes the DMG
  - signs the DMG with the Sparkle EdDSA key
  - regenerates `appcast.xml`
  - creates the GitHub Release
  - commits and pushes the updated `appcast.xml`

## 7. Post-Release Verification

- Verify the GitHub Release exists and the DMG is downloadable.
- Verify the repo `appcast.xml` was updated and pushed.
- Verify the running app can start the Sparkle updater without runtime errors.
- Verify one real install can see the published build and one real update flow behaves correctly.

## 8. Launch Flow Sanity Check

- Verify one real Google sign-in flow in the Mac app.
- Verify one real purchase flow with webhook delivery.
- Verify entitlement refresh after purchase.
- Verify restore on a returning or reinstalled app.
- Verify the launch trial and paywall states still behave as expected for non-purchased users.

## 9. Capture Results

Use this section as the lightweight launch-day punch list after the first real run:

- [ ] Google sign-in worked end to end.
- [ ] Native auth handoff returned to `clicky://auth/callback`.
- [ ] Polar checkout opened from the Mac app.
- [ ] Polar webhook was received by the public backend.
- [ ] Entitlement flipped to active after purchase.
- [ ] `Refresh Access` reflected the new entitlement.
- [ ] `Restore Access` worked on a returning/reinstalled app.
- [ ] Refunded/revoked or expired-grace states behaved acceptably.
- [ ] Sparkle `Check for Updates…` could read the published Clicky appcast.
- [ ] Sparkle could see the published release as a valid update when expected.
- [ ] Any failures were recorded with exact timestamps and error messages.
