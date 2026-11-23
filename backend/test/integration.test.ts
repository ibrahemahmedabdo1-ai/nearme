// Integration tests part 1. Run: npm run test:integration
import test from "node:test";
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { call, newUser, staff, sql, psql, pw, URL_DB } from "./harness/helpers.ts";

test("health", async () => { const r = await call("health", "GET"); assert.equal(r.status, 200); assert.equal(r.body.db, "up"); });

test("register: age gate, weak password, terms, duplicates, email verification", async () => {
  const base = { email: "a@x.io", password: pw, display_name: "Alice", birthdate: "1995-01-01", install_id: "install-id-aaaaaaaaaaaa", accept_terms: true };
  const year = new Date().getUTCFullYear() - 17;
  assert.equal((await call("auth/register", "POST", { body: { ...base, birthdate: `${year}-01-01` } })).body.error, "age_restricted");
  assert.equal((await call("auth/register", "POST", { body: { ...base, password: "weakpassword1" } })).body.error, "password_too_weak");
  assert.equal((await call("auth/register", "POST", { body: { ...base, accept_terms: false } })).body.error, "terms_required");
  assert.equal((await call("auth/register", "POST", { body: { ...base, email: "bad" } })).status, 422);
  const ok = await call("auth/register", "POST", { body: base }); assert.equal(ok.status, 201); assert.equal(ok.body.email_verification, "sent");
  assert.equal((await call("auth/register", "POST", { body: { ...base, email: "b@x.io" } })).body.error, "device_already_registered");
  assert.equal((await call("auth/register", "POST", { body: { ...base, install_id: "install-id-bbbbbbbbbbbb" } })).body.error, "email_taken");
  const mail = (globalThis as any).__mailOutbox.at(-1); const tok = /Token: (\S+?)<\/p>/.exec(mail.html)![1];
  assert.equal((await call("auth/email/verify", "POST", { body: { token: tok } })).status, 200);
  assert.equal((await call("auth/email/verify", "POST", { body: { token: tok } })).status, 400);   // single use
  const me = await call("me", "GET", { token: ok.body.access_token }); assert.equal(me.body.user.email_verified, true);
  assert.equal(JSON.stringify(me.body).includes("password"), false);
});

test("login: generic errors, rate limit, banned account", async () => {
  const u = await newUser("login");
  const bad = await call("auth/login", "POST", { body: { email: u.email, password: "wrong-password" } });
  const unknown = await call("auth/login", "POST", { body: { email: "nobody@x.io", password: "wrong-password" } });
  assert.equal(bad.status, 401); assert.deepEqual(bad.body, unknown.body);   // no account enumeration
  assert.equal((await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: u.install } })).status, 200);
  let last = 0; for (let i = 0; i < 9; i++) last = (await call("auth/login", "POST", { body: { email: "victim@x.io", password: "x" + i } })).status;
  assert.equal(last, 429);
});

test("refresh rotation and reuse detection revokes the family", async () => {
  const u = await newUser("refresh");
  const r1 = await call("auth/refresh", "POST", { body: { refresh_token: u.refresh } }); assert.equal(r1.status, 200);
  assert.equal((await call("me", "GET", { token: r1.body.access_token })).status, 200);
  assert.equal((await call("auth/refresh", "POST", { body: { refresh_token: u.refresh } })).status, 401);   // old token reused => theft
  assert.equal((await call("me", "GET", { token: r1.body.access_token })).status, 401);                    // whole family revoked
  assert.equal((await call("auth/refresh", "POST", { body: { refresh_token: r1.body.refresh_token } })).status, 401);
  assert.ok(Number(sql(`SELECT count(*) FROM security_events WHERE kind='refresh_token_reuse'`)) >= 1);
});

test("password recovery: no enumeration, single-use, logs out everywhere", async () => {
  const u = await newUser("recover");
  assert.equal((await call("auth/password/forgot", "POST", { body: { email: "ghost@x.io" } })).status, 202);
  assert.equal((await call("auth/password/forgot", "POST", { body: { email: u.email } })).status, 202);
  const tok = /Token: (\S+?)<\/p>/.exec((globalThis as any).__mailOutbox.at(-1).html)![1];
  assert.equal((await call("auth/password/reset", "POST", { body: { token: tok, password: "weak" } })).status, 422);
  assert.equal((await call("auth/password/reset", "POST", { body: { token: tok, password: "NewStr0ngPassw0rd" } })).status, 200);
  assert.equal((await call("auth/password/reset", "POST", { body: { token: tok, password: "AnotherStr0ngPass1" } })).status, 400);
  assert.equal((await call("me", "GET", { token: u.token })).status, 401);
  assert.equal((await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: u.install } })).status, 401);
  assert.equal((await call("auth/login", "POST", { body: { email: u.email, password: "NewStr0ngPassw0rd", install_id: u.install } })).status, 200);
});

