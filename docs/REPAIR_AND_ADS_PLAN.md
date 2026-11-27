# Near Me — Repair and Release Plan

This branch contains focused fixes discovered during the GitHub audit. It does not replace the existing product architecture or remove existing features.

## Changes implemented in this branch

- Discovery now reads the signed-in member's `preferences.genders` and applies it to candidate selection. An empty selection intentionally means all available genders.
- Discovery excludes profiles the current member has already swiped, preventing repeated recommendations after Like, Super Like, Favorite, or Pass.
- Near Me swipe actions now call the backend for Pass, Like, and Super Like. The card advances only after the server confirms the action; failures keep the current card visible. Match responses are surfaced to the member.
- Registration now accepts and persists preferred discovery genders.
- Customer profile editing now supports updating the member's own gender and preferred discovery genders.
- AdMob client logic now enforces the Owner-configured `max_per_session` cap per placement during the running app session.

## Advertising is a preserved product requirement

Do not delete, rename, silently move, or bypass the existing ad system.

The fixed Owner-controlled placements remain:
- `home_feed`: banner, shown only when enabled by the Owner.
- `tab_transition`: interstitial, only at a natural tab transition and subject to the configured minimum gap.
- `rewarded_cosmetic`: optional, user-initiated rewarded ad for non-cash cosmetic rewards only.

All placements are disabled by default. The Owner controls enabled state, minimum gap, and maximum impressions per session through the existing ad configuration API.

Ads must never appear in chat threads, authentication/onboarding, PIN lock, verification, appeals, support, reporting, blocking, account deletion, or safety flows. Never add ads to these screens as part of a redesign. Rewarded ads must remain optional and must not gate essential functionality, matching, messaging, or account safety.

The app currently defaults to Google's official test ad unit IDs. Production release must use Owner-supplied production AdMob IDs through build-time configuration; never ship test IDs as production IDs.

## Verification still required

- Run backend unit, database, integration, typecheck, and production build workflows.
- Run Flutter analyze/tests and build all three apps against the verified HTTPS production backend.
- Test the discovery regression cases with multiple real test accounts (male/female/other), including empty gender preferences, selected genders, Pass persistence, and mutual matching.
- Verify all fixed ad placements with test IDs and consent flow; verify Owner configuration, frequency gap, per-session caps, and forbidden-screen exclusions.
- Verify live provider configuration for email, FCM, object storage, malware scanning, and realtime. Provider adapters currently return explicit not-configured/provider-error results where credentials or vendor integrations are absent; do not represent those integrations as live until verified.
- Verify production database migrations, backups and restore, domain/backend health, and Android release signing.
- Complete a security review and device-level QA before production release.

## Important release rule

A successful Debug APK build or CI workflow is not proof of production readiness. Do not merge this branch or publish a release until the relevant CI jobs, live-service checks, and manual device tests pass.
