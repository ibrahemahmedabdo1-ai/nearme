# NEAR ME — read this first (honest status)

Built in a sandbox **without Flutter, the Android SDK, Next.js packages, or access to Vercel/Neon/Google**. What that means:

| Area | Status |
|---|---|
| Backend domain logic (auth tokens, passwords, intro limit, matching, permissions, uploads, TOTP, crypto, ad & emergency policy) | **15 unit tests executed — all pass** (`npm test`) |
| PostgreSQL schema + 5 migrations | **Executed on real PostgreSQL 16 — DB test suite passes** (`npm run test:db`) |
| **API route handlers (92 routes)** | **43 integration tests executed against real PostgreSQL — all pass** (`npm run test:integration`). The REAL route code runs; only two things are swapped in tests: `next/server` (minimal Request/Response shim) and the Neon driver (local `psql` with PREPARE/EXECUTE so parameter-type inference matches the real protocol). **Not yet run under actual Next.js / Neon** — do `npm install && npm run typecheck && npm run build` first. |
| Flutter apps (customer / admin / support), shared packages, 30 themes, 3D icons, chat, PIN lock + decoy, AdMob wiring | **Written, NOT compiled, NOT run.** Only a bracket/string balance check was done (`scripts/dartcheck.py`). Expect some compile errors on first `flutter analyze`. |
| APK / AAB / signing / mapping files | **Not produced** (no Flutter/SDK here). `scripts/build-all.sh` builds them on your machine. |
| Vercel deploy, Neon connection, FCM, AdMob IDs, Google Sign-In client ID, object storage, realtime, email, AI, malware scan, social APIs | **Not connected.** Adapters return `not_configured` / HTTP 501; nothing is faked as sent. |
| Google Play approval | **Cannot be guaranteed.** See PLAY_COMPLIANCE.md |

Backup/restore scripts were executed against real PostgreSQL (dump, checksum, restore, tamper refusal).

Bugs the integration tests found and I fixed: per-account login rate limit was IP-scoped (bypassable); account deletion violated a DB CHECK; an audit INSERT used one parameter as two types.

Run everything locally (needs Node 22 + PostgreSQL + psql): `cd backend && TEST_PG_URL=postgresql:///postgres npm run test:all`

See FEATURES.md (per-feature status) and CONTINUATION.md (what remains).
