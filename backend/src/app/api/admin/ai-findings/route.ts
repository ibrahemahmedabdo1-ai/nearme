import { handle, json, requirePermission } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => { await requirePermission(r, "reports.review"); return json({ findings: await q("SELECT id,user_id,kind,confidence,reason_codes,status,created_at FROM ai_findings WHERE status='needs_review' ORDER BY confidence DESC, created_at LIMIT 100") }); });
