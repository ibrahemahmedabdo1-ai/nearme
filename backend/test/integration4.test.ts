// Feature batch 3: chat media and Marketing Center.
import { test } from "node:test";
import assert from "node:assert/strict";
import { call, newUser, staff, sql } from "./harness/helpers.ts";

const conv = async (a: any, b: any) => { await call("swipes", "POST", { token: a.token, body: { to_user: b.id, kind: "like" } }); await call("swipes", "POST", { token: b.token, body: { to_user: a.id, kind: "like" } }); return sql(`SELECT id FROM conversations WHERE '${a.id}' IN (user_a,user_b) AND '${b.id}' IN (user_a,user_b)`); };

test("chat media: scan fails closed, downloads limited to participants, GIF urls validated", async () => {
  const a = await newUser("mdA"), b = await newUser("mdB"), c = await newUser("mdC"); const id = await conv(a, b);
  const att = sql(`INSERT INTO attachments(owner_id,storage_key,mime,size_bytes,sha256) VALUES ('${a.id}','u/${a.id}/x.png','image/png',100,'${"a".repeat(64)}') RETURNING id`).split("\n")[0];
  assert.equal((await call("uploads/complete", "POST", { token: a.token, body: { attachment_id: att } })).status, 501);   // no scanner: stays pending
  assert.equal(sql(`SELECT scan_status FROM attachments WHERE id='${att}'`), "pending");
  assert.equal((await call("uploads/complete", "POST", { token: b.token, body: { attachment_id: att } })).status, 404);   // not the owner
  const send = () => call("conversations/[id]/messages", "POST", { token: a.token, params: { id }, body: { kind: "image", attachment_id: att } });
  assert.equal((await send()).status, 422);   // unscanned cannot be sent
  sql(`UPDATE attachments SET scan_status='clean' WHERE id='${att}'`);
  const m = await send(); assert.equal(m.status, 201);
  assert.equal((await call("attachments/[id]", "GET", { token: b.token, params: { id: att } })).status, 501);   // participant allowed, storage not configured
  assert.equal((await call("attachments/[id]", "GET", { token: c.token, params: { id: att } })).status, 404);   // stranger denied
  await call("conversations/[id]/messages/[mid]", "PATCH", { token: a.token, params: { id, mid: m.body.message.id }, body: { action: "delete_all" } });
  assert.equal((await call("attachments/[id]", "GET", { token: b.token, params: { id: att } })).status, 404);   // deleted for everyone
  const g = (url: string) => call("conversations/[id]/messages", "POST", { token: a.token, params: { id }, body: { kind: "gif", body: url } });
  assert.equal((await g("https://media.giphy.com/media/x/giphy.gif")).status, 201);
  assert.equal((await g("https://evil.example/x.gif")).status, 422); assert.equal((await g("http://media.giphy.com/x.gif")).status, 422); assert.equal((await g("javascript:alert(1)")).status, 422);
  assert.equal((await call("conversations/[id]/messages", "POST", { token: a.token, params: { id }, body: { kind: "location", body: "30.0444,31.2357" } })).status, 422); // location sharing is not part of Near Me chat
  assert.equal((await call("gifs", "GET", { token: a.token })).status, 501);
});

