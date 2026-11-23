# Google Play compliance checklist (verified against Google's pages on 2026-11-22; re-check before submitting)
Sources: support.google.com/googleplay/android-developer/answer/11926878 (target API), /answer/17190352 & /answer/16549787 (Child Safety Standards, social & dating), /answer/9876937 (UGC), /answer/16926792 (policy update: age-gating for dating).

Technical
- [x] Target Android 16 / API 36 — new apps and updates must target API 36+ since 2026-08-31 (patch script sets it; **verify in built AAB**).
- [ ] 16 KB page-size: run `scripts/verify-16kb.sh` on the built APK; upgrade any native plugin that fails.
- [ ] Android App Bundle + Play App Signing (docs/ANDROID_SIGNING.md).
- [ ] Permissions: only INTERNET, ACCESS_COARSE_LOCATION (on demand), POST_NOTIFICATIONS, AD_ID. Explain each in Data safety.
- [ ] Check Android developer verification requirements for your account type in Play Console (new program; rules evolving).
Policies
- [ ] Privacy Policy URL (`/privacy`) filled with legal name/contact. [ ] Terms (`/terms`). [ ] Community Guidelines page (add from legal/COMMUNITY_GUIDELINES.md).
- [ ] Account deletion: in-app (Profile → Delete account) **and** web URL `/delete-account` entered in Data safety.
- [ ] Child Safety Standards: published CSAE prohibition (`/child-safety`), in-app reporting (done), designated contact, self-certify in Play Console for Social/Dating.
- [ ] UGC: terms acceptance at signup (done), report + block (done), moderation by humans (Admin/Support), objectionable content defined in Community Guidelines.
- [ ] Dating: use Play Console "Restrict minor access" / age-based blocking since dating is the primary function; keep in-app 18+ gate (done). No sugar-dating/compensated arrangements — enforce in rules.
- [ ] Ads: declare "contains ads"; AdMob app IDs; UMP consent flow for EEA/UK; no ads in chat/safety (enforced in policy code); no accidental-click design.
- [ ] Data safety form: location (approx), personal info, photos, messages, device IDs (install id hash, AD_ID), security events. Must match actual behavior.
- [ ] Content rating questionnaire (user interaction, location sharing, dating). [ ] App access instructions: provide a test account for reviewers (create a non-owner demo account; never give Owner credentials).
- [ ] Store listing: screenshots (use real app screens once built), feature graphic, short/full description in AR+EN. No unverifiable claims.
Testing
- [ ] Internal testing track → closed testing (new personal developer accounts must meet Play's testing requirements) → production.
Disclaimer: approval is decided by Google; this list reduces risk, it does not guarantee approval.
