import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
export const PATCH = handle(async (r, { params }) => {
  const c = await requirePermission(r, "users.moderate"); const { id } = await params;
  const b = await body(r, x => { if (!["accepted", "declined"].includes(x.status)) throw new Error("invalid_status"); return { status: x.status as string }; });
  const u = await q("UPDATE moderation_recommendations SET status=$2,decided_by=$3 WHERE id=$1 AND status='open' RETURNING id", [id, b.status, c.sub]);
  if (!u.length) throw new HttpError(404, "not_found"); await audit(c, "recommendation.decide", { type: "recommendation", id }, { status: b.status }, clientIp(r));
  return json({ ok: true, note: "Accepting records the decision; apply the action through the punishments endpoint." });
});