test("discovery: radius, approximate distance only, blocks, no coordinates leaked", async () => {
  const me = await newUser("seeker"), near = await newUser("near"), mid = await newUser("mid"), far = await newUser("far"), blocked = await newUser("blk");
  for (const [u, lat, lon] of [[me, 30.0444, 31.2357], [near, 30.0500, 31.2400], [mid, 30.2000, 31.3000], [far, 31.2001, 29.9187], [blocked, 30.0450, 31.2360]] as const)
    assert.equal((await call("me/location", "POST", { token: u.token, body: { lat, lon } })).status, 200);
  sql(`INSERT INTO user_interests SELECT users.id, i.id FROM users, interests i WHERE users.id IN ('${me.id}','${near.id}') AND i.slug='travel'`);
  const def = await call("discover", "GET", { token: me.token });
  const names = def.body.results.map((x: any) => x.name); assert.equal(def.body.radius_km, 25);
  assert.ok(names.includes("nearUser") && !names.includes("farUser")); assert.ok(names.includes("blkUser"));
  const nearRes = def.body.results.find((x: any) => x.name === "nearUser");
  assert.ok(nearRes.distance_km > 0 && Number.isFinite(nearRes.distance_km) && nearRes.compatibility > 0); assert.ok(nearRes.reasons.some((x: string) => x.startsWith("shared_interests")));
  assert.equal(/lat|lon/i.test(JSON.stringify(def.body)), false);
  assert.ok((await call("discover", "GET", { token: me.token, query: "?radius=1" })).body.results.every((x: any) => x.distance_km <= 2));
  assert.ok((await call("discover", "GET", { token: me.token, query: "?radius=all" })).body.results.some((x: any) => x.name === "farUser"));
  assert.equal((await call("discover", "GET", { token: me.token, query: "?radius=7" })).status, 422);
  await call("blocks", "POST", { token: me.token, body: { target_user: blocked.id } });
  assert.ok(!(await call("discover", "GET", { token: me.token })).body.results.some((x: any) => x.name === "blkUser"));
  assert.ok(!(await call("discover", "GET", { token: blocked.token })).body.results.some((x: any) => x.name === "seekerUser"));   // symmetric
});

test("swipes: mutual like creates an accepted match conversation; self/blocked rejected", async () => {
  const a = await newUser("mA"), b = await newUser("mB");
  assert.equal((await call("swipes", "POST", { token: a.token, body: { to_user: a.id, kind: "like" } })).status, 422);
  assert.equal((await call("swipes", "POST", { token: a.token, body: { to_user: b.id, kind: "like" } })).body.matched, false);
  assert.equal((await call("swipes", "POST", { token: b.token, body: { to_user: a.id, kind: "super_like" } })).body.matched, true);
  assert.equal(sql(`SELECT intro_status FROM conversations WHERE kind='match' AND '${a.id}' IN (user_a,user_b)`), "accepted");
});

test("incoming likes list excludes answered and blocked members", async () => {
  const a = await newUser("lkA"), b = await newUser("lkB"), c = await newUser("lkC");
  await call("swipes", "POST", { token: b.token, body: { to_user: a.id, kind: "like" } }); await call("swipes", "POST", { token: c.token, body: { to_user: a.id, kind: "super_like" } });
  assert.equal((await call("likes/incoming", "GET", { token: a.token })).body.likes.length, 2);
  await call("swipes", "POST", { token: a.token, body: { to_user: b.id, kind: "pass" } }); await call("blocks", "POST", { token: a.token, body: { target_user: c.id } });
  assert.equal((await call("likes/incoming", "GET", { token: a.token })).body.likes.length, 0);
});

