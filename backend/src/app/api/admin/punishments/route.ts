import { handle, json, requirePermission, body, str, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import type { Permission } from "@/domain/permissions";
const NEED: Record<string, Permission> = { warning: "punish.warn", message_restriction: "punish.warn", like_restriction: "punish.warn", suspension: "punish.suspend", ban: "punish.ban" };
export const POST = handle(async (r) => {
  const b = await body(r, x => { if (!(x.kind in NEED)) throw new Error("invalid_kind"); return { user: str(x.user_id, "user_id", 36, 36), kind: x.kind as string, reason: str(x.reason, "reason", 3, 1000), points: Number.isInteger(x.points) ? Math.min(20, Math.max(0, x.points)) : 0, days: Number.isInteger(x.days) && x.days > 0 ? Math.min(365, x.days) : null, report: x.report_id ?? null }; });
  const c = await requirePermission(r, NEED[b.kind]);
  const t = (await q<{ role: string }>("SELECT role FROM users WHERE id=$1", [b.user]))[0];
  if (!t) throw new HttpError(404, "not_found"); if (t.role !== "customer") throw new HttpError(403, "cannot_punish_staff");   // staff are managed only by the Owner
  const p = (await q<{ id: string }>("INSERT INTO punishments(user_id,kind,points,reason,ends_at,issued_by,report_id) VALUES ($1,$2,$3,$4, CASE WHEN $5::int IS NULL THEN NULL ELSE now() + ($5::int || ' days')::interval END,$6,$7) RETURNING id", [b.user, b.kind, b.points, b.reason, b.days, c.sub, b.report]))[0];
  if (b.kind === "suspension") await q("UPDATE users SET status='suspended' WHERE id=$1", [b.user]);
  if (b.kind === "ban") { await q("UPDATE users SET status='banned' WHERE id=$1", [b.user]); await q("UPDATE sessions SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL", [b.user]); }
  // Warning-points threshold opens a REVIEW recommendation for a human; it never punishes automatically.
  const th = Number((await q<{ value: unknown }>("SELECT value FROM app_config WHERE key='warnings.review_threshold'"))[0]?.value ?? 10);
  const pts = (await q<{ n: number }>("SELECT coalesce(sum(points),0)::int AS n FROM punishments WHERE user_id=$1 AND revoked_at IS NULL AND (ends_at IS NULL OR ends_at>now())", [b.user]))[0].n;
  if (pts >= th && !(await q("SELECT 1 FROM moderation_recommendations WHERE user_id=$1 AND status='open'", [b.user])).length)
    await q("INSERT INTO moderation_recommendations(user_id,recommended,note,created_by) VALUES ($1,'suspension',$2,$3)", [b.user, `Warning points reached ${pts} (threshold ${th}); human review required.`, c.sub]);
  if (b.report) await q("UPDATE reports SET status='actioned' WHERE id=$1", [b.report]);
  await audit(c, `punish.${b.kind}`, { type: "user", id: b.user }, { reason_len: b.reason.length, points: b.points, days: b.days }, clientIp(r));
  return json({ punishment_id: p.id }, 201);
});
