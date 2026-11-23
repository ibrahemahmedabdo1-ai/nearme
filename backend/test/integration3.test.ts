// Feature batch 2: staff management, owner credentials, verification review, recommendations, backups, retention.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { call, newUser, staff, sql, pw, ownerCache } from "./harness/helpers.ts";

test("staff management is Owner-only; secrets shown once; owner-only permissions can never be granted", async () => {
  const owner = await staff("owner", "ownr"); const adm = await staff("admin", "sadm"); const u = await newUser("stfU");
  assert.equal((await call("admin/staff", "GET", { token: adm.token })).status, 403);
  assert.equal((await call("admin/staff", "POST", { token: u.token, body: {} })).status, 403);
  const c = await call("admin/staff", "POST", { token: owner.token, body: { email: "newsup@staff.test", display_name: "New Sup", role: "support" } });
  assert.equal(c.status, 201); assert.ok(c.body.initial_password && c.body.totp_secret);
  assert.ok(!sql(`SELECT password_hash||totp_secret_enc FROM users WHERE id='${c.body.id}'`).includes(c.body.initial_password));
  const { totp } = await import("../src/lib/totp.ts");
  const login = await call("auth/login", "POST", { body: { email: "newsup@staff.test", password: c.body.initial_password, totp: totp(c.body.totp_secret) } }); assert.equal(login.status, 200);
  assert.equal((await call("admin/staff", "POST", { token: owner.token, body: { email: "newsup@staff.test", display_name: "Dup", role: "admin" } })).status, 409);
  assert.equal((await call("admin/staff", "POST", { token: owner.token, body: { email: "x@staff.test", display_name: "Bad", role: "owner" } })).status, 422);
  const p = (perms: string[]) => call("admin/staff/[id]", "PATCH", { token: owner.token, params: { id: c.body.id }, body: { permissions: perms } });
  assert.equal((await p(["backup.run"])).status, 403); assert.equal((await p(["emergency.control"])).status, 403); assert.equal((await p(["nonsense"])).status, 422);
  assert.equal((await p(["analytics.read"])).status, 200);
  assert.equal((await call("admin/stats", "GET", { token: login.body.access_token })).status, 200);   // granted extra permission works
  assert.equal((await call("admin/staff/[id]", "PATCH", { token: owner.token, params: { id: owner.id }, body: { disabled: true } })).status, 404);   // owner not editable
  assert.equal((await call("admin/staff/[id]", "PATCH", { token: owner.token, params: { id: c.body.id }, body: { disabled: true } })).status, 200);
  assert.equal((await call("admin/stats", "GET", { token: login.body.access_token })).status, 401);   // sessions revoked
  assert.equal((await call("auth/login", "POST", { body: { email: "newsup@staff.test", password: c.body.initial_password, totp: totp(c.body.totp_secret) } })).status, 403);
});

test("owner 2FA rotation issues one-time recovery codes; recovery code logs in once", async () => {
  const owner = await staff("owner", "ownr"); const { totp } = await import("../src/lib/totp.ts");
  assert.equal((await call("admin/owner/credentials", "POST", { token: owner.token, body: { password: "wrong-password-x", totp: totp(owner.secret) } })).status, 401);
  const r = await call("admin/owner/credentials", "POST", { token: owner.token, body: { password: pw, totp: totp(owner.secret) } });
  assert.equal(r.status, 200); assert.equal(r.body.recovery_codes.length, 10);
  assert.equal(sql(`SELECT count(*) FROM owner_recovery_codes WHERE user_id='${owner.id}'`), "10");
  assert.ok(!sql(`SELECT string_agg(code_hash,',') FROM owner_recovery_codes`).includes(r.body.recovery_codes[0]));
  const code = r.body.recovery_codes[0];
  assert.equal((await call("auth/login", "POST", { body: { email: owner.email, password: pw, recovery_code: code } })).status, 200);
  assert.equal((await call("auth/login", "POST", { body: { email: owner.email, password: pw, recovery_code: code } })).status, 401);   // single use
  assert.equal((await call("auth/login", "POST", { body: { email: owner.email, password: pw, totp: totp(owner.secret) } })).status, 401);   // old secret rotated out
  ownerCache.secret = r.body.totp_secret; ownerCache.login = async () => (await call("auth/login", "POST", { body: { email: owner.email, password: pw, totp: totp(r.body.totp_secret) } })).body.access_token;
  void createHash;
});

