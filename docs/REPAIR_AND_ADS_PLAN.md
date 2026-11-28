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

The currently implemented Owner-controlled placements are:
- `home_feed`: banner, shown only when enabled by the Owner.
- `tab_transition`: interstitial, only at a natural tab transition and subject to the configured minimum gap.
- `rewarded_cosmetic`: optional, user-initiated rewarded ad for non-cash cosmetic rewards only.

All six placements are disabled by default. The Owner can disable placements or choose lower delivery limits. Server-side hard caps cannot be raised remotely: Banner 4/session and 120-second gap; Native 3/session and 90-second gap; Interstitial 3/session and 180-second gap (plus two eligible tab transitions); Rewarded 5/session and user-initiated; App Open 1/session and 4-hour gap; Rewarded Interstitial 2/session and 5-minute gap. Admin displays the non-overridable limits.

Ads must never appear in chat threads, authentication/onboarding, PIN lock, verification, appeals, support, reporting, blocking, account deletion, or safety flows. Never add ads to these screens as part of a redesign. Rewarded ads must remain optional and must not gate essential functionality, matching, messaging, or account safety.

The app currently defaults to Google's official test ad unit IDs. Production release must use all six Owner-supplied production AdMob IDs through build-time configuration; never ship test IDs as production IDs.

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


## Google Play / AdMob compliance gates (required before release)

These are release requirements, not claims that Google has approved the app:

- The app's core discovery/matching functionality is dating/matchmaking-oriented. Configure the Play Console target-audience and age controls so minors are blocked from the dating/matchmaking experience, and verify the in-app age/eligibility gate cannot be bypassed by editing local state or calling APIs directly. Do not market the app to children.
- Treat profiles, photos, bios, interests, and messages as user-generated content. Require acceptance of Terms and Community Guidelines before upload/use; provide in-app report and block controls; operate timely moderation and appeal handling; enforce repeat-offender actions; and ensure moderation is available to users, not just as a decorative UI.
- Ads are part of the app's content. Keep ad content appropriate for the app's declared content rating and exclude ads from all authentication, onboarding, chat, verification, reporting, blocking, appeals, support, account deletion, and safety journeys.
- Interstitials may only appear at an expected, natural break in app content. Never show on launch, exit, immediately after returning from background, during a form/task, or on every swipe/tap. The client now requires at least two eligible tab-transition opportunities between interstitial displays in addition to the Owner-configured minimum gap and session cap. Keep this safeguard non-removable by remote configuration.
- Rewarded ads must be explicitly user-initiated, clearly explain the optional non-cash cosmetic reward before showing, and never gate matching, messaging, visibility, account safety, or other essential functionality. Do not reward ad clicks.
- Keep Google's official test ad unit IDs in development only. Production IDs must be supplied through release build configuration; add a release CI guard that fails if test IDs or placeholders are present in a production artifact.
- Complete the Play Console Data safety form and in-app privacy policy consistently with actual app behavior and every SDK (including ads, analytics, crash reporting, messaging, storage, and authentication). Request permissions only when needed and after contextual explanation; do not collect background location.
- Complete the applicable consent flow before requesting ads where required. If consent information is unavailable or the user cannot be served ads, fail closed and do not request ads until eligibility is resolved.
- Verify app content rating, privacy policy URL, account deletion path, UGC moderation, developer contact details, SDK versions, and all required Play Console declarations before submission.

Official policy references reviewed on 2026-11-27:
- Google Play Developer Program Policy: https://support.google.com/googleplay/android-developer/answer/18265346
- Google Play Ads policy: https://support.google.com/googleplay/android-developer/answer/9857753
- Google Play User Data / Data safety: https://support.google.com/googleplay/android-developer/answer/10144311
- AdMob disallowed interstitial implementations: https://support.google.com/admob/answer/6201362
- AdMob invalid traffic: https://support.google.com/admob/answer/3342054

A policy checklist is not a substitute for reviewing the actual app, SDK disclosures, Play Console declarations, and live ad behavior. Google makes the final approval decision.

- The Android bootstrap patch now uses the `ADMOB_APP_ID` Gradle manifest placeholder. Local/debug builds default to Google's official TEST app ID; production builds must inject the real app ID.
- `scripts/verify-release-admob.sh` fails closed unless the app ID and all six production ad-unit IDs are supplied and correctly formatted. It rejects Google's test IDs and placeholders.
- The Customer app now exposes the UMP privacy-options entry point only when UMP reports that it is required. The ad service also waits for consent resolution, fails closed on a consent timeout, and notifies banner placements when consent becomes available so they can load safely.
- The Customer ad service uses all six fixed Owner-controlled placements and records impressions from SDK impression callbacks. App Open is withheld until after the first few launches, expires cached ads after four hours, and persists its four-hour cooldown across app restarts.
- The GitHub mobile workflow currently builds DEBUG APKs only. The signed-release job remains disabled until the Owner configures secure signing secrets and production AdMob IDs; do not describe debug APKs as store-ready releases.


## Ad delivery hardening added after the initial audit

- The Admin API now enforces non-overridable per-placement frequency ceilings and minimum gaps on the server, rather than trusting only the Admin UI.
- Owner controls now display the hard safety ceilings returned by the server. Attempts to configure higher frequency are clamped to the policy limit.
- The account currently has six AdMob ad units, but only Banner, Interstitial, and Rewarded are wired in the Customer client. Native, App Open, and Rewarded Interstitial remain explicitly unintegrated; they require their own UI lifecycle, consent-aware load/show behavior, format-specific frequency controls, and tests before activation.
- Chat lists and private chat threads remain excluded. Do not place AdMob inventory in direct messaging; this restriction is intentional to avoid policy risk.


## Six-format AdMob implementation status (2026-11-27)

All six publisher-console units now have distinct client-side format integrations and Owner-controlled server placements. Every placement remains disabled by default and must be enabled explicitly after the app is approved and tested.

- Banner `home_feed`: existing fixed home placement; hard cap 4/session, 120s minimum gap.
- Native `discovery_native`: a clearly labeled native ad after the third organic discovery card; hard cap 3/session, 90s minimum gap.
- Interstitial `tab_transition`: natural eligible tab transitions only; hard cap 3/session, 180s minimum gap and at least two eligible transitions between impressions.
- Rewarded `rewarded_cosmetic`: explicit user choice in Rewards; non-cash cosmetic reward only; hard cap 5/session.
- App Open `app_open`: only when returning from background on an eligible non-sensitive screen; hard cap 1/session and 4-hour minimum gap.
- Rewarded Interstitial `rewarded_interstitial_cosmetic`: separate, explicit opt-in control in Rewards; non-cash cosmetic reward only; hard cap 2/session and 5-minute minimum gap.

The six SDK unit IDs are supplied through `--dart-define`; development defaults use Google's official test unit IDs. `scripts/build-all.sh` now passes all six release unit IDs, and `scripts/verify-release-admob.sh` blocks release if any are missing or test IDs. The Android application ID placeholder also defaults to Google's official test App ID; set `ADMOB_APP_ID` in the build environment for production. Consent is resolved through UMP before SDK requests. No ad placement is permitted in private chat threads, authentication, support, verification, appeals, or safety flows.

These integrations are code changes, not evidence of live ad serving. Keep placements disabled until UMP, test-device validation, the app's AdMob review, and Play release checks are complete.
