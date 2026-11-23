import { handle, json, requirePermission, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => {
  const c = await requirePermission(r, "users.read");
  const s = (new URL(r.url).searchParams.get("q") ?? "").slice(0, 60);
  const rows = await q("SELECT id,member_code,display_name,status,trust_score,country_code,created_at,last_seen_at FROM users WHERE role='customer' AND ($1='' OR display_name ILIKE '%'||$1||'%' OR email ILIKE $1||'%' OR member_code::text=$1) ORDER BY created_at DESC LIMIT 50", [s]);
  await audit(c, "users.search", undefined, { q_len: s.length }, clientIp(r));   // staff data access is audited; passwords/PINs are never selected
  return json({ users: rows });
});