test("verification review: support reviews, only admin approves, evidence is audited, AI is advisory", async () => {
  const sup = await staff("support", "vsup"); const adm = await staff("admin", "vadm"); const u = await newUser("verU");
  const v = sql(`INSERT INTO verifications(user_id,method,evidence_storage_key) VALUES ('${u.id}','live_selfie','evidence/${u.id}.jpg') RETURNING id`).split("\n")[0];
  assert.equal((await call("admin/verifications", "GET", { token: u.token })).status, 403);
  assert.equal((await call("admin/verifications", "GET", { token: sup.token })).body.verifications.length >= 1, true);
  const act = (t: string, action: string) => call("admin/verifications/[id]", "POST", { token: t, params: { id: v }, body: { action } });
  assert.equal((await act(sup.token, "approve")).status, 403);
  assert.equal((await act(sup.token, "evidence")).status, 501);   // storage not configured, honest
  assert.equal(sql(`SELECT count(*) FROM audit_log WHERE action='verification.evidence_access'`), "1");
  assert.equal((await act(sup.token, "analyze")).status, 501);
  assert.equal((await act(sup.token, "support_review")).status, 200); assert.equal((await act(sup.token, "support_review")).status, 409);
  assert.equal((await act(adm.token, "approve")).status, 200);
  assert.equal(sql(`SELECT status FROM verifications WHERE id='${v}'`), "approved");
  assert.equal((await act(adm.token, "bogus")).status, 422);
  assert.equal((await call("admin/ai-findings", "GET", { token: sup.token })).status, 200);
  const f = sql(`INSERT INTO ai_findings(user_id,kind,confidence,reason_codes) VALUES ('${u.id}','spam',0.9,'{x}') RETURNING id`).split("\n")[0];
  assert.equal((await call("admin/ai-findings/[id]", "PATCH", { token: sup.token, params: { id: f }, body: { status: "dismissed" } })).status, 200);
  assert.equal(sql(`SELECT status FROM users WHERE id='${u.id}'`), "active");   // never auto-punished
});

test("support recommends, admin decides; warning threshold opens a review, never an automatic ban", async () => {
  const sup = await staff("support", "rsup"); const adm = await staff("admin", "radm"); const u = await newUser("recU");
  const rec = await call("admin/recommendations", "POST", { token: sup.token, body: { user_id: u.id, recommended: "suspension", note: "repeated spam" } }); assert.equal(rec.status, 201);
  assert.equal((await call("admin/recommendations", "GET", { token: sup.token })).status, 403);
  assert.equal((await call("admin/recommendations/[id]", "PATCH", { token: sup.token, params: { id: rec.body.id }, body: { status: "accepted" } })).status, 403);
  assert.equal((await call("admin/recommendations/[id]", "PATCH", { token: adm.token, params: { id: rec.body.id }, body: { status: "accepted" } })).status, 200);
  assert.equal(sql(`SELECT status FROM users WHERE id='${u.id}'`), "active");
  const w = (pts: number) => call("admin/punishments", "POST", { token: adm.token, body: { user_id: u.id, kind: "warning", reason: "rule break", points: pts } });
  assert.equal((await w(6)).status, 201); assert.equal(sql(`SELECT count(*) FROM moderation_recommendations WHERE user_id='${u.id}' AND status='open'`), "0");
  assert.equal((await w(6)).status, 201); assert.equal(sql(`SELECT count(*) FROM moderation_recommendations WHERE user_id='${u.id}' AND status='open'`), "1");
  assert.equal(sql(`SELECT status FROM users WHERE id='${u.id}'`), "active");
  const t = sql(`INSERT INTO tickets(user_id,subject) VALUES ('${u.id}','help') RETURNING id`).split("\n")[0];
  assert.equal((await call("admin/tickets/[id]", "PATCH", { token: sup.token, params: { id: t }, body: { status: "escalated" } })).status, 200);
  assert.equal((await call("admin/tickets/[id]", "PATCH", { token: sup.token, params: { id: t }, body: { status: "bogus" } })).status, 422);
});

