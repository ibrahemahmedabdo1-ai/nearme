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


## Launch-readiness work added on 2026-11-27

- UMP consent lifecycle is now awaited with a bounded timeout and fail-closed behavior; privacy options are exposed when UMP says they are required.
- Customer banner placements listen for consent resolution and are disposed if ad-request eligibility is withdrawn.
- Android bootstrap uses a parameterized AdMob app ID instead of hardcoding a test app ID in the manifest. Debug builds retain Google's test fallback; release builds must supply production identifiers.
- Added `scripts/verify-release-admob.sh`; `scripts/build-all.sh` now requires HTTPS API URL, production AdMob IDs, Flutter analyze/tests, and release signing configuration before building APK/AABs.
- Customer signup now links to Terms, Privacy Policy, and Community Guidelines. Added the public Community Guidelines page.
- Customer login re-checks stored birthdate age for existing accounts; a regression test covers blocking a pre-existing under-18 account.

## Current blockers (do not bypass)

- Latest GitHub Actions backend/mobile runs visible to this audit remain queued; no passing final-head CI result has been verified.
- Vercel reported the free-tier daily deployment limit. A previous preview deployment was Ready, but the newest head has no verified fresh deployment.
- Privacy Policy, Terms, and Child Safety pages still contain operator/legal placeholders. Add the real legal entity and monitored privacy/child-safety contact details, and obtain legal review.
- Owner must configure Play Console age-restricted functionality to block minors for the dating/matchmaking core feature; the in-app/server age gate does not replace this Console control.
- Owner must configure AdMob Privacy & messaging, real production app/ad unit IDs, and verify UMP behavior in applicable regions.
- Owner must create and securely back up the three upload keystores / configure signing secrets. Signed-release CI remains intentionally disabled.
- No production APK/AAB has been generated or delivered from this branch; Debug APK CI artifacts, if produced, are not store-ready releases.

Current PR remains a draft and is not merged: https://github.com/ibrahemahmedabdo1-ai/nearme/pull/2


## Additional continuation work (2026-11-27)

- AdMob requests are now capped globally at the PG content rating before SDK initialization. The publisher still must configure sensitive-category and advertiser controls in AdMob.
- Banner, Interstitial, and Rewarded session caps now count actual impression callbacks, not successful loads.
- Both backend and Flutter policy mirrors now prohibit ads in authentication, registration, onboarding, support/ticketing, moderation, child-safety, appeals, account deletion, and the existing safety flows. Backend and Flutter tests cover the expanded list.
- Release script now requires per-app upload key files, verifies the Gradle release signing configuration, validates signed APK/AAB outputs, and restores any pre-existing local key.properties files after build.
- GitHub Actions now limits branch push checks to main, runs PR checks against main, and cancels stale runs to reduce duplicate queueing.
- Latest head at this update: `3621e1fe2b1bd81da131c16eb563eba23b499627`. Backend and mobile CI jobs are still queued; Vercel preview deployments currently correspond to older commits only.

- UMP privacy-options visibility now refreshes when consent state finishes loading, so the required entry point is not missed by an early profile render.
- Rewarded ad presentation now releases its in-flight lock and completes safely if the SDK rejects the show call.
- Current branch head: `6d78bd3f5ac50872bc07b7e9c55b43f5405d916e`. Latest mobile/backend Actions runs have been queued; earlier runs were cancelled by the stale-run concurrency rule. No final-head green CI result is available yet.
