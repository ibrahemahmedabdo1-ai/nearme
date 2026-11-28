// Feature batch 1: profile, preferences, presence, boost/rewind, items, challenges, notifications, device binding.
import { test } from "node:test";
import assert from "node:assert/strict";
import { call, newUser, staff, sql, pw } from "./harness/helpers.ts";

const match = async (a: any, b: any) => { await call("swipes", "POST", { token: a.token, body: { to_user: b.id, kind: "like" } }); await call("swipes", "POST", { token: b.token, body: { to_user: a.id, kind: "like" } }); return sql(`SELECT id FROM conversations WHERE '${a.id}' IN (user_a,user_b) AND '${b.id}' IN (user_a,user_b)`); };

test("login is bound to the registered device (one account per device)", async () => {
  const u = await newUser("dev");
  const noId = await call("auth/login", "POST", { body: { email: u.email, password: pw } }); assert.equal(noId.status, 422);
  const other = await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: "f".repeat(32) } }); assert.equal(other.status, 403); assert.equal(other.body.error, "device_not_registered");
  assert.equal((await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: u.install } })).status, 200);
  assert.equal(sql(`SELECT count(*) FROM security_events WHERE user_id='${u.id}' AND kind='login_unregistered_device'`), "1");
});

test("customer login re-checks adult eligibility for legacy pre-existing accounts", async () => {
  const u = await newUser("ageLogin");
  // Simulate a legacy row that predates the database age constraint. Restore the schema/data in finally.
  sql(`ALTER TABLE users ALTER COLUMN birthdate DROP NOT NULL; ALTER TABLE users DROP CONSTRAINT users_birthdate_check; UPDATE users SET birthdate='2012-01-01' WHERE id='${u.id}'`);
  try {
    const denied = await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: u.install } });
    assert.equal(denied.status, 403);
    assert.equal(denied.body.error, "age_restricted");
  } finally {
    sql(`UPDATE users SET birthdate='1995-01-01' WHERE id='${u.id}'; ALTER TABLE users ADD CONSTRAINT users_birthdate_check CHECK (birthdate <= (CURRENT_DATE - INTERVAL '18 years')); ALTER TABLE users ALTER COLUMN birthdate SET NOT NULL`);
  }
});

test("profile edit, interests, hide, no secrets in /me", async () => {
  const u = await newUser("prof");
  assert.equal((await call("me", "PATCH", { token: u.token, body: { display_name: "Nova", bio: "hello world" } })).status, 200);
  assert.equal((await call("me", "PATCH", { token: u.token, body: { display_name: "x" } })).status, 422);
  assert.equal((await call("me/interests", "PUT", { token: u.token, body: { slugs: ["travel", "music"] } })).status, 200);
  assert.equal((await call("me/interests", "PUT", { token: u.token, body: { slugs: ["nope"] } })).status, 422);
  const me = await call("me", "GET", { token: u.token });
  assert.equal(me.body.user.display_name, "Nova"); assert.deepEqual(me.body.interests.sort(), ["music", "travel"]);
  assert.ok(!JSON.stringify(me.body).match(/password|pin_hash|totp|refresh/i));
  assert.equal((await call("interests", "GET", { token: u.token })).body.interests.length >= 3, true);
  const viewer = await newUser("view");
  assert.equal((await call("me/hide", "POST", { token: u.token, body: { hours: 2 } })).status, 200);
  assert.ok(!(await call("discover", "GET", { token: viewer.token, query: "?radius=all" })).body.results.some((x: any) => x.id === u.id));
  assert.equal((await call("me/hide", "POST", { token: u.token, body: { hours: 0 } })).status, 422);
  assert.equal((await call("me/hide", "POST", { token: u.token, body: { hours: null } })).status, 200);
});

