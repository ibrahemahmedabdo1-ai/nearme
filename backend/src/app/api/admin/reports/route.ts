import { handle, json, requirePermission } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => {
  await requirePermission(r, "reports.review"); const st = new URL(r.url).searchParams.get("status") ?? "open";
  if (!["open", "reviewing", "actioned", "dismissed"].includes(st)) return json({ error: "invalid_status" }, 422);
  return json({ reports: await q("SELECT r.id,r.category,r.details,r.status,r.created_at,r.target_user,t.display_name AS target_name FROM reports r JOIN users t ON t.id=r.target_user WHERE r.status=$1 ORDER BY (r.category IN ('csae','minor_safety')) DESC, r.created_at LIMIT 100", [st]) });   // child-safety reports first
});
