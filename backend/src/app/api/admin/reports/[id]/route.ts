import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
export const POST = handle(async (r, { params }) => {
  const c = await requirePermission(r, "reports.review"); const { id } = await params;
  const { status } = await body(r, x => { if (!["reviewing", "dismissed"].includes(x.status)) throw new Error("invalid_status"); return { status: x.status as string }; });
  const row = await q("UPDATE reports SET status=$2,assigned_to=$3 WHERE id=$1 AND status IN ('open','reviewing') RETURNING id", [id, status, c.sub]);
  if (!row.length) throw new HttpError(404, "not_found");
  await audit(c, "report.review", { type: "report", id }, { status }, clientIp(r)); return json({ ok: true });
});
