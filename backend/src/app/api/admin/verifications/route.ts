import { handle, json, requirePermission } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => {
  await requirePermission(r, "verification.review"); const st = new URL(r.url).searchParams.get("status") ?? "pending";
  if (!["pending", "support_reviewed", "approved", "rejected", "appealed"].includes(st)) return json({ error: "invalid_status" }, 422);
  return json({ verifications: await q("SELECT v.id,v.user_id,u.display_name,v.method,v.status,v.ai_confidence,v.ai_reason_codes,(v.evidence_storage_key IS NOT NULL) AS has_evidence,v.created_at FROM verifications v JOIN users u ON u.id=v.user_id WHERE v.status=$1 ORDER BY v.created_at LIMIT 100", [st]) });
});