test("preferences validate values and Owner-defined PIN timeouts", async () => {
  const u = await newUser("pref");
  assert.equal((await call("me/preferences", "PUT", { token: u.token, body: { radius_km: 10, temp_messages: "7d", language: "en", min_age: 20, max_age: 40, show_online: false } })).status, 200);
  const g = (await call("me/preferences", "GET", { token: u.token })).body.preferences; assert.equal(g.radius_km, 10); assert.equal(g.show_online, false); assert.equal(g.language, "en");
  assert.equal((await call("me/preferences", "PUT", { token: u.token, body: { radius_km: 7 } })).status, 422);
  assert.equal((await call("me/preferences", "PUT", { token: u.token, body: { min_age: 17 } })).status, 422);
  assert.equal((await call("me/preferences", "PUT", { token: u.token, body: { min_age: 50, max_age: 30 } })).status, 422);
  assert.equal((await call("me/preferences", "PUT", { token: u.token, body: { pin_timeout_sec: 77 } })).status, 422);
  assert.equal((await call("me/preferences", "PUT", { token: u.token, body: { pin_timeout_sec: 300 } })).status, 200);
  assert.equal((await call("me/preferences", "PUT", { token: u.token, body: { radius_km: null } })).status, 200);   // "all"
});

test("presence and typing respect privacy and conversation membership", async () => {
  const a = await newUser("pA"), b = await newUser("pB"), c = await newUser("pC"); const id = await match(a, b);
  await call("presence", "POST", { token: b.token });
  let l = (await call("conversations/[id]/messages", "GET", { token: a.token, params: { id } })).body.peer; assert.equal(l.online, true); assert.equal(l.typing, false);
  assert.equal((await call("conversations/[id]/typing", "POST", { token: b.token, params: { id } })).status, 200);
  assert.equal((await call("conversations/[id]/messages", "GET", { token: a.token, params: { id } })).body.peer.typing, true);
  assert.equal((await call("conversations/[id]/typing", "POST", { token: c.token, params: { id } })).status, 404);
  await call("me/preferences", "PUT", { token: b.token, body: { show_online: false, show_last_seen: false } });
  l = (await call("conversations/[id]/messages", "GET", { token: a.token, params: { id } })).body.peer; assert.equal(l.online, false); assert.equal(l.last_seen_at, null);
});

test("rewind (5 minutes, not after a match) and boost (once per 24h, sorted first)", async () => {
  const a = await newUser("rwA"), b = await newUser("rwB"), c = await newUser("rwC"), d = await newUser("rwD");
  await call("swipes", "POST", { token: a.token, body: { to_user: b.id, kind: "pass" } });
  assert.equal((await call("swipes/rewind", "POST", { token: a.token })).body.restored_user, b.id);
  assert.equal((await call("swipes/rewind", "POST", { token: a.token })).status, 404);
  await call("swipes", "POST", { token: a.token, body: { to_user: c.id, kind: "pass" } });
  sql(`UPDATE swipes SET created_at=now()-interval '10 minutes' WHERE from_user='${a.id}'`);
  assert.equal((await call("swipes/rewind", "POST", { token: a.token })).status, 409);
  await call("swipes", "POST", { token: b.token, body: { to_user: c.id, kind: "like" } }); await call("swipes", "POST", { token: c.token, body: { to_user: b.id, kind: "like" } });
  assert.equal((await call("swipes/rewind", "POST", { token: b.token })).status, 409);   // matched
  assert.equal((await call("boost", "POST", { token: d.token })).status, 201);
  assert.equal((await call("boost", "POST", { token: d.token })).status, 429);
  const res = (await call("discover", "GET", { token: a.token, query: "?radius=all" })).body.results;
  assert.ok(!res.some((p: any) => p.id === c.id), "a passed profile must not reappear after the rewind window");
  assert.equal(res[0].id, d.id);
});

test("owner-controlled matching weights are validated and audited", async () => {
  const adm = await staff("admin", "wadm"); const u = await newUser("wcust");
  assert.equal((await call("admin/matching-weights", "PUT", { token: u.token, body: {} })).status, 403);
  assert.equal((await call("admin/matching-weights", "PUT", { token: adm.token, body: { interests: 50, distance: 20, age: 10, activity: 10, verified: 10 } })).status, 200);
  assert.equal((await call("admin/matching-weights", "PUT", { token: adm.token, body: { interests: -1, distance: 20, age: 10, activity: 10, verified: 10 } })).status, 422);
  assert.equal((await call("admin/matching-weights", "GET", { token: adm.token })).body.weights.interests, 50);
  assert.equal(sql(`SELECT count(*) FROM audit_log WHERE action='matching.weights'`), "1");
});

