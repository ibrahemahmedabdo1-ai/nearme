# Google Play compliance checklist (reviewed against Google's current pages on 2026-11-27; re-check before submitting)
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


## Additional launch checks confirmed during the 2026-11-27 audit

- [x] Customer signup requires a birthdate and server-side age calculation rejects users under 18.
- [ ] Play Console age-restricted content/functionality controls must be configured to block minors for the dating/matchmaking core functionality. The in-app birthdate gate does not replace this Console requirement.
- [x] UMP consent update is requested at Customer app startup; ad requests fail closed when consent cannot be resolved; a privacy-options entry point is shown when UMP reports it is required.
- [x] Customer registration links to the Terms, Privacy Policy, and Community Guidelines routes.
- [x] Android bootstrap now injects the AdMob application ID through a Gradle manifest placeholder; production build guard rejects test IDs and placeholder values.
- [ ] The Privacy Policy, Terms, and Child Safety pages still contain Owner/legal-review placeholders. Replace them with the operator's verified legal name, monitored privacy/child-safety contacts, accurate provider/retention disclosures, and legally reviewed final text before release.
- [ ] The child-safety contact must be monitored daily and the escalation/reporting process must be staffed and tested. Do not publish the template as a completed safety program.
- [ ] Verify UMP messages and privacy options in AdMob Privacy & messaging for applicable regions (including EEA/UK/Switzerland), using test devices and the real production AdMob app ID.
- [ ] The mobile GitHub workflow currently creates DEBUG APKs only. The signed-release workflow remains disabled until the Owner configures signing secrets; use `scripts/build-all.sh` only after the production IDs and upload keystores are configured.

Official references:
- Age-restricted functionality: https://support.google.com/googleplay/android-developer/answer/16302250
- UMP Flutter setup: https://developers.google.com/admob/flutter/privacy
- AdMob invalid traffic: https://support.google.com/admob/answer/3342054
