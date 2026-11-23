# Feature checklist
Legend — **TESTED**: executed test passes (unit / DB / integration against real PostgreSQL). **WRITTEN**: code present, not executed (Flutter, external providers). **TODO**: not implemented.

| ID | Feature | Status | Key files | Endpoints | Tables | Limitations |
|---|---|---|---|---|---|---|
| A1 | Register email+password, 18+ gate, terms, strength rules, device bind, verification email | TESTED | api/auth/register, lib/emailTokens | POST /api/auth/register | users,devices,preferences,email_tokens | email delivery needs provider keys |
| A2 | Login (generic errors, per-account rate limit), refresh rotation + reuse detection, logout | TESTED | api/auth/* | login, refresh, logout | sessions,security_events | |
| A3 | Password recovery, email verify/resend | TESTED | api/auth/password/*, api/auth/email/* | forgot, reset, verify, resend | email_tokens | |
| A4 | Google Sign-In (server verifies ID token) | WRITTEN (needs GOOGLE_CLIENT_ID + network) | api/auth/google | POST /api/auth/google | users.google_sub | Flutter button not wired; link-to-existing-email flow TODO |
| A5 | Staff/Owner mandatory TOTP 2FA | TESTED | lib/totp, api/auth/login | login | users.totp_secret_enc | enrollment UI TODO (bootstrap prints secret) |
| A6 | One account per device; transfer after revoke | TESTED (DB+route) | migrations, register | | devices | Owner-approved transfer routes TODO; Play Integrity attestation TODO |
| A7 | Account deletion in-app + public web | TESTED | api/me DELETE, api/public/delete-account, /delete-account | | users | retention cron TESTED |
| B1 | Discovery: radius 1/5/10/25/50/100/all (default 25), approximate distance, age/verified filters, blocks symmetric, no coordinates leaked | TESTED | api/discover, domain/matching | GET /api/discover | users,preferences,blocks | online/recent/shared-interest filters as params TODO; SQL geo pre-filter for scale TODO |
| B2 | Coarse location on demand only | TESTED | api/me/location | POST | users.lat_cell | |
| B3 | Like, super like, pass, favorite; mutual match; incoming likes; restrictions | TESTED | api/swipes, api/likes/incoming | | swipes,matches,conversations | match push needs FCM |
| B4 | Compatibility % + reason codes | TESTED | domain/matching | discover | | Owner weights: PUT /api/admin/matching-weights (TESTED) |
| C1 | Intro requests: 3-message limit across all types, no bypass (1 conversation per pair), accept/reject, Owner rule (anyone/verified_only/matched_only) | TESTED (route + DB trigger) | api/conversations/** | POST /api/conversations, /respond | conversations,messages | |
| C2 | Messages: send/list, delivery+read, read-receipt privacy, temp messages (24h/7d/30d after read), delete for me/both (Owner window), react, pin, reply | TESTED | api/conversations/[id]/messages/** | | messages,message_deletions,message_reactions | realtime transport = polling in app; Ably/Pusher adapter not implemented; typing status & last-seen endpoints TODO; GIF/sticker catalog TODO |
| C3 | Attachments: type/size/magic-byte policy, clean-scan gate before delivery | TESTED (policy + gate) | api/uploads, domain/messaging | POST /api/uploads | attachments | storage + malware scan providers not configured → 501; upload-complete/scan callback route TODO; location sharing UI TODO |
| C4 | Screenshot protection FLAG_SECURE | WRITTEN (patch script) | scripts/patch_android.py | | | Android cannot reliably detect screenshots; never absolute |
| D1 | Reports, blocks, child-safety event | TESTED | api/reports, api/blocks | | reports,blocks,security_events | |
| D2 | Punishments (permission per kind, staff protected), appeals (credential re-auth), Owner final decision, restrictions enforced | TESTED | api/admin/punishments, api/appeals, api/admin/appeals | | punishments,appeals | warning-points auto-escalation TODO; admin UI for these TODO |
| D3 | Ratings (genuine interaction) + trust score | TESTED | api/ratings, domain/policy | POST /api/ratings | ratings | |
| D4 | Verification request + evidence to storage; AI findings never auto-punish | partial (policy TESTED; route returns 501 w/o storage) | api/verification, domain/policy.routeAiFinding | | verifications,ai_findings | review/approve routes, liveness, AI vendor TODO |
| E1 | RBAC with owner-only set (code + DB CHECK), audited staff access | TESTED | domain/permissions, lib/http | | staff_permissions,audit_log | staff-management routes (create admin/support accounts) TODO |
| E2 | Emergency modes + lockdown revoking sessions | TESTED | api/admin/emergency | | emergency_state | |
| E3 | Admin stats (real data, null when unavailable) | TESTED | api/admin/stats | | | AdMob/retention null by design |
| E4 | Support: tickets create/list/reply, internal notes, identity control | TESTED | api/tickets, api/admin/tickets | | tickets,ticket_messages | escalate/close + recommendations TESTED |
| E5 | App Builder: data-only config draft/publish/rollback (rejects executable content) | TESTED | api/admin/config | | config_versions,app_config | visual editor WRITTEN (admin/pages/builder_page.dart); new executable code can NOT be shipped remotely (by design) |
| E6 | Releases / min version / forced update | TESTED | api/admin/releases, /api/config | | app_releases | rollout enforcement per user TODO |
| E7 | Occasions cron: targeting, no duplicates, honest push | TESTED | api/cron/occasions, vercel.json | | occasions,occasion_sends | occasion CRUD TESTED; push needs FCM |
| E8 | Backups | TESTED (scripts + routes) | docs/BACKUP_RESTORE.md | | backups | scripts/backup.sh + restore.sh TESTED; Owner routes TESTED (see Batch 2) |
| E9 | Marketing center (Meta/TikTok/X) | routes TESTED; real platform APIs NOT verified | providers | | social_* | needs Meta/TikTok/X developer approvals; OAuth callback + publish untested against live platforms |
| F1 | 30 themes, light/dark, RTL, scheduling resolver | WRITTEN (tests written, not run) | near_me_core/themes.dart | /api/config | | per-theme fonts/backgrounds beyond palette+shape TODO |
| F2 | 3D icon set (17 SVG) + NmIcon | WRITTEN (SVGs rendered & checked) | assets/icons, scripts/gen_icons.py | | | |
| F3 | Ad policy + AdMob wiring (UMP consent, banner, interstitial on transitions, never in chat) | policy TESTED; SDK code WRITTEN | domain/policy, mobile/.../ads.dart | /api/config | ad_config | test IDs by default; native/app-open/rewarded formats TODO |
| F4 | PIN lock + decoy PIN + lockout + Owner-allowed timeouts | WRITTEN | mobile/.../pin_lock.dart | /api/config | | |
| F5 | Chat UI (list, thread, intro banner, report/block, actions) | WRITTEN | mobile/.../chat_screen.dart | | | media/sticker/GIF picker, typing, presence, rate, gift WRITTEN |
| G1 | Providers (email, push, storage, realtime, AI, malware, social) | adapters return not_configured | src/providers | | | each needs vendor code + credentials |
| H1 | Legal pages + Play checklist | WRITTEN templates | app/*/page.tsx, docs/PLAY_COMPLIANCE.md | | | Owner must fill contacts/legal name |

