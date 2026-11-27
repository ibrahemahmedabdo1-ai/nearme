# NEAR ME — read this first (status as of 2026-11-27)

This repository contains three Flutter Android apps (Customer, Admin, Support), a Next.js backend, PostgreSQL migrations, and shared packages.

## Verified baseline on `main`

| Area | Evidence |
|---|---|
| Backend CI | The latest `main` backend workflow on 2026-11-23 completed successfully, including tests, DB integration, typecheck, and build. |
| Mobile CI | The latest `main` mobile workflow on 2026-11-23 completed successfully and produced three **Debug APK** artifacts (Customer, Admin, Support). |
| Production release | Not verified. Debug APKs are not signed production releases/AABs. |
| Live services | Must be checked independently. A successful build does not prove Vercel, Neon, email, FCM, storage, realtime, AI moderation, malware scanning, or social APIs are all configured and operational. |
| Google Play approval | Cannot be guaranteed; review `PLAY_COMPLIANCE.md`. |

## Current repair branch

Branch: `fix/nearme-complete-audit`  
Draft PR: https://github.com/ibrahemahmedabdo1-ai/nearme/pull/2

Changes in progress:
- Apply member gender preferences in discovery.
- Stop recommending profiles already swiped by the member.
- Persist Pass, Like, and Super Like from the Near Me screen; do not silently advance on request failure.
- Save preferred genders during registration and allow members to edit their own gender and discovery preferences.
- Enforce Owner-configured AdMob per-placement session caps.
- Add Owner-only AdMob controls for enabling placements and tuning frequency/session limits.
- Add regression tests and document advertising/release rules.

CI for this branch is still running. Do not treat this branch as release-ready until both backend and mobile PR workflows pass.

## Advertising — preserve these fixed placements

- `home_feed`: banner.
- `tab_transition`: interstitial only at a natural tab transition, respecting the configured minimum gap.
- `rewarded_cosmetic`: optional, user-initiated rewarded ad for non-cash cosmetic rewards.

All placements are disabled by default and Owner-controlled. No ads are permitted in chat threads, authentication/onboarding, PIN lock, verification, appeals, support, reporting, blocking, account deletion, or safety flows. Production AdMob IDs must be configured at build time; Google's test IDs must never ship in a production build.

## Release gates still required

1. Pass backend unit, PostgreSQL, integration, typecheck, and Next.js build workflows on the repair branch.
2. Pass Flutter analyze/tests and build Customer, Admin, and Support against a verified HTTPS backend.
3. Test gender filtering, empty preferences, Pass persistence, rewind window, mutual matching, and multi-account behavior.
4. Test consent, all ad placements, Owner controls, minimum gaps, session caps, and forbidden-screen exclusions.
5. Verify live Vercel/Neon, migrations, backup/restore, email, FCM, object storage, malware scanning, and realtime providers.
6. Complete security review, physical-device QA, and Android release signing before production rollout.

See `FEATURES.md`, `SECURITY.md`, `CONTINUATION.md`, and `REPAIR_AND_ADS_PLAN.md` for detailed status and remaining work.
