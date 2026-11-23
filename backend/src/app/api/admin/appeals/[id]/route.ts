import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
// Staff decide; the Owner always has the final word (owner_final locks the decision against further staff changes).
export const POST = handle(async (r, { params }) => {
  const c = await requirePermission(r, "reports.review"); const { id } = await params;
  const { decision } = await body(r, x => { if (!["upheld", "overturned"].includes(x.decision)) throw new Error("invalid_decision"); return { decision: x.decision as string }; });
  const a = (await q<any>("SELECT * FROM appeals WHERE id=$1", [id]))[0];
  if (!a) throw new HttpError(404, "not_found");
  if (a.owner_final && c.role !== "owner") throw new HttpError(403, "owner_decision_final");
  if (a.status !== "open" && c.role !== "owner") throw new HttpError(409, "already_decided");
  await q("UPDATE appeals SET status=$2,reviewed_by=$3,owner_final=$4 WHERE id=$1", [id, decision, c.sub, c.role === "owner"]);
  if (decision === "overturned") {
    await q("UPDATE punishments SET revoked_at=now() WHERE id=$1", [a.punishment_id]);
    await q("UPDATE users SET status='active' WHERE id=$1 AND status IN ('suspended','banned') AND NOT EXISTS (SELECT 1 FROM punishments p WHERE p.user_id=users.id AND p.revoked_at IS NULL AND p.kind IN ('suspension','ban') AND (p.ends_at IS NULL OR p.ends_at>now()))", [a.user_id]);
  }
  await audit(c, "appeal.decide", { type: "appeal", id }, { decision, owner_final: c.role === "owner" }, clientIp(r));
  return json({ ok: true });
});
