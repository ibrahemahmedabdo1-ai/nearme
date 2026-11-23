import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";
export type AccessClaims = { sub: string; role: "customer" | "support" | "admin" | "owner"; sid: string; exp: number; iat: number };
const b64u = (b: Buffer | string) => Buffer.from(b).toString("base64url");

export function signAccessToken(c: Omit<AccessClaims, "iat" | "exp">, secret: string, ttlSec = 900, now = Date.now()): string {
  if (secret.length < 32) throw new Error("JWT secret too short");
  const iat = Math.floor(now / 1000);
  const body = b64u(JSON.stringify({ ...c, iat, exp: iat + ttlSec }));
  const head = b64u(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const sig = createHmac("sha256", secret).update(`${head}.${body}`).digest("base64url");
  return `${head}.${body}.${sig}`;
}
export function verifyAccessToken(token: string, secret: string, now = Date.now()): AccessClaims | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [h, b, s] = parts;
  try {
    if (JSON.parse(Buffer.from(h, "base64url").toString()).alg !== "HS256") return null;
    const exp = createHmac("sha256", secret).update(`${h}.${b}`).digest();
    const got = Buffer.from(s, "base64url");
    if (got.length !== exp.length || !timingSafeEqual(got, exp)) return null;
    const c = JSON.parse(Buffer.from(b, "base64url").toString()) as AccessClaims;
    return c.exp * 1000 > now ? c : null;
  } catch { return null; }
}
/** Opaque refresh token; only its SHA-256 is stored. Rotated on every use; reuse of an old token revokes the family. */
export function newRefreshToken() { const raw = randomBytes(48).toString("base64url"); return { raw, hash: hashRefresh(raw) }; }
export const hashRefresh = (raw: string) => createHash("sha256").update(raw).digest("hex");
