import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
/** A human resolves the finding. Resolving NEVER punishes anyone automatically. */
export const PATCH = handle(async (r, { params }) => {
  const c = await requirePermission(r, "reports.review"); const { id } = await params;
  const b = await body(r, x => { if (!["confirmed", "dismissed"].includes(x.status)) throw new Error("invalid_status"); return { status: x.status as string }; });
  const u = await q("UPDATE ai_findings SET status=$2,reviewed_by=$3 WHERE id=$1 AND status='needs_review' RETURNING id", [id, b.status, c.sub]);
  if (!u.length) throw new HttpError(404, "not_found"); await audit(c, "ai_finding.resolve", { type: "ai_finding", id }, { status: b.status }, clientIp(r)); return json({ ok: true });
});