test("stickers, gifts, inventory, equip: ownership enforced", async () => {
  const a = await newUser("gA"), b = await newUser("gB"), c = await newUser("gC");
  assert.ok((await call("stickers", "GET", { token: a.token })).body.stickers.length >= 5);
  assert.equal((await call("gifts", "POST", { token: a.token, body: { to_user: b.id, item_id: "gift_rose" } })).status, 403);   // no conversation yet
  await match(a, b);
  assert.equal((await call("gifts", "POST", { token: a.token, body: { to_user: b.id, item_id: "gift_rose" } })).status, 201);
  assert.equal((await call("gifts", "POST", { token: a.token, body: { to_user: b.id, item_id: "frame_neon" } })).status, 422);   // not a gift
  assert.equal((await call("notifications", "GET", { token: b.token })).body.unread, 1);
  assert.equal((await call("inventory", "GET", { token: b.token })).body.gifts_received.length, 1);
  assert.equal((await call("inventory/equip", "POST", { token: a.token, body: { slot: "frame", item_id: "frame_neon" } })).status, 403);   // not owned
  sql(`INSERT INTO user_items(user_id,item_id,source) VALUES ('${a.id}','frame_neon','test')`);
  assert.equal((await call("inventory/equip", "POST", { token: a.token, body: { slot: "frame", item_id: "frame_neon" } })).status, 200);
  assert.equal((await call("inventory/equip", "POST", { token: a.token, body: { slot: "cover", item_id: "frame_neon" } })).status, 403);   // wrong slot kind
  assert.equal((await call("me", "GET", { token: a.token })).body.user.equipped.frame, "frame_neon");
  assert.equal((await call("inventory/equip", "POST", { token: a.token, body: { slot: "frame", item_id: null } })).status, 200);
  assert.equal(sql(`SELECT equipped::text FROM users WHERE id='${a.id}'`), "{}");
  const blocker = await newUser("gD"); await match(blocker, c); await call("blocks", "POST", { token: c.token, body: { target_user: blocker.id } });
  assert.equal((await call("gifts", "POST", { token: blocker.token, body: { to_user: c.id, item_id: "gift_star" } })).status, 403);
});

test("challenges: progress computed server-side, one claim per day, free cosmetic reward", async () => {
  const a = await newUser("chA"), b = await newUser("chB");
  const list = async () => (await call("challenges", "GET", { token: a.token })).body.challenges;
  const bio = (await list()).find((x: any) => x.metric === "profile_bio_set"); assert.equal(bio.completed, false);
  assert.equal((await call("challenges/[id]/claim", "POST", { token: a.token, params: { id: bio.id } })).status, 409);
  await call("me", "PATCH", { token: a.token, body: { bio: "my bio" } });
  assert.equal((await list()).find((x: any) => x.id === bio.id).completed, true);
  const ok = await call("challenges/[id]/claim", "POST", { token: a.token, params: { id: bio.id } }); assert.equal(ok.status, 200);
  assert.equal((await call("challenges/[id]/claim", "POST", { token: a.token, params: { id: bio.id } })).status, 409);
  if (ok.body.reward_item) assert.equal(sql(`SELECT count(*) FROM user_items WHERE user_id='${a.id}' AND item_id='${ok.body.reward_item}'`), "1");
  assert.equal((await call("challenges/[id]/claim", "POST", { token: a.token, params: { id: "missing" } })).status, 404);
  void b;
});

test("rewarded ad claims are capped per day and only grant cosmetics", async () => {
  const a = await newUser("adA"); let last = 0;
  for (let i = 0; i < 4; i++) last = (await call("rewards/ad", "POST", { token: a.token })).status;
  assert.equal(last, 429); assert.equal(sql(`SELECT count(*) FROM rewarded_ad_claims WHERE user_id='${a.id}'`), "3");
});