test("marketing: permission-gated, OAuth honest, approval workflow, never fake-publishes", async () => {
  const owner = await staff("owner", "ownr"); const adm = await staff("admin", "madm"); const u = await newUser("mkU");
  for (const [p, m] of [["admin/marketing/accounts", "GET"], ["admin/marketing/posts", "GET"], ["admin/marketing/campaigns", "GET"]] as const) { assert.equal((await call(p, m, { token: u.token })).status, 403); assert.equal((await call(p, m, { token: adm.token })).status, 403); assert.equal((await call(p, m, { token: owner.token })).status, 200); }
  assert.equal((await call("admin/marketing/accounts/link", "POST", { token: owner.token, body: { platform: "tiktok" } })).status, 501);   // not configured
  assert.equal((await call("admin/marketing/accounts/link", "POST", { token: owner.token, body: { platform: "myspace" } })).status, 422);
  process.env.X_CLIENT_ID = "cid"; process.env.APP_PUBLIC_URL = "https://app.example";
  const link = await call("admin/marketing/accounts/link", "POST", { token: owner.token, body: { platform: "x" } }); assert.equal(link.status, 200);
  assert.ok(link.body.authorize_url.startsWith("https://twitter.com/i/oauth2/authorize?client_id=cid")); assert.ok(link.body.authorize_url.includes("state="));
  assert.equal((await call("admin/marketing/accounts/callback", "GET", { query: "?code=abc&state=forged.sig" })).status, 400);   // CSRF state enforced
  const acc = sql(`INSERT INTO social_accounts(platform,external_id,token_enc,linked_by) VALUES ('x','acct1','enc','${owner.id}') RETURNING id`).split("\n")[0];
  assert.ok(!JSON.stringify((await call("admin/marketing/accounts", "GET", { token: owner.token })).body).includes("enc\""));   // no tokens leaked
  await call("admin/config", "GET", { token: owner.token });
  const post = await call("admin/marketing/posts", "POST", { token: owner.token, body: { account_id: acc, text: "Eid Mubarak", scheduled_at: new Date(Date.now() - 1000).toISOString() } }); assert.equal(post.status, 201);
  const act = (action: string, t = owner.token) => call("admin/marketing/posts/[id]", "PATCH", { token: t, params: { id: post.body.id }, body: { action } });
  assert.equal((await act("approve")).status, 409);   // cannot skip submit
  assert.equal((await act("submit")).status, 200); assert.equal(sql(`SELECT status FROM social_posts WHERE id='${post.body.id}'`), "pending_approval");
  assert.equal((await call("cron/social-publish", "GET", { token: "cron-secret-for-tests-123" })).body.published, 0);   // not approved yet
  assert.equal((await act("approve")).status, 200);
  const run = await call("cron/social-publish", "GET", { token: "cron-secret-for-tests-123" });
  assert.equal(run.body.blocked, 1); assert.equal(run.body.published, 0);
  assert.equal(sql(`SELECT status FROM social_posts WHERE id='${post.body.id}'`), "blocked_no_api_access");   // honest, not "published"
  assert.equal((await call("cron/social-publish", "GET", { token: "x" })).status, 401);
  assert.equal((await act("revert")).status, 200); assert.equal(sql(`SELECT status FROM social_posts WHERE id='${post.body.id}'`), "draft");
});

test("marketing: paid campaigns need Owner authorization; occasion drafts never auto-publish; AI advisory is honest", async () => {
  const owner = await staff("owner", "ownr");
  // an admin who was granted marketing.manage by the Owner can work but cannot authorize paid spend or approve posts
  const adm = await staff("admin", "mkadm"); sql(`INSERT INTO staff_permissions(user_id,permission,granted_by) VALUES ('${adm.id}','marketing.manage','${owner.id}')`);
  const camp = await call("admin/marketing/campaigns", "POST", { token: adm.token, body: { name: "Paid test", kind: "paid", budget_cents: 5000 } }); assert.equal(camp.status, 201);
  assert.equal((await call("admin/marketing/campaigns/[id]/authorize", "POST", { token: adm.token, params: { id: camp.body.id } })).status, 403);
  assert.equal((await call("admin/marketing/campaigns/[id]/authorize", "POST", { token: owner.token, params: { id: camp.body.id } })).status, 200);
  assert.equal(sql(`SELECT status FROM marketing_campaigns WHERE id='${camp.body.id}'`), "owner_authorized");
  assert.equal((await call("admin/marketing/campaigns/[id]/authorize", "POST", { token: owner.token, params: { id: camp.body.id } })).status, 409);
  assert.throws(() => sql(`INSERT INTO marketing_campaigns(name,kind,status,created_by) VALUES ('x','paid','running','${owner.id}')`));   // DB guarantee
  const acc = sql(`INSERT INTO social_accounts(platform,external_id,token_enc) VALUES ('facebook','pg1','enc') RETURNING id`).split("\n")[0];
  const oc = sql(`INSERT INTO occasions(name,starts_at,message,created_by) VALUES ('Spring','${new Date(Date.now() + 86400000).toISOString()}','{"en":"Happy spring","ar":"ربيع سعيد"}','${owner.id}') RETURNING id`).split("\n")[0];
  const d = await call("admin/marketing/from-occasion", "POST", { token: adm.token, body: { occasion_id: oc, account_id: acc } }); assert.equal(d.status, 201); assert.equal(d.body.post_ids.length, 2);
  assert.equal(sql(`SELECT count(*) FROM social_posts WHERE campaign_id='${d.body.campaign_id}' AND status='draft'`), "2");
  const post = d.body.post_ids[0]; await call("admin/marketing/posts/[id]", "PATCH", { token: adm.token, params: { id: post }, body: { action: "submit" } });
  assert.equal((await call("admin/marketing/posts/[id]", "PATCH", { token: adm.token, params: { id: post }, body: { action: "approve" } })).status, 403);   // owner approval required
  assert.equal((await call("admin/marketing/ai", "POST", { token: adm.token, body: { task: "draft_post", input: "spring sale" } })).status, 501);
  assert.equal((await call("admin/marketing/campaigns", "GET", { token: adm.token })).body.campaigns.some((c: any) => c.id === d.body.campaign_id && c.posts === 2), true);
});