test("introduction requests: 3-message limit across types, no bypass, accept/reject, blocks", async () => {
  const a = await newUser("iA"), b = await newUser("iB"), c = await newUser("iC");
  const open = await call("conversations", "POST", { token: a.token, body: { to_user: b.id } }); assert.equal(open.status, 201);
  const id = open.body.conversation_id;
  const send = (tok: string, kind: string, body = "hi") => call("conversations/[id]/messages", "POST", { token: tok, params: { id }, body: { kind, body } });
  assert.equal((await send(a.token, "text")).status, 201); assert.equal((await send(a.token, "location", "30.1,31.2")).status, 201); assert.equal((await send(a.token, "sticker", "stk_smile")).status, 201);
  assert.equal((await send(a.token, "text")).body.error, "intro_limit_reached");
  const again = await call("conversations", "POST", { token: a.token, body: { to_user: b.id } }); assert.equal(again.body.existing, true); assert.equal(again.body.conversation_id, id);   // cannot open another request to bypass
  assert.equal((await call("conversations/[id]/respond", "POST", { token: a.token, params: { id }, body: { accept: true } })).status, 404);   // initiator cannot accept own request
  assert.equal((await call("conversations/[id]/respond", "POST", { token: b.token, params: { id }, body: { accept: true } })).status, 200);
  assert.equal((await send(a.token, "text", "after accept")).status, 201);
  // reject path
  const o2 = await call("conversations", "POST", { token: a.token, body: { to_user: c.id } }); const id2 = o2.body.conversation_id;
  assert.equal((await call("conversations/[id]/respond", "POST", { token: c.token, params: { id: id2 }, body: { accept: false } })).status, 200);
  assert.equal((await call("conversations/[id]/messages", "POST", { token: a.token, params: { id: id2 }, body: { kind: "text", body: "x" } })).body.error, "request_rejected");
  assert.equal((await call("conversations", "GET", { token: a.token })).body.conversations.length, 1);   // rejected ones are hidden
  // blocking stops messages
  await call("blocks", "POST", { token: b.token, body: { target_user: a.id } });
  assert.equal((await send(a.token, "text")).body.error, "blocked");
  assert.equal((await call("conversations", "POST", { token: a.token, body: { to_user: b.id } })).body.error, "blocked");
});

test("messages: list, read receipts privacy, temporary messages, delete for me / both, react, pin", async () => {
  const a = await newUser("mgA"), b = await newUser("mgB");
  sql(`UPDATE preferences SET temp_messages='24h' WHERE user_id='${a.id}'`);
  const id = (await call("conversations", "POST", { token: a.token, body: { to_user: b.id } })).body.conversation_id;
  await call("conversations/[id]/respond", "POST", { token: b.token, params: { id }, body: { accept: true } });
  const sent = (await call("conversations/[id]/messages", "POST", { token: a.token, params: { id }, body: { kind: "text", body: "temp msg" } })).body.message.id;
  const patch = (tok: string, action: string, extra: object = {}, mid = sent) => call("conversations/[id]/messages/[mid]", "PATCH", { token: tok, params: { id, mid }, body: { action, ...extra } });
  assert.equal(sql(`SELECT expires_at IS NULL FROM messages WHERE id='${sent}'`), "t");   // unread messages never expire
  assert.equal((await patch(a.token, "read")).status, 422);                                // cannot "read" own message
  sql(`UPDATE preferences SET read_receipts=false WHERE user_id='${b.id}'`);
  assert.equal((await patch(b.token, "read")).status, 200);
  const exp = Number(sql(`SELECT extract(epoch FROM expires_at-read_at) FROM messages WHERE id='${sent}'`)); assert.ok(Math.abs(exp - 86400) < 2);   // 24h after reading
  const listA = (await call("conversations/[id]/messages", "GET", { token: a.token, params: { id } })).body.messages; assert.equal(listA[0].read_at, null);   // B disabled receipts
  assert.ok((await call("conversations/[id]/messages", "GET", { token: b.token, params: { id } })).body.messages[0].read_at);
  assert.equal((await patch(b.token, "react", { emoji: "❤️" })).status, 200); assert.equal((await patch(a.token, "pin")).status, 200);
  const l2 = (await call("conversations/[id]/messages", "GET", { token: a.token, params: { id } })).body.messages[0]; assert.equal(l2.pinned, true); assert.equal(l2.reactions[0].emoji, "❤️");
  // expiry
  sql(`UPDATE messages SET expires_at=now()-interval '1 second' WHERE id='${sent}'`);
  assert.equal((await call("conversations/[id]/messages", "GET", { token: a.token, params: { id } })).body.messages.length, 0);
  // delete for me / both
  const m2 = (await call("conversations/[id]/messages", "POST", { token: a.token, params: { id }, body: { kind: "text", body: "second" } })).body.message.id;
  assert.equal((await patch(b.token, "delete_all", {}, m2)).body.error, "delete_window_closed");   // only the sender
  assert.equal((await patch(b.token, "delete_me", {}, m2)).status, 200);
  assert.equal((await call("conversations/[id]/messages", "GET", { token: b.token, params: { id } })).body.messages.length, 0);
  assert.equal((await call("conversations/[id]/messages", "GET", { token: a.token, params: { id } })).body.messages.length, 1);
  assert.equal((await patch(a.token, "delete_all", {}, m2)).status, 200);
  assert.equal((await call("conversations/[id]/messages", "GET", { token: a.token, params: { id } })).body.messages[0].body, null);
  const m3 = (await call("conversations/[id]/messages", "POST", { token: a.token, params: { id }, body: { kind: "text", body: "old" } })).body.message.id;
  sql(`UPDATE messages SET sent_at=now()-interval '30 minutes' WHERE id='${m3}'`);
  assert.equal((await patch(a.token, "delete_all", {}, m3)).body.error, "delete_window_closed");   // Owner window (10 min) elapsed
  assert.equal((await call("conversations/[id]/messages", "GET", { token: (await newUser("outsider")).token, params: { id } })).status, 404);   // non-participant
});

