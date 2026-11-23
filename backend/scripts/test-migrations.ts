// Runs migrations on a throwaway DB and asserts critical DB-level guarantees. Needs a local Postgres + psql (set PGHOST/PGUSER etc.).
import { spawnSync } from "node:child_process";
import assert from "node:assert/strict";
const base = process.env.TEST_PG_URL ?? "postgresql://postgres@localhost:5432/postgres";
const db = `nearme_test_${Date.now()}`; const url = base.replace(/\/[^/]*$/, `/${db}`);
const sh = (u: string, sql: string) => spawnSync("psql", [u, "-v", "ON_ERROR_STOP=1", "-qAt", "-c", sql], { encoding: "utf8" });
const ok = (sql: string) => { const r = sh(url, sql); assert.equal(r.status, 0, `${sql}\n${r.stderr}`); return r.stdout.trim(); };
const fails = (sql: string, re: RegExp) => { const r = sh(url, sql); assert.notEqual(r.status, 0, `expected failure: ${sql}`); assert.match(r.stderr, re); };
assert.equal(sh(base, `CREATE DATABASE ${db}`).status, 0);
try {
  const run = () => spawnSync("node", ["--experimental-strip-types", "scripts/migrate.ts"], { env: { ...process.env, DATABASE_URL: url }, encoding: "utf8" });
  let r = run(); assert.equal(r.status, 0, r.stderr); assert.match(r.stdout, /applied 0001_core.sql/); assert.match(r.stdout, /applied 0002_intro_pending_only.sql/);
  r = run(); assert.equal(r.status, 0); assert.doesNotMatch(r.stdout, /applied/); // idempotent
  const u = (n: string, extra = "") => ok(`INSERT INTO users(email,display_name,birthdate${extra ? ",role" : ""}) VALUES ('${n}@x.io','${n}user','1995-01-01'${extra}) RETURNING id`).split("\n")[0];
  const a = u("alice"), b = u("bobby");
  fails(`INSERT INTO users(email,display_name,birthdate) VALUES ('kid@x.io','kiddo', CURRENT_DATE - INTERVAL '17 years')`, /check constraint/);
  u("owner", ",'owner'"); fails(`INSERT INTO users(email,display_name,birthdate,role) VALUES ('o2@x.io','owner2','1990-01-01','owner')`, /one_owner/);
  ok(`INSERT INTO devices(user_id,install_id_hash) VALUES ('${a}','h1')`); fails(`INSERT INTO devices(user_id,install_id_hash) VALUES ('${b}','h1')`, /one_account_per_device/);
  ok(`UPDATE devices SET revoked_at=now() WHERE install_id_hash='h1'`); ok(`INSERT INTO devices(user_id,install_id_hash) VALUES ('${b}','h1')`); // transfer after revoke
  const [lo, hi] = a < b ? [a, b] : [b, a];
  const conv = ok(`INSERT INTO conversations(user_a,user_b,initiator) VALUES ('${lo}','${hi}','${a}') RETURNING id`).split("\n")[0];
  fails(`INSERT INTO conversations(user_a,user_b,initiator) VALUES ('${lo}','${hi}','${a}')`, /conversations_user_a_user_b_key/); // no second request for same pair
  const send = (s: string, t = "text") => `INSERT INTO messages(conversation_id,sender_id,kind,body) VALUES ('${conv}','${s}','${t}','hi')`;
  ok(send(a)); ok(send(a, "image")); ok(send(a, "sticker")); fails(send(a), /intro_limit_reached/);
  ok(send(b)); ok(send(a)); // reply resets the streak
  ok(send(a)); ok(send(a)); fails(send(a), /intro_limit_reached/); ok(send(b)); // new streak limited again; reply clears it
  ok(`UPDATE conversations SET intro_status='accepted' WHERE id='${conv}'`); ok(send(a)); ok(send(a)); ok(send(a)); // accepted conversations are not limited
  ok(`INSERT INTO audit_log(actor_id,action) VALUES ('${a}','x')`); fails(`UPDATE audit_log SET action='y'`, /append-only/); fails(`DELETE FROM audit_log`, /append-only/);
  fails(`INSERT INTO staff_permissions(user_id,permission,granted_by) VALUES ('${a}','ownership.transfer','${b}')`, /check constraint/);
  fails(`INSERT INTO preferences(user_id,radius_km) VALUES ('${a}',7)`, /check constraint/);
  assert.equal(ok(`SELECT mode FROM emergency_state`), "normal");
  console.log("DB tests passed: migrations idempotent, 18+, single owner, one account/device, intro limit trigger, audit immutability, constraints");
} finally { sh(base, `DROP DATABASE IF EXISTS ${db}`); }
