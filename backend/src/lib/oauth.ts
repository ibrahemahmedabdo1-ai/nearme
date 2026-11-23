import { createHmac, timingSafeEqual } from "node:crypto";
import { env } from "./env";
export type Platform = "facebook" | "instagram" | "tiktok" | "x";
export const OAUTH: Record<Platform, { auth: string; token: string; scope: string; idVar: string; secretVar: string }> = {
  facebook: { auth: "https://www.facebook.com/v21.0/dialog/oauth", token: "https://graph.facebook.com/v21.0/oauth/access_token", scope: "pages_manage_posts,pages_read_engagement", idVar: "FACEBOOK_CLIENT_ID", secretVar: "FACEBOOK_CLIENT_SECRET" },
  instagram: { auth: "https://www.facebook.com/v21.0/dialog/oauth", token: "https://graph.facebook.com/v21.0/oauth/access_token", scope: "instagram_basic,instagram_content_publish", idVar: "FACEBOOK_CLIENT_ID", secretVar: "FACEBOOK_CLIENT_SECRET" },
  tiktok: { auth: "https://www.tiktok.com/v2/auth/authorize/", token: "https://open.tiktokapis.com/v2/oauth/token/", scope: "video.publish", idVar: "TIKTOK_CLIENT_KEY", secretVar: "TIKTOK_CLIENT_SECRET" },
  x: { auth: "https://twitter.com/i/oauth2/authorize", token: "https://api.twitter.com/2/oauth2/token", scope: "tweet.read tweet.write users.read offline.access", idVar: "X_CLIENT_ID", secretVar: "X_CLIENT_SECRET" },
};
export const configured = (p: Platform) => !!process.env[OAUTH[p].idVar] && process.env[OAUTH[p].idVar] !== "none";
/** Signed, expiring state (CSRF protection for the OAuth round trip), bound to the staff member who started it. */
export function signState(userId: string, platform: Platform, ttlMs = 600_000): string {
  const p = Buffer.from(JSON.stringify({ u: userId, p: platform, e: Date.now() + ttlMs })).toString("base64url");
  return p + "." + createHmac("sha256", env("JWT_SECRET")).update("oauth:" + p).digest("base64url");
}
export function verifyState(state: string): { u: string; p: Platform } | null {
  const [p, sig] = state.split("."); if (!p || !sig) return null;
  const want = createHmac("sha256", env("JWT_SECRET")).update("oauth:" + p).digest(); const got = Buffer.from(sig, "base64url");
  if (got.length !== want.length || !timingSafeEqual(got, want)) return null;
  const d = JSON.parse(Buffer.from(p, "base64url").toString()); return d.e > Date.now() ? { u: d.u, p: d.p } : null;
}