test("occasions admin CRUD is permission-gated and notifications are created by cron", async () => {
  const adm = await staff("admin", "oadm"); const u = await newUser("occU");
  const body = { name: "Test Day", starts_at: new Date(Date.now() - 60_000).toISOString(), ends_at: new Date(Date.now() + 3600_000).toISOString(), message: { en: "Hello", ar: "مرحبا" }, send_in_app: true };
  assert.equal((await call("admin/occasions", "POST", { token: u.token, body })).status, 403);
  assert.equal((await call("admin/occasions", "POST", { token: adm.token, body: { ...body, message: { en: "x" } } })).status, 422);
  const c = await call("admin/occasions", "POST", { token: adm.token, body }); assert.equal(c.status, 201);
  const run = await call("cron/occasions", "GET", { token: "cron-secret-for-tests-123" }); assert.equal(run.status, 200);
  assert.ok((await call("notifications", "GET", { token: u.token })).body.notifications.some((n: any) => n.kind === "occasion"));
  assert.equal((await call("admin/occasions/[id]", "PATCH", { token: adm.token, params: { id: c.body.id }, body: { ...body, name: "Renamed" } })).status, 200);
  assert.equal((await call("admin/occasions", "GET", { token: adm.token })).body.occasions[0].in_app_sent >= 1, true);
  assert.equal((await call("admin/occasions/[id]", "DELETE", { token: adm.token, params: { id: c.body.id } })).status, 200);
});

test("sessions can be listed and revoked; fcm token stored on the device; security events visible", async () => {
  const u = await newUser("sess");
  const l = await call("me/sessions", "GET", { token: u.token }); assert.ok(l.body.sessions.length >= 1);
  assert.equal((await call("devices/fcm", "POST", { token: u.token, body: { fcm_token: "t".repeat(40) } })).status, 200);
  assert.equal(sql(`SELECT count(*) FROM devices WHERE user_id='${u.id}' AND fcm_token IS NOT NULL`), "1");
  const second = await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: u.install } });
  const sid = (await call("me/sessions", "GET", { token: second.body.access_token })).body.sessions.find((s: any) => s.id !== l.body.current).id;
  assert.equal((await call("me/sessions/[id]", "DELETE", { token: u.token, params: { id: sid } })).status, 200);
  assert.equal((await call("me/sessions/[id]", "DELETE", { token: u.token, params: { id: "00000000-0000-0000-0000-000000000000" } })).status, 404);
  assert.equal((await call("me/security", "GET", { token: u.token })).status, 200);
});

test("ad placements: fixed set, disabled by default, Owner-configurable, validated", async () => {
  const owner = await staff("owner", "ownr"); const adm = await staff("admin", "adadm");
  const list = (await call("admin/ads", "GET", { token: owner.token })).body.placements;
  assert.deepEqual(list.map((p: any) => p.placement).sort(), ["app_open", "discovery_native", "home_feed", "rewarded_cosmetic", "rewarded_interstitial_cosmetic", "tab_transition"]); assert.ok(list.every((p: any) => p.enabled === false));
  assert.equal((await call("admin/ads", "GET", { token: adm.token })).status, 403);   // not granted by default
  assert.equal((await call("admin/ads", "PUT", { token: owner.token, body: { placement: "chat_thread", enabled: true } })).status, 403);   // no ads in chat, ever
  const lowerGap = await call("admin/ads", "PUT", { token: owner.token, body: { placement: "home_feed", min_gap_sec: 5 } });
  assert.equal(lowerGap.status, 200); assert.equal(lowerGap.body.min_gap_sec, 120); // hard safety floor cannot be lowered
  const enabled = await call("admin/ads", "PUT", { token: owner.token, body: { placement: "home_feed", enabled: true, min_gap_sec: 90 } });
  assert.equal(enabled.status, 200); assert.equal(enabled.body.min_gap_sec, 120);
  assert.equal((await call("config", "GET")).body.ads.find((p: any) => p.placement === "home_feed").enabled, true);
});