## Batch 2 — added in the final build (all backend rows TESTED against real PostgreSQL; Flutter rows WRITTEN, never compiled here)

| ID | Feature | Status | Endpoints / files | Limitations |
|---|---|---|---|---|
| I1 | Profile edit, interests, hide profile, preferences (validated; Owner-defined PIN timeouts), sessions list/revoke, security events, FCM token | TESTED | /api/me, /api/me/{preferences,interests,hide,sessions,security}, /api/devices/fcm, /api/interests | push delivery needs FCM credentials |
| I2 | Login bound to registered device (`device_not_registered`) | TESTED | /api/auth/login (`install_id`) | Owner-approved device transfer routes NOT implemented; Play Integrity attestation NOT implemented |
| I3 | Presence heartbeat + typing, privacy respected | TESTED | /api/presence, /api/conversations/[id]/typing | polling, not realtime push |
| I4 | Rewind (5 min, not after match), Boost (30 min / 24 h), boosted-first discovery, Owner matching weights | TESTED | /api/swipes/rewind, /api/boost, /api/admin/matching-weights | |
| I5 | Stickers, free gifts, inventory/equip with ownership checks, behavioral badges, daily challenges (server-computed), optional rewarded ad (capped) | TESTED | /api/{stickers,gifts,inventory,challenges,rewards/ad} | rewarded-ad claim is client-reported (AdMob server-side verification TODO), capped per day, cosmetics only |
| I6 | Notifications (+ occasion notifications) | TESTED | /api/notifications, cron/occasions | |
| I7 | Occasions CRUD + sent-count reporting | TESTED | /api/admin/occasions | |
| I8 | Staff management (Owner): create with one-time password+TOTP secret, extra permissions (owner-only never grantable), disable, revoke sessions | TESTED | /api/admin/staff | |
| I9 | Owner 2FA rotation + one-time recovery codes + recovery login | TESTED | /api/admin/owner/credentials | |
| I10 | User inspection (audited, no secrets) | TESTED | /api/admin/users/[id] | |
| I11 | Verification review (support review, admin approve, audited evidence links, AI advisory), AI findings, recommendations, warning-points review threshold (never auto-punishes), ticket escalate/close, report + appeal queues | TESTED | /api/admin/{verifications,ai-findings,recommendations,reports,appeals,tickets} | evidence + AI need storage/AI providers (501 until configured) |
| I12 | Backups: Owner request, restore authorization (typed confirm + fresh TOTP), real scripts with checksum verification | TESTED | /api/admin/backups, scripts/backup.sh, scripts/restore.sh | scheduled automatic backups NOT provided (use Neon backups/branching) |
| I13 | Retention cron (expired messages, verification evidence, old sessions) | TESTED | /api/cron/retention | |
| I14 | Release compatibility check | TESTED | /api/admin/releases/compat | |
| I15 | Chat media: upload complete + malware-scan gate (fail closed), participant-only signed download, GIF provider adapter, GIF URL allowlist | TESTED (gate, access, validation) | /api/uploads/complete, /api/attachments/[id], /api/gifs | real storage, scanner, GIPHY key needed |
| I16 | Marketing Center: OAuth start with signed state, accounts (tokens encrypted, never returned), posts with approval workflow, publish cron (marks blocked_no_api_access, never fake "published"), campaigns, Owner-only paid authorization (+DB guarantee), seasonal drafts from occasions, AI studio (501 w/o provider) | TESTED (everything except live platform calls) | /api/admin/marketing/*, /api/cron/social-publish | OAuth token exchange + publishing NOT verified against Meta/TikTok/X |
| I17 | AdMob placements managed by Owner (fixed set, off by default) | TESTED | /api/admin/ads | |
| I18 | Flutter: customer screens (media, profile edit, rewards/inventory, notifications, verification, appeal, support, incoming likes, security center) | WRITTEN | mobile/apps/customer/lib/screens | never compiled |
| I19 | Flutter: admin screens (staff, moderation hub, marketing, occasions, ads, weights, releases, backups, owner security, visual App Builder) | WRITTEN | mobile/apps/admin/lib/pages | never compiled |
| I20 | Customer app consumes published `builder.app` config (theme, tab labels, feature toggles) | WRITTEN (parsing logic has Dart unit tests, not run) | near_me_core/src/builder.dart | |
