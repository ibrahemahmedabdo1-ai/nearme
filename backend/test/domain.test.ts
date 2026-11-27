import test from "node:test";
import assert from "node:assert/strict";
import { hashPassword, verifyPassword, validatePasswordStrength } from "../src/domain/password.ts";
import { signAccessToken, verifyAccessToken, newRefreshToken, hashRefresh } from "../src/domain/tokens.ts";
import { evaluateIntro } from "../src/domain/introLimit.ts";
import { compatibility, approxDistance, haversineKm, withinRadius, DEFAULT_RADIUS_KM } from "../src/domain/matching.ts";
import { expiresAt, canDeleteForBoth, checkUpload } from "../src/domain/messaging.ts";
import { can } from "../src/domain/permissions.ts";
import { isAdult, adAllowed, modeAllows, routeAiFinding, trustScore } from "../src/domain/policy.ts";
import { RateLimiter } from "../src/lib/rateLimit.ts";
import { encrypt, decrypt } from "../src/lib/crypto.ts";
import { newTotpSecret, totp, verifyTotp } from "../src/lib/totp.ts";
import { randomBytes } from "node:crypto";
const S = "x".repeat(40);

test("password hash/verify + strength", async () => {
  const h = await hashPassword("Str0ngPassw0rd");
  assert.ok(await verifyPassword("Str0ngPassw0rd", h)); assert.ok(!(await verifyPassword("wrong", h)));
  assert.equal(validatePasswordStrength("short"), "password_too_short"); assert.equal(validatePasswordStrength("alllowercase12"), "password_too_weak");
  assert.equal(validatePasswordStrength("Str0ngPassw0rd"), null);
});
test("access token: valid, tampered, expired, alg none", () => {
  const t = signAccessToken({ sub: "u1", role: "customer", sid: "s1" }, S, 60, 1000);
  assert.equal(verifyAccessToken(t, S, 2000)?.sub, "u1");
  assert.equal(verifyAccessToken(t, S, 1000 + 61_000), null);
  assert.equal(verifyAccessToken(t.slice(0, -2) + "xx", S, 2000), null);
  assert.equal(verifyAccessToken(t, "y".repeat(40), 2000), null);
  const none = Buffer.from('{"alg":"none"}').toString("base64url") + "." + t.split(".")[1] + ".";
  assert.equal(verifyAccessToken(none, S, 2000), null);
  assert.throws(() => signAccessToken({ sub: "u", role: "owner", sid: "s" }, "short"));
});
test("refresh token stored hashed", () => { const r = newRefreshToken(); assert.equal(hashRefresh(r.raw), r.hash); assert.notEqual(r.raw, r.hash); });
test("intro limit: 3 messages, any type, across requests; reply resets", () => {
  const m = (s: string, r: string, kind = "text") => ({ senderId: s, recipientId: r, kind });
  assert.equal(evaluateIntro([], "a", "b").remaining, 3);
  const three = [m("a","b"), m("a","b","image"), m("a","b","sticker")];
  assert.equal(evaluateIntro(three, "a", "b").reason, "limit_reached");
  assert.equal(evaluateIntro([...three, m("b","a")], "a", "b").allowed, true);
  assert.equal(evaluateIntro(three, "a", "b", { blocked: true }).reason, "blocked");
  assert.equal(evaluateIntro(three.map(x => ({ ...x, deleted: true })), "a", "b").allowed, false); // deleting does not bypass
});
test("matching: radius, approx distance, score, weights", () => {
  assert.equal(DEFAULT_RADIUS_KM, 25);
  assert.ok(withinRadius(10, 25) && !withinRadius(30, 25) && withinRadius(999, null) && !withinRadius(null, 25));
  assert.ok(Math.abs(haversineKm([30.0444, 31.2357], [31.2001, 29.9187]) - 179) < 5);
  assert.equal(approxDistance(0.1), 0.5); assert.equal(approxDistance(0.8), 1); assert.equal(approxDistance(12.2), 13);
  const now = Date.now();
  const hi = compatibility({ interests: ["a","b"], radiusKm: 25, minAge: 20, maxAge: 35 }, { interests: ["a","b"], distanceKm: 1, age: 27, lastActiveMs: now, verified: true }, undefined, now);
  const lo = compatibility({ interests: ["a","b"], radiusKm: 25, minAge: 20, maxAge: 35 }, { interests: ["z"], distanceKm: 24, age: 50, lastActiveMs: now - 9e8, verified: false }, undefined, now);
  assert.ok(hi.score > 90 && lo.score < 20 && hi.reasons.includes("verified_profile"));
  assert.throws(() => compatibility({ interests: [], radiusKm: null, minAge: 18, maxAge: 99 }, { interests: [], distanceKm: 1, age: 20, lastActiveMs: now, verified: false }, { interests: 0, distance: 0, age: 0, activity: 0, verified: 0 }));
});
test("temporary messages & delete-for-both", () => {
  assert.equal(expiresAt("off", 1000), null); assert.equal(expiresAt("24h", null), null); assert.equal(expiresAt("24h", 1000), 1000 + 86_400_000);
  const sent = 1_000_000;
  assert.ok(canDeleteForBoth(sent, "a", "a", 10, sent + 9 * 60_000));
  assert.ok(!canDeleteForBoth(sent, "a", "a", 10, sent + 11 * 60_000));
  assert.ok(!canDeleteForBoth(sent, "a", "b", 10, sent + 1000));
  assert.ok(!canDeleteForBoth(sent, "a", "a", 0, sent + 1000));
});
test("uploads: block executables, double ext, spoofed content, size", () => {
  const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0, 0]);
  assert.equal(checkUpload("a.png", "image/png", 100, 1e6, png).ok, true);
  assert.equal((checkUpload("a.exe", "application/octet-stream", 1, 1e6, png) as any).reason, "blocked_type");
  assert.equal((checkUpload("a.exe.png", "image/png", 1, 1e6, png) as any).reason, "double_extension");
  assert.equal((checkUpload("a.pdf", "application/pdf", 1, 1e6, png) as any).reason, "content_mismatch");
  assert.equal((checkUpload("a.png", "image/png", 2e6, 1e6, png) as any).reason, "size_limit");
  assert.equal((checkUpload("a.svg", "image/svg+xml", 1, 1e6, png) as any).reason, "blocked_type");
});
test("permissions: staff can never hold owner-only", () => {
  assert.ok(can("owner", [], "ownership.transfer"));
  for (const p of ["ownership.transfer","owner.credentials","identity.view_secrets","emergency.control","accounts.manage_staff"] as const) {
    assert.ok(!can("admin", [p], p)); assert.ok(!can("support", [p], p));
  }
  assert.ok(can("support", [], "tickets.reply")); assert.ok(!can("support", [], "punish.ban")); assert.ok(!can("customer", ["tickets.read"], "tickets.read"));
});
test("age gate 18+", () => { const n = new Date("2026-06-15"); assert.ok(isAdult(new Date("2008-06-15"), n)); assert.ok(!isAdult(new Date("2008-06-16"), n)); });
test("ad policy", () => {
  const c = { lastInterstitialMs: null, minGapSec: 120, isTransition: true, now: 1e6 };
  assert.ok(!adAllowed({ screen: "chat_thread", format: "banner" }, c));
  assert.ok(!adAllowed({ screen: "report_flow", format: "native" }, c));
  for (const screen of ["login", "registration", "onboarding", "support", "support_chat", "support_ticket", "appeals", "child_safety", "moderation"]) {
    assert.ok(!adAllowed({ screen, format: "banner" }, c), `ads must be blocked in ${screen}`);
  }
  assert.ok(adAllowed({ screen: "home", format: "native" }, c));
  assert.ok(!adAllowed({ screen: "home", format: "interstitial" }, { ...c, isTransition: false }));
  assert.ok(!adAllowed({ screen: "home", format: "interstitial" }, { ...c, lastInterstitialMs: 1e6 - 5000 }));
});
test("emergency modes keep owner access", () => {
  for (const m of ["maintenance","read_only","registration_lock","chat_protection","security_lockdown","full_shutdown"] as const) assert.ok(modeAllows(m, "owner_access"));
  assert.ok(!modeAllows("read_only", "write")); assert.ok(!modeAllows("registration_lock", "register")); assert.ok(!modeAllows("chat_protection", "send_message")); assert.ok(!modeAllows("full_shutdown", "read"));
});
test("AI never auto-punishes; trust score bounded", () => {
  assert.equal(routeAiFinding({ kind: "fake", confidence: 0.99, reasonCodes: ["x"], evidenceRefs: [] }).autoPunish, false);
  assert.equal(routeAiFinding({ kind: "fake", confidence: 0.1, reasonCodes: ["x"], evidenceRefs: [] }).action, "ignore");
  assert.equal(trustScore({ verified: true, ratingAvg: 5, ratingCount: 10, reportsUpheld: 0, accountAgeDays: 900 }) <= 100, true);
  assert.equal(trustScore({ verified: false, ratingAvg: 1, ratingCount: 10, reportsUpheld: 20, accountAgeDays: 0 }), 0);
});
test("rate limiter", () => { const r = new RateLimiter(2, 1000); assert.ok(r.check("k", 0).ok && r.check("k", 1).ok); assert.ok(!r.check("k", 2).ok); assert.ok(r.check("k", 1001).ok); });
test("AES-GCM roundtrip + tamper", () => {
  const k = randomBytes(32).toString("base64"); const e = encrypt("secret", k); assert.equal(decrypt(e, k), "secret");
  const bad = e.slice(0, -2) + (e.endsWith("A") ? "B" : "A"); assert.throws(() => decrypt(bad, k));
});
test("TOTP RFC6238 vector", () => {
  // RFC 6238 SHA1 secret "12345678901234567890" -> base32 GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ, T=59 => 287082 (8 digits 94287082)
  assert.equal(totp("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", 59_000, 30, 8), "94287082");
  const s = newTotpSecret(); assert.ok(verifyTotp(s, totp(s, 1e12), 1e12)); assert.ok(!verifyTotp(s, "000000", 1e12) || totp(s, 1e12) === "000000");
});
