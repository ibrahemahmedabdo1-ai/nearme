import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import { getProviders } from "@/providers";
/** Support: support_review / analyze / evidence. Approval and rejection need verification.approve (Admin+). AI output is advisory only. */
export const POST = handle(async (r, { params }) => {
  const { id } = await params; const b = await body(r, x => { if (!["support_review", "approve", "reject", "analyze", "evidence"].includes(x.action)) throw new Error("invalid_action"); return { action: x.action as string }; });
  const c = await requirePermission(r, b.action === "approve" || b.action === "reject" ? "verification.approve" : "verification.review");
  const v = (await q<any>("SELECT id,status,evidence_storage_key FROM verifications WHERE id=$1", [id]))[0]; if (!v) throw new HttpError(404, "not_found");
  const ip = clientIp(r);
  if (b.action === "support_review") { if (v.status !== "pending") throw new HttpError(409, "invalid_state"); await q("UPDATE verifications SET status='support_reviewed',reviewed_by=$2 WHERE id=$1", [id, c.sub]); await audit(c, "verification.support_review", { type: "verification", id }, {}, ip); return json({ ok: true }); }
  if (b.action === "approve" || b.action === "reject") {
    if (!["support_reviewed", "pending", "appealed"].includes(v.status)) throw new HttpError(409, "invalid_state");
    await q("UPDATE verifications SET status=$2,approved_by=$3,evidence_delete_after=now()+interval '7 days' WHERE id=$1", [id, b.action === "approve" ? "approved" : "rejected", c.sub]);   // evidence scheduled for deletion by retention cron
    await audit(c, `verification.${b.action}`, { type: "verification", id }, {}, ip); return json({ ok: true });
  }
  if (!v.evidence_storage_key) throw new HttpError(404, "no_evidence");
  if (b.action === "evidence") {   // short-lived signed URL, every access audited
    const s = await getProviders().storage.presignDownload(v.evidence_storage_key, 60);
    await audit(c, "verification.evidence_access", { type: "verification", id }, {}, ip);
    if (!s.ok) return json({ error: "storage_not_configured" }, 501); return json({ url: s.data.url, expires_in: 60 });
  }
  const a = await getProviders().ai.analyze("verification_selfie", { imageKey: v.evidence_storage_key });   // advisory
  if (!a.ok) return json({ error: "ai_not_configured" }, 501);
  await q("UPDATE verifications SET ai_confidence=$2,ai_reason_codes=$3 WHERE id=$1", [id, a.data.confidence, a.data.reasonCodes]);
  return json({ confidence: a.data.confidence, reason_codes: a.data.reasonCodes, advisory: true });
});
