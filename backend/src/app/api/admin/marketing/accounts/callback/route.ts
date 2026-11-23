import { handle, json, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import { env } from "@/lib/env";
import { encrypt } from "@/lib/crypto";
import { OAUTH, verifyState } from "@/lib/oauth";
/** OAuth redirect target. State must be valid, unexpired and from a user who still holds marketing.manage. Tokens are stored AES-256-GCM encrypted.
 *  NOTE: the token exchange below follows each platform's documented OAuth 2.0 code flow but is NOT verified against the live platforms in this repository's tests. */
export const GET = handle(async (r) => {
  const sp = new URL(r.url).searchParams; const st = verifyState(sp.get("state") ?? ""); const code = sp.get("code");
  if (!st || !code) throw new HttpError(400, "invalid_state");
  const who = (await q<{ role: string }>("SELECT role FROM users WHERE id=$1 AND status='active'", [st.u]))[0];
  const ok = who && (who.role === "owner" || (await q("SELECT 1 FROM staff_permissions WHERE user_id=$1 AND permission='marketing.manage'", [st.u])).length); if (!ok) throw new HttpError(403, "forbidden");
  const o = OAUTH[st.p];
  const res = await fetch(o.token, { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ grant_type: "authorization_code", code, client_id: process.env[o.idVar] ?? "", client_secret: process.env[o.secretVar] ?? "", redirect_uri: `${env("APP_PUBLIC_URL")}/api/admin/marketing/accounts/callback` }) });
  if (!res.ok) throw new HttpError(502, "token_exchange_failed");
  const t: any = await res.json(); if (typeof t.access_token !== "string") throw new HttpError(502, "token_exchange_failed");
  const extId = String(t.open_id ?? t.user_id ?? t.page_id ?? "primary");
  const row = (await q<{ id: string }>("INSERT INTO social_accounts(platform,external_id,token_enc,refresh_token_enc,linked_by,expires_at,status) VALUES ($1,$2,$3,$4,$5, CASE WHEN $6::int IS NULL THEN NULL ELSE now()+($6::int||' seconds')::interval END,'linked') ON CONFLICT (platform,external_id) DO UPDATE SET token_enc=EXCLUDED.token_enc,refresh_token_enc=EXCLUDED.refresh_token_enc,expires_at=EXCLUDED.expires_at,status='linked',linked_by=EXCLUDED.linked_by RETURNING id",
    [st.p, extId, encrypt(t.access_token, env("DATA_ENCRYPTION_KEY")), t.refresh_token ? encrypt(String(t.refresh_token), env("DATA_ENCRYPTION_KEY")) : null, st.u, Number.isInteger(t.expires_in) ? t.expires_in : null]))[0];
  await q("INSERT INTO audit_log(actor_id,actor_role,action,target_type,target_id) VALUES ($1,$2,'marketing.account_link','social_account',$3)", [st.u, who!.role, row.id]); void clientIp;
  return json({ linked: true, account_id: row.id });
});
