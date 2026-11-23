import { handle, json, requirePermission } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => {
  await requirePermission(r, "reports.review"); const st = new URL(r.url).searchParams.get("status") ?? "open";
  if (!["open", "upheld", "overturned"].includes(st)) return json({ error: "invalid_status" }, 422);
  return json({ appeals: await q("SELECT a.id,a.status,a.text,a.owner_final,a.created_at,p.kind,p.reason,u.display_name,u.member_code FROM appeals a JOIN punishments p ON p.id=a.punishment_id JOIN users u ON u.id=a.user_id WHERE a.status=$1 ORDER BY a.created_at LIMIT 100", [st]) });
});
