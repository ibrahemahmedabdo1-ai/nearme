import { handle, json, requirePermission, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
/** Staff user inspection. Every view is audited. Never returns hashes, PINs, secrets or precise location. */
export const GET = handle(async (r, { params }) => {
  const c = await requirePermission(r, "users.read"); const { id } = await params;
  const u = (await q<any>("SELECT id,member_code,display_name,role,status,gender,country_code,bio,trust_score,created_at,last_seen_at,email_verified_at IS NOT NULL AS email_verified FROM users WHERE id=$1", [id]))[0];
  if (!u) throw new HttpError(404, "not_found");
  await audit(c, "user.inspect", { type: "user", id }, {}, clientIp(r));
  return json({ user: u,
    punishments: await q("SELECT id,kind,points,reason,starts_at,ends_at,revoked_at FROM punishments WHERE user_id=$1 ORDER BY starts_at DESC LIMIT 50", [id]),
    reports_against: (await q<{ n: number }>("SELECT count(*)::int AS n FROM reports WHERE target_user=$1", [id]))[0].n,
    devices: (await q<{ n: number }>("SELECT count(*)::int AS n FROM devices WHERE user_id=$1 AND revoked_at IS NULL", [id]))[0].n,
    verification: (await q("SELECT method,status,created_at FROM verifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 5", [id])) });
});