test("attachments must be scanned clean; uploads validate type and report missing storage honestly", async () => {
  const a = await newUser("upA"), b = await newUser("upB");
  const id = (await call("conversations", "POST", { token: a.token, body: { to_user: b.id } })).body.conversation_id;
  assert.equal((await call("conversations/[id]/messages", "POST", { token: a.token, params: { id }, body: { kind: "image" } })).body.error, "attachment_required");
  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0, 0, 0, 0]).toString("base64");
  const up = (name: string, mime: string) => call("uploads", "POST", { token: a.token, body: { name, mime, size: 1000, head_b64: png, sha256: "a".repeat(64) } });
  assert.equal((await up("virus.exe", "application/octet-stream")).body.error, "blocked_type");
  assert.equal((await up("photo.png", "image/png")).status, 501);   // storage provider not configured => honest 501, nothing faked
  const att = sql(`INSERT INTO attachments(owner_id,storage_key,mime,size_bytes,sha256) VALUES ('${a.id}','k1','image/png',10,'x') RETURNING id`).split("\n")[0];
  assert.equal((await call("conversations/[id]/messages", "POST", { token: a.token, params: { id }, body: { kind: "image", attachment_id: att } })).body.error, "attachment_not_ready");
  sql(`UPDATE attachments SET scan_status='clean' WHERE id='${att}'`);
  assert.equal((await call("conversations/[id]/messages", "POST", { token: a.token, params: { id }, body: { kind: "image", attachment_id: att } })).status, 201);
});

test("reports and blocks; child-safety reports raise a security event", async () => {
  const a = await newUser("rA"), b = await newUser("rB");
  assert.equal((await call("reports", "POST", { token: a.token, body: { target_user: b.id, category: "bogus" } })).status, 422);
  assert.equal((await call("reports", "POST", { token: a.token, body: { target_user: b.id, category: "csae", details: "x" } })).status, 201);
  assert.equal(sql(`SELECT count(*) FROM security_events WHERE kind='child_safety_report' AND user_id='${b.id}'`), "1");
  assert.equal((await call("blocks", "POST", { token: a.token, body: { target_user: a.id } })).status, 422);
});

