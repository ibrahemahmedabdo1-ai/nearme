import { handle, json, requirePermission } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => {
  await requirePermission(r, "tickets.read");
  const st = new URL(r.url).searchParams.get("status") ?? "open";
  return json({ tickets: await q("SELECT t.id,t.subject,t.status,t.created_at,u.display_name,u.member_code FROM tickets t LEFT JOIN users u ON u.id=t.user_id WHERE t.status=$1 ORDER BY t.created_at DESC LIMIT 100", [st]) });
});
