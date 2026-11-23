import { handle, json, auth, body, str, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => {
  const c = await auth(r);
  const u = await q("SELECT id,member_code,display_name,bio,gender,country_code,trust_score,avatar_key,cover_key,equipped,boost_until,hidden_until,email_verified_at IS NOT NULL AS email_verified,email FROM users WHERE id=$1", [c.sub]);
  const interests = await q("SELECT i.slug FROM user_interests ui JOIN interests i ON i.id=ui.interest_id WHERE ui.user_id=$1", [c.sub]);
  return json({ user: u[0], interests: interests.map((x: any) => x.slug), role: c.role });   // never returns hashes, PINs or secrets
});
export const PATCH = handle(async (r) => {
  const c = await auth(r);
  const b = await body(r, x => ({ name: x.display_name === undefined ? null : str(x.display_name, "display_name", 2, 40), bio: x.bio === undefined ? null : (x.bio === "" ? "" : str(x.bio, "bio", 1, 500)), gender: x.gender === undefined ? null : str(x.gender, "gender", 1, 20), country: x.country_code === undefined ? null : str(x.country_code, "country_code", 2, 2).toUpperCase() }));
  await q("UPDATE users SET display_name=COALESCE($2,display_name), bio=CASE WHEN $3::text IS NULL THEN bio WHEN $3='' THEN NULL ELSE $3 END, gender=COALESCE($4,gender), country_code=COALESCE($5,country_code) WHERE id=$1", [c.sub, b.name, b.bio, b.gender, b.country]);
  return json({ ok: true });
});
export const DELETE = handle(async (r) => {   // in-app account deletion (also reachable via /delete-account web flow)
  const c = await auth(r);
  await q("UPDATE users SET status='deleted',deleted_at=now(),email=NULL,google_sub=NULL,password_hash=NULL,bio=NULL,pin_hash=NULL,decoy_pin_hash=NULL,totp_secret_enc=NULL,avatar_key=NULL,cover_key=NULL,display_name='Deleted user' WHERE id=$1 AND role='customer'", [c.sub]);
  await q("UPDATE sessions SET revoked_at=now() WHERE user_id=$1", [c.sub]);
  await q("UPDATE devices SET revoked_at=now(),fcm_token=NULL WHERE user_id=$1", [c.sub]);
  await q("INSERT INTO audit_log(actor_id,actor_role,action,target_type,target_id) VALUES ($1,'customer','user.delete','user',$2)", [c.sub, c.sub]);
  return json({ ok: true });
});
