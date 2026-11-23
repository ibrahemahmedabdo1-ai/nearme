import { handle, json, body, str, email, rateLimit, HttpError, clientIp, audit } from "@/lib/http";
import { q } from "@/lib/db";
import { verifyPassword } from "@/domain/password";
// Public web resource for Google Play "account deletion" requirement: users can delete without opening the app.
export const POST = handle(async (r) => {
  const b = await body(r, x => ({ email: email(x.email), password: str(x.password, "password", 1, 128) }));
  rateLimit(r, "web-delete-ip", 10, 3_600_000); rateLimit(r, "web-delete-acct", 5, 3_600_000, b.email);
  const u = (await q<any>("SELECT id,password_hash,role FROM users WHERE email=$1 AND status<>'deleted'", [b.email]))[0];
  if (!u || u.role !== "customer" || !u.password_hash || !(await verifyPassword(b.password, u.password_hash))) throw new HttpError(401, "invalid_credentials");
  await q("UPDATE users SET status='deleted',deleted_at=now(),email=NULL,google_sub=NULL,password_hash=NULL,bio=NULL,pin_hash=NULL,decoy_pin_hash=NULL,totp_secret_enc=NULL,display_name='Deleted user' WHERE id=$1", [u.id]);
  await q("UPDATE sessions SET revoked_at=now() WHERE user_id=$1", [u.id]); await q("UPDATE devices SET revoked_at=now() WHERE user_id=$1", [u.id]);
  await audit(null, "user.delete_web", { type: "user", id: u.id }, {}, clientIp(r));
  return json({ ok: true });
});