test("RBAC: customers blocked from admin APIs; staff need 2FA; support limits; owner-only actions", async () => {
  const cust = await newUser("plain");
  assert.equal((await call("admin/stats", "GET", { token: cust.token })).status, 403);
  assert.equal((await call("admin/users", "GET")).status, 401);
  const sup = await staff("support", "sup"), adm = await staff("admin", "adm"), own = await staff("owner", "own");
  const noTotp = await call("auth/login", "POST", { body: { email: sup.email, password: pw } }); assert.equal(noTotp.status, 401); assert.equal(noTotp.body.error, "2fa_required");
  assert.equal((await call("auth/login", "POST", { body: { email: sup.email, password: pw, totp: "000000" } })).status, 401);
  assert.equal((await call("admin/stats", "GET", { token: sup.token })).status, 403);                        // support: no analytics
  assert.equal((await call("admin/stats", "GET", { token: adm.token })).status, 200);
  assert.equal((await call("admin/users", "GET", { token: sup.token })).status, 200);
  assert.ok(Number(sql(`SELECT count(*) FROM audit_log WHERE action='users.search'`)) >= 1);               // staff data access audited
  const stats = (await call("admin/stats", "GET", { token: adm.token })).body; assert.equal(stats.admob, null); assert.equal(stats.retention, null);   // no invented numbers
  // support tickets + identities
  const t = (await call("tickets", "POST", { token: cust.token, body: { subject: "Help me", text: "cannot login" } })).body.ticket_id;
  assert.equal((await call("admin/tickets", "GET", { token: sup.token })).body.tickets.length >= 1, true);
  assert.equal((await call("admin/tickets/[id]", "POST", { token: sup.token, params: { id: t }, body: { body: "hello", identity: "admin" } })).body.error, "identity_not_allowed");
  assert.equal((await call("admin/tickets/[id]", "POST", { token: sup.token, params: { id: t }, body: { body: "hello", identity: "anonymous" } })).body.error, "identity_not_allowed");
  assert.equal((await call("admin/tickets/[id]", "POST", { token: sup.token, params: { id: t }, body: { body: "hello", identity: "support" } })).status, 201);
  assert.equal((await call("admin/tickets/[id]", "POST", { token: sup.token, params: { id: t }, body: { body: "internal", internal_note: true } })).status, 201);
  assert.equal((await call("admin/tickets/[id]", "POST", { token: adm.token, params: { id: t }, body: { body: "as admin", identity: "admin" } })).status, 201);
  // owner-only
  assert.equal((await call("admin/emergency", "POST", { token: adm.token, body: { mode: "maintenance" } })).status, 403);
  assert.equal((await call("admin/releases", "POST", { token: adm.token, body: { version_name: "1.0.0", version_code: 1 } })).status, 403);
  assert.equal((await call("admin/releases", "POST", { token: own.token, body: { version_name: "1.0.0", version_code: 1, min_required: true } })).status, 201);
  assert.equal((await call("config", "GET")).body.min_version_code, 1);
  // staff can never be given forbidden permissions (DB CHECK) and cannot be punished by staff
  const bad = psql(URL_DB, `INSERT INTO staff_permissions(user_id,permission,granted_by) VALUES ('${adm.id}','ownership.transfer','${own.id}')`); assert.notEqual(bad.status, 0);
  assert.equal((await call("admin/punishments", "POST", { token: own.token, body: { user_id: adm.id, kind: "warning", reason: "test reason" } })).body.error, "cannot_punish_staff");
});

test("punishments, appeals with owner final decision, ban revokes sessions", async () => {
  const u = await newUser("punished"), adm = await staff("admin", "adm2"), own = await staff("owner", "own2");
  assert.equal((await call("admin/punishments", "POST", { token: adm.token, body: { user_id: u.id, kind: "ban", reason: "spam spam" } })).status, 403);   // ban is owner-only
  const sus = await call("admin/punishments", "POST", { token: adm.token, body: { user_id: u.id, kind: "suspension", reason: "harassment", days: 7, points: 5 } }); assert.equal(sus.status, 201);
  assert.equal((await call("me", "GET", { token: u.token })).status, 401);                  // suspended => cannot act
  assert.equal((await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: u.install } })).status, 200);   // can log in? status suspended is not banned/deleted
  const ap = await call("appeals", "POST", { body: { email: u.email, password: pw, punishment_id: sus.body.punishment_id, text: "I did nothing wrong" } }); assert.equal(ap.status, 201);
  assert.equal((await call("appeals", "POST", { body: { email: u.email, password: "wrong-pass", punishment_id: sus.body.punishment_id, text: "I did nothing wrong" } })).status, 401);
  assert.equal((await call("admin/appeals/[id]", "POST", { token: adm.token, params: { id: ap.body.appeal_id }, body: { decision: "upheld" } })).status, 200);
  assert.equal((await call("admin/appeals/[id]", "POST", { token: own.token, params: { id: ap.body.appeal_id }, body: { decision: "overturned" } })).status, 200);   // owner overrides staff
  assert.equal(sql(`SELECT status FROM users WHERE id='${u.id}'`), "active");
  assert.equal((await call("admin/appeals/[id]", "POST", { token: adm.token, params: { id: ap.body.appeal_id }, body: { decision: "upheld" } })).body.error, "owner_decision_final");
  const ban = await call("admin/punishments", "POST", { token: own.token, body: { user_id: u.id, kind: "ban", reason: "repeated abuse" } }); assert.equal(ban.status, 201);
  assert.equal((await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: u.install } })).status, 403);
});

