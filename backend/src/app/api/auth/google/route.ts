import { handle, json, body, str, rateLimit, guardMode, HttpError, clientIp, audit } from "@/lib/http";
import { q } from "@/lib/db";
import { env } from "@/lib/env";
import { isAdult } from "@/domain/policy";
import { issueSession } from "@/lib/session";
import { createHash } from "node:crypto";
/** Google Sign-In: the app sends the Google ID token. We verify it with Google (signature, audience, expiry) -- never trust the client's claims.
 *  New accounts must also supply birthdate (18+), install_id and terms acceptance. Needs GOOGLE_CLIENT_ID (Web client ID) -- awaiting Owner credentials. */
export const POST = handle(async (r) => {
  rateLimit(r, "google", 20, 3_600_000);
  const b = await body(r, x => ({ id_token: str(x.id_token, "id_token", 20, 4096), install_id: str(x.install_id, "install_id", 16, 128), birthdate: x.birthdate ? str(x.birthdate, "birthdate", 10, 10) : null, display_name: x.display_name ? str(x.display_name, "display_name", 2, 40) : null, accept_terms: x.accept_terms === true }));
  const clientId = process.env.GOOGLE_CLIENT_ID; if (!clientId) throw new HttpError(501, "google_not_configured");
  const res = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(b.id_token)}`, { signal: AbortSignal.timeout(8000) });
  if (!res.ok) throw new HttpError(401, "invalid_google_token");
  const t = (await res.json()) as { aud?: string; sub?: string; email?: string; email_verified?: string | boolean; exp?: string; name?: string };
  if (t.aud !== clientId || !t.sub || !t.email || String(t.email_verified) !== "true" || Number(t.exp) * 1000 < Date.now()) throw new HttpError(401, "invalid_google_token");
  const existing = (await q<{ id: string; role: "customer"; status: string }>("SELECT id,role,status FROM users WHERE google_sub=$1", [t.sub]))[0];
  if (existing) {
    if (["banned", "deleted"].includes(existing.status)) throw new HttpError(403, "account_unavailable");
    await guardMode("read"); return json(await issueSession(existing.id, existing.role, null, clientIp(r)));
  }
  await guardMode("register");
  if (!b.accept_terms) throw new HttpError(422, "terms_required");
  if (!b.birthdate || isNaN(+new Date(b.birthdate))) throw new HttpError(422, "birthdate_required");
  if (!isAdult(new Date(b.birthdate + "T00:00:00Z"))) throw new HttpError(403, "age_restricted");
  const idHash = createHash("sha256").update(b.install_id).digest("hex");
  if ((await q("SELECT 1 FROM devices WHERE install_id_hash=$1 AND revoked_at IS NULL", [idHash])).length) throw new HttpError(409, "device_already_registered");
  let uid: string;
  try { uid = (await q<{ id: string }>("INSERT INTO users(email,email_verified_at,google_sub,display_name,birthdate) VALUES ($1, now(), $2, $3, $4) RETURNING id", [t.email.toLowerCase(), t.sub, b.display_name ?? (t.name ?? "Member").slice(0, 40), b.birthdate]))[0].id; }
  catch (e: any) { if (e?.code === "23505") throw new HttpError(409, "email_taken"); throw e; }   // same email already has a password account: link flow is a TODO (security review needed)
  await q("INSERT INTO preferences(user_id) VALUES ($1)", [uid]);
  const dev = await q<{ id: string }>("INSERT INTO devices(user_id,install_id_hash) VALUES ($1,$2) RETURNING id", [uid, idHash]);
  await audit(null, "user.register_google", { type: "user", id: uid }, {}, clientIp(r));
  return json({ user_id: uid, ...(await issueSession(uid, "customer", dev[0].id, clientIp(r))) }, 201);
});
