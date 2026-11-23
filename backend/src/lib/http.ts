import { NextRequest, NextResponse } from "next/server";
import { verifyAccessToken, type AccessClaims } from "@/domain/tokens";
import { RateLimiter } from "./rateLimit";
import { env } from "./env";
import { q } from "./db";
import { modeAllows, type Action, type EmergencyMode } from "@/domain/policy";
import { can, type Permission } from "@/domain/permissions";

export class HttpError extends Error {
  status: number; code: string;
  constructor(status: number, code: string) { super(code); this.status = status; this.code = code; }
}
export const json = (data: unknown, status = 200) => NextResponse.json(data, { status, headers: { "Cache-Control": "no-store" } });
export const clientIp = (r: NextRequest) => r.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "unknown";

const limiters = new Map<string, RateLimiter>();
export function rateLimit(r: NextRequest, bucket: string, max: number, windowMs: number, extraKey = "") {
  let l = limiters.get(bucket); if (!l) limiters.set(bucket, l = new RateLimiter(max, windowMs));
  // When a per-account/user key is given, the limit is per ACCOUNT (not per IP) so rotating IPs cannot bypass it.
  const res = l.check(extraKey ? `k:${extraKey}` : `ip:${clientIp(r)}`);
  if (!res.ok) throw new HttpError(429, "rate_limited");
}
export async function body<T>(r: NextRequest, validate: (x: any) => T): Promise<T> {
  const text = await r.text(); if (text.length > 32_768) throw new HttpError(413, "payload_too_large");
  let raw: unknown; try { raw = JSON.parse(text); } catch { throw new HttpError(400, "invalid_json"); }
  try { return validate(raw); } catch (e) { throw new HttpError(422, e instanceof Error ? e.message : "invalid_input"); }
}
export const str = (v: unknown, name: string, min: number, max: number): string => {
  if (typeof v !== "string" || v.length < min || v.length > max) throw new Error(`invalid_${name}`); return v;
};
export const email = (v: unknown): string => {
  const s = str(v, "email", 5, 254).trim().toLowerCase(); if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(s)) throw new Error("invalid_email"); return s;
};

export async function getEmergencyMode(): Promise<EmergencyMode> {
  const r = await q<{ mode: EmergencyMode }>("SELECT mode FROM emergency_state WHERE id");
  return r[0]?.mode ?? "normal";
}
export async function guardMode(action: Action, claims?: AccessClaims | null) {
  if (claims?.role === "owner") return;
  const staff = claims && claims.role !== "customer";
  if (!modeAllows(await getEmergencyMode(), staff && action !== "register" ? "staff_access" : action)) throw new HttpError(503, "service_restricted");
}
export async function auth(r: NextRequest): Promise<AccessClaims> {
  const h = r.headers.get("authorization"); if (!h?.startsWith("Bearer ")) throw new HttpError(401, "unauthorized");
  const c = verifyAccessToken(h.slice(7), env("JWT_SECRET")); if (!c) throw new HttpError(401, "unauthorized");
  // session must still be active (supports instant revocation / lockdown)
  const s = await q("SELECT 1 FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.id=$1 AND s.revoked_at IS NULL AND u.status IN ('active','hidden')", [c.sid]);
  if (!s.length) throw new HttpError(401, "session_revoked");
  return c;
}
export async function requirePermission(r: NextRequest, p: Permission): Promise<AccessClaims> {
  const c = await auth(r);
  const granted = (await q<{ permission: Permission }>("SELECT permission FROM staff_permissions WHERE user_id=$1", [c.sub])).map(x => x.permission);
  if (!can(c.role, granted, p)) throw new HttpError(403, "forbidden");
  return c;
}
export async function audit(actor: AccessClaims | null, action: string, target?: { type: string; id: string }, detail: object = {}, ip?: string) {
  await q("INSERT INTO audit_log(actor_id,actor_role,action,target_type,target_id,detail,ip) VALUES ($1,$2,$3,$4,$5,$6,$7)",
    [actor?.sub ?? null, actor?.role ?? null, action, target?.type ?? null, target?.id ?? null, JSON.stringify(detail), ip && ip !== "unknown" ? ip : null]);
}
type Handler = (r: NextRequest, ctx: any) => Promise<Response>;
export const handle = (h: Handler): Handler => async (r, ctx) => {
  try { return await h(r, ctx); }
  catch (e) {
    if (e instanceof HttpError) return json({ error: e.code }, e.status);
    console.error("unhandled", e instanceof Error ? e.message : "unknown"); // no stack/PII to client
    return json({ error: "internal_error" }, 500);
  }
};
