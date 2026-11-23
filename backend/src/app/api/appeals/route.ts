import { handle, json, auth, body, str, email, HttpError, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
import { verifyPassword } from "@/domain/password";
// Suspended/banned members have no active session, so an appeal re-authenticates with email+password (no session needed).
export const POST = handle(async (r) => {
  const b = await body(r, x => ({ email: x.email ? email(x.email) : null, password: x.password ? str(x.password, "password", 1, 128) : null, pid: str(x.punishment_id, "punishment_id", 36, 36), text: str(x.text, "text", 10, 2000) }));
  let uid: string;
  if (r.headers.get("authorization")) uid = (await auth(r)).sub;
  else {
    if (!b.email || !b.password) throw new HttpError(401, "unauthorized");
    rateLimit(r, "appeal-login", 5, 3_600_000, b.email);
    const u = (await q<{ id: string; password_hash: string | null }>("SELECT id,password_hash FROM users WHERE email=$1 AND role='customer' AND status<>'deleted'", [b.email]))[0];
    if (!u?.password_hash || !(await verifyPassword(b.password, u.password_hash))) throw new HttpError(401, "invalid_credentials");
    uid = u.id;
  }
  rateLimit(r, "appeal", 5, 86_400_000, uid);
  if (!(await q("SELECT 1 FROM punishments WHERE id=$1 AND user_id=$2 AND revoked_at IS NULL", [b.pid, uid])).length) throw new HttpError(404, "not_found");
  if ((await q("SELECT 1 FROM appeals WHERE punishment_id=$1 AND status='open'", [b.pid])).length) throw new HttpError(409, "appeal_open");
  return json({ appeal_id: (await q<{ id: string }>("INSERT INTO appeals(punishment_id,user_id,text) VALUES ($1,$2,$3) RETURNING id", [b.pid, uid, b.text]))[0].id }, 201);
});