test("message restriction and like restriction are enforced", async () => {
  const a = await newUser("resA"), b = await newUser("resB"), adm = await staff("admin", "adm3");
  await call("admin/punishments", "POST", { token: adm.token, body: { user_id: a.id, kind: "message_restriction", reason: "spam msgs", days: 3 } });
  await call("admin/punishments", "POST", { token: adm.token, body: { user_id: a.id, kind: "like_restriction", reason: "spam likes", days: 3 } });
  assert.equal((await call("conversations", "POST", { token: a.token, body: { to_user: b.id } })).body.error, "messaging_restricted");
  assert.equal((await call("swipes", "POST", { token: a.token, body: { to_user: b.id, kind: "like" } })).body.error, "likes_restricted");
});

test("ratings need genuine interaction and update trust score", async () => {
  const a = await newUser("rtA"), b = await newUser("rtB");
  const id = (await call("conversations", "POST", { token: a.token, body: { to_user: b.id } })).body.conversation_id;
  await call("conversations/[id]/respond", "POST", { token: b.token, params: { id }, body: { accept: true } });
  assert.equal((await call("ratings", "POST", { token: a.token, body: { ratee: b.id, conversation_id: id, stars: 5 } })).body.error, "interaction_required");
  for (let i = 0; i < 3; i++) { await call("conversations/[id]/messages", "POST", { token: a.token, params: { id }, body: { kind: "text", body: "a" + i } }); await call("conversations/[id]/messages", "POST", { token: b.token, params: { id }, body: { kind: "text", body: "b" + i } }); }
  assert.equal((await call("ratings", "POST", { token: a.token, body: { ratee: b.id, conversation_id: id, stars: 6 } })).status, 422);
  assert.equal((await call("ratings", "POST", { token: a.token, body: { ratee: b.id, conversation_id: id, stars: 5 } })).status, 201);
  assert.equal((await call("ratings", "POST", { token: a.token, body: { ratee: b.id, conversation_id: id, stars: 5 } })).body.error, "already_rated");
  assert.ok(Number(sql(`SELECT trust_score FROM users WHERE id='${b.id}'`)) >= 50);
});

test("App Builder config: data-only, draft -> publish -> rollback", async () => {
  const adm = await staff("admin", "adm4");
  const bad = await call("admin/config", "POST", { token: adm.token, body: { action: "draft", payload: { tabs: [{ name: "x", script: "alert(1)" }] } } }); assert.equal(bad.status, 422);
  assert.equal((await call("admin/config", "POST", { token: adm.token, body: { action: "draft", payload: { note: "<script>x</script>" } } })).status, 422);
  const v1 = (await call("admin/config", "POST", { token: adm.token, body: { action: "draft", payload: { primary: "#111111" } } })).body.id;
  assert.equal((await call("admin/config", "POST", { token: adm.token, body: { action: "publish", id: v1 } })).status, 200);
  const v2 = (await call("admin/config", "POST", { token: adm.token, body: { action: "draft", payload: { primary: "#222222" } } })).body.id;
  await call("admin/config", "POST", { token: adm.token, body: { action: "publish", id: v2 } });
  assert.equal((await call("config", "GET")).body.config["builder.app"].primary, "#222222");
  assert.equal((await call("admin/config", "POST", { token: adm.token, body: { action: "rollback", id: v1 } })).status, 200);
  assert.equal((await call("config", "GET")).body.config["builder.app"].primary, "#111111");
  assert.equal(sql(`SELECT count(*) FROM config_versions WHERE state='published'`), "1");
});