test("user inspection is audited and never exposes secrets", async () => {
  const sup = await staff("support", "isup"); const u = await newUser("insU");
  const r = await call("admin/users/[id]", "GET", { token: sup.token, params: { id: u.id } }); assert.equal(r.status, 200);
  assert.ok(!JSON.stringify(r.body).match(/password|pin_hash|totp|lat_cell|lon_cell/i));
  assert.equal(sql(`SELECT count(*) FROM audit_log WHERE action='user.inspect' AND target_id='${u.id}'`), "1");
  assert.equal((await call("admin/users/[id]", "GET", { token: u.token, params: { id: u.id } })).status, 403);
  assert.equal((await call("admin/users/[id]", "GET", { token: sup.token, params: { id: "00000000-0000-0000-0000-000000000000" } })).status, 404);
});

test("backups: Owner-only, restore needs typed confirmation + fresh TOTP", async () => {
  const owner = await staff("owner", "ownr"); const adm = await staff("admin", "badm"); const { totp } = await import("../src/lib/totp.ts");
  assert.equal((await call("admin/backups", "POST", { token: adm.token, body: { scope: "database" } })).status, 403);
  assert.equal((await call("admin/backups", "POST", { token: owner.token, body: { scope: "nope" } })).status, 422);
  const b = await call("admin/backups", "POST", { token: owner.token, body: { scope: "database" } }); assert.equal(b.status, 201);
  const rs = (confirm: string, code: string) => call("admin/backups/[id]/restore", "POST", { token: owner.token, params: { id: b.body.id }, body: { confirm, totp: code } });
  assert.equal((await rs("RESTORE", totp(owner.secret))).status, 422);
  assert.equal((await rs(`RESTORE ${b.body.id}`, "000000")).status, 401);
  assert.equal((await rs(`RESTORE ${b.body.id}`, totp(owner.secret))).status, 200);
  assert.equal(sql(`SELECT status FROM backups WHERE id='${b.body.id}'`), "restore_authorized");
  assert.equal((await call("admin/releases/compat", "GET", { token: owner.token })).body.migrations.length >= 5, true);
});

test("retention cron removes expired messages and evidence; requires the secret", async () => {
  const a = await newUser("rtA"), b = await newUser("rtB");
  const cv = sql(`INSERT INTO conversations(user_a,user_b,kind,intro_status,initiator) VALUES (LEAST('${a.id}'::uuid,'${b.id}'::uuid),GREATEST('${a.id}'::uuid,'${b.id}'::uuid),'match','accepted','${a.id}') RETURNING id`).split("\n")[0];
  sql(`INSERT INTO messages(conversation_id,sender_id,kind,body,expires_at) VALUES ('${cv}','${a.id}','text','old',now()-interval '1 hour'),('${cv}','${a.id}','text','new',now()+interval '1 hour')`);
  sql(`INSERT INTO verifications(user_id,method,status,evidence_storage_key,evidence_delete_after) VALUES ('${a.id}','live_selfie','rejected','k1',now()-interval '1 day')`);
  assert.equal((await call("cron/retention", "GET", { token: "wrong" })).status, 401);
  const r = await call("cron/retention", "GET", { token: "cron-secret-for-tests-123" });
  assert.equal(r.status, 200); assert.equal(r.body.messages_deleted, 1); assert.equal(r.body.evidence_cleared, 1);
  assert.equal(sql(`SELECT count(*) FROM messages WHERE conversation_id='${cv}'`), "1");
});

test("report and appeal queues list work for staff only; child-safety first", async () => {
  const sup = await staff("support", "qsup"); const a = await newUser("qA"), b = await newUser("qB");
  await call("reports", "POST", { token: a.token, body: { target_user: b.id, category: "spam" } }); await call("reports", "POST", { token: a.token, body: { target_user: b.id, category: "csae" } });
  assert.equal((await call("admin/reports", "GET", { token: a.token })).status, 403);
  const l = (await call("admin/reports", "GET", { token: sup.token })).body.reports; assert.equal(l[0].category, "csae");
  assert.equal((await call("admin/appeals", "GET", { token: sup.token })).status, 200); assert.equal((await call("admin/appeals", "GET", { token: sup.token, query: "?status=x" })).status, 422);
});
