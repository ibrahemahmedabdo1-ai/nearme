# Continuation report — remaining work, in order
1. `cd backend && npm install && npm run typecheck && npm run build` — fix anything real Next.js/TypeScript reports (routes were only executed through the test shim). Commit `package-lock.json`.
2. `scripts/bootstrap-flutter.sh`, then `flutter analyze` + `flutter test` in each package/app; fix compile errors (Dart never compiled). Run `scripts/dartcheck.py` for a quick balance check.
3. Neon + Vercel per docs/DEPLOYMENT.md; verify /api/health. Create Owner with scripts/bootstrap-owner.ts.
4. Providers: FCM, object storage (R2/S3) + `/api/uploads/complete` scan callback, realtime (Ably/Pusher), email (Resend/Postmark), malware scan, AI moderation.
5. Known gaps (see FEATURES.md): Owner-approved device transfer, Play Integrity attestation, Google Sign-In button in Flutter, AdMob server-side reward verification, realtime transport (chat polls every 4 s), provider integrations.
6. Marketing Center: obtain Meta/TikTok/X developer approvals, then verify the OAuth callback and publishing against the real APIs (written from the documented flows, never run against them).
7. Device testing on Android 16 / 16 KB page size (`scripts/verify-16kb.sh`), accessibility, RTL review, penetration test, `npm audit`.
8. Play Console: docs/PLAY_COMPLIANCE.md items, then internal → closed → production tracks.