test("emergency modes: read_only blocks writes, security_lockdown revokes customer sessions, owner keeps access", async () => {
  const u = await newUser("emg"), v = await newUser("emg2"), own = await staff("owner", "own3");
  assert.equal((await call("admin/emergency", "POST", { token: own.token, body: { mode: "nonsense" } })).status, 422);
  await call("admin/emergency", "POST", { token: own.token, body: { mode: "read_only" } });
  assert.equal((await call("swipes", "POST", { token: u.token, body: { to_user: v.id, kind: "like" } })).body.error, "service_restricted");
  assert.equal((await call("discover", "GET", { token: u.token })).status, 200);   // reads still work
  assert.equal((await call("auth/register", "POST", { body: { email: "z@x.io", password: pw, display_name: "ZZ", birthdate: "1990-01-01", install_id: "zzzzzzzzzzzzzzzzzzzz", accept_terms: true } })).status, 503);   // read-only: registration is a write
  await call("admin/emergency", "POST", { token: own.token, body: { mode: "registration_lock" } });
  assert.equal((await call("auth/register", "POST", { body: { email: "z2@x.io", password: pw, display_name: "ZZ", birthdate: "1990-01-01", install_id: "yyyyyyyyyyyyyyyyyyyy", accept_terms: true } })).body.error, "service_restricted");
  await call("admin/emergency", "POST", { token: own.token, body: { mode: "security_lockdown" } });
  assert.equal((await call("me", "GET", { token: u.token })).status, 401);
  assert.equal((await call("me", "GET", { token: own.token })).status, 200);       // owner session survives
  assert.equal((await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: u.install } })).status, 503);
  await call("admin/emergency", "POST", { token: own.token, body: { mode: "normal" } });
  assert.equal((await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: u.install } })).status, 200);
  assert.equal(sql(`SELECT count(*) FROM audit_log WHERE action='emergency.set_mode'`), "4");
});

test("occasions cron: authenticated, targeted, never duplicates, push not recorded without provider", async () => {
  const a = await newUser("ocA"); const b = await newUser("ocB");
  sql(`UPDATE users SET country_code='EG' WHERE id='${a.id}'; UPDATE users SET country_code='US' WHERE id='${b.id}'; INSERT INTO devices(user_id,install_id_hash,fcm_token) VALUES ('${a.id}','h-oc','tok-1')`);
  const own = sql(`SELECT id FROM users WHERE role='owner' LIMIT 1`).split("\n")[0];
  sql(`INSERT INTO occasions(name,starts_at,recurrence,countries,message,send_push,send_in_app,created_by) VALUES ('Eid',now()-interval '1 hour','none','{EG}','{"en":"Eid Mubarak"}',true,true,'${own}')`);
  assert.equal((await call("cron/occasions", "GET")).status, 401);
  const r1 = await call("cron/occasions", "GET", { token: process.env.CRON_SECRET }); assert.equal(r1.status, 200);
  const o = r1.body.processed.find((x: any) => x.occasion); assert.equal(o.in_app_new, 1); assert.equal(o.push_sent, 0);
  const r2 = await call("cron/occasions", "GET", { token: process.env.CRON_SECRET }); assert.equal(r2.body.processed[0].in_app_new, 0);   // no duplicates
  assert.equal(sql(`SELECT count(*) FROM occasion_sends WHERE channel='push'`), "0");   // FCM not configured => not claimed as sent
  sql(`UPDATE preferences SET occasion_push_enabled=false WHERE user_id='${a.id}'`);
});

test("account deletion removes credentials and revokes everything (in-app and public web)", async () => {
  const u = await newUser("del"), w = await newUser("delweb");
  assert.equal((await call("me", "DELETE", { token: u.token })).status, 200);
  assert.equal((await call("auth/login", "POST", { body: { email: u.email, password: pw, install_id: u.install } })).status, 401);
  assert.equal(sql(`SELECT password_hash IS NULL AND email IS NULL FROM users WHERE id='${u.id}'`), "t");
  assert.equal((await call("public/delete-account", "POST", { body: { email: w.email, password: "wrong-password" } })).status, 401);
  assert.equal((await call("public/delete-account", "POST", { body: { email: w.email, password: pw } })).status, 200);
  assert.equal((await call("me", "GET", { token: w.token })).status, 401);
});
