import { handle, json, requirePermission, body, str, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
/** Support recommends an action; only an Admin/Owner decides. A recommendation never applies a punishment by itself. */
export const GET = handle(async (r) => { await requirePermission(r, "users.moderate"); return json({ recommendations: await q("SELECT id,ticket_id,user_id,recommended,note,status,created_at FROM moderation_recommendations WHERE status='open' ORDER BY created_at LIMIT 100") }); });
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "tickets.reply");
  const b = await body(r, x => { if (!["warning", "message_restriction", "like_restriction", "suspension", "ban", "no_action"].includes(x.recommended)) throw new Error("invalid_recommended"); return { user: str(x.user_id, "user_id", 36, 36), ticket: x.ticket_id ? str(x.ticket_id, "ticket_id", 36, 36) : null, rec: x.recommended as string, note: str(x.note, "note", 3, 1000) }; });
  if (!(await q("SELECT 1 FROM users WHERE id=$1 AND role='customer'", [b.user])).length) throw new HttpError(404, "not_found");
  const row = (await q<{ id: string }>("INSERT INTO moderation_recommendations(ticket_id,user_id,recommended,note,created_by) VALUES ($1,$2,$3,$4,$5) RETURNING id", [b.ticket, b.user, b.rec, b.note, c.sub]))[0];
  await audit(c, "recommendation.create", { type: "user", id: b.user }, { recommended: b.rec }, clientIp(r)); return json({ id: row.id }, 201);
});
