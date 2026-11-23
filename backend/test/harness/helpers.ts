// Shared helpers for integration tests: REAL route handlers + REAL PostgreSQL.
import { before, after } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { NextRequest } from "next/server";

export const BASE = process.env.TEST_PG_URL ?? "postgresql:///postgres";
export const DB = `nearme_it_${Date.now()}`;
export const URL_DB = BASE.replace(/\/[^/]*$/, `/${DB}`);
process.env.DATABASE_URL = URL_DB; (process.env as any).NODE_ENV = "test";
process.env.JWT_SECRET = randomBytes(48).toString("base64"); process.env.DATA_ENCRYPTION_KEY = randomBytes(32).toString("base64"); process.env.CRON_SECRET = "cron-secret-for-tests-123";
export const psql = (u: string, sql: string) => spawnSync("psql", [u, "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" });

export type R = { status: number; body: any };
export const routes = new Map<string, any>();
export async function mod(path: string) { if (!routes.has(path)) routes.set(path, await import(`../../src/app/api/${path}/route.ts`)); return routes.get(path); }
export async function call(path: string, method: string, o: { body?: unknown; token?: string; params?: Record<string, string>; ip?: string; query?: string } = {}): Promise<R> {
  const m = await mod(path);
  const req = new NextRequest(`http://localhost/api/${path}${o.query ?? ""}`, { method, headers: { "content-type": "application/json", "x-forwarded-for": o.ip ?? "10.0.0." + Math.floor(Math.random() * 250), ...(o.token ? { authorization: `Bearer ${o.token}` } : {}) }, body: o.body === undefined ? undefined : JSON.stringify(o.body) });
  const res: Response = await m[method](req, { params: Promise.resolve(o.params ?? {}) });
  return { status: res.status, body: await res.json().catch(() => null) };
}
export const pw = "Str0ngPassw0rd!";
export let n = 0;
export async function newUser(name: string, birth = "1995-05-05") {
  n++; const email = `${name}${n}@test.io`;
  const install = randomBytes(16).toString("hex");
  const r = await call("auth/register", "POST", { body: { email, password: pw, display_name: name + "User", birthdate: birth, install_id: install, accept_terms: true } });
  assert.equal(r.status, 201, JSON.stringify(r.body));
  return { id: r.body.user_id as string, email, install, token: r.body.access_token as string, refresh: r.body.refresh_token as string };
}
export const sql = (s: string) => { const r = psql(URL_DB, s); assert.equal(r.status, 0, r.stderr); return r.stdout.trim(); };
export let ownerCache: any = null;
export async function staff(role: "support" | "admin" | "owner", name: string): Promise<any> {
  if (role === "owner" && ownerCache) return { ...ownerCache, token: await ownerCache.login() };   // DB allows exactly one owner
  const { hashPassword } = await import("../../src/domain/password.ts"); const { newTotpSecret, totp } = await import("../../src/lib/totp.ts"); const { encrypt } = await import("../../src/lib/crypto.ts");
  const secret = newTotpSecret(); const email = `${name}@staff.test`;
  const id = sql(`INSERT INTO users(email,email_verified_at,password_hash,role,display_name,birthdate,totp_secret_enc) VALUES ('${email}',now(),'${await hashPassword(pw)}','${role}','${name}','1985-01-01','${encrypt(secret, process.env.DATA_ENCRYPTION_KEY!)}') RETURNING id`).split("\n")[0];
  const login = async () => { const r = await call("auth/login", "POST", { body: { email, password: pw, totp: totp(secret) } }); assert.equal(r.status, 200, JSON.stringify(r.body)); return r.body.access_token as string; };
  const out = { id, email, secret, login, token: await login() }; if (role === "owner") ownerCache = out; return out;
}
before(() => {
  assert.equal(psql(BASE, `CREATE DATABASE ${DB}`).status, 0);
  const m = spawnSync("node", ["--experimental-strip-types", "scripts/migrate.ts"], { env: { ...process.env, DATABASE_URL: URL_DB }, encoding: "utf8" }); assert.equal(m.status, 0, m.stderr);
  sql(`INSERT INTO interests(slug,name_en,name_ar) VALUES ('travel','Travel','سفر'),('music','Music','موسيقى'),('sports','Sports','رياضة')`);
});
after(() => { psql(BASE, `DROP DATABASE IF EXISTS ${DB}`); });

