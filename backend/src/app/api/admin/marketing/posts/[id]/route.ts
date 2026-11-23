import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
/** Workflow: draft -> pending_approval (submit) -> approved (approve). With marketing.require_approval (default true) only the Owner approves. Publishing is done by the cron, never here. */
export const PATCH = handle(async (r, { params }) => {
  const c = await requirePermission(r, "marketing.manage"); const { id } = await params;
  const b = await body(r, x => { if (!["submit", "approve", "revert", "schedule"].includes(x.action)) throw new Error("invalid_action"); const d = x.scheduled_at ? new Date(x.scheduled_at) : null; if (d && isNaN(+d)) throw new Error("invalid_scheduled_at"); return { action: x.action as string, at: d ? d.toISOString() : null }; });
  const p = (await q<any>("SELECT status FROM social_posts WHERE id=$1", [id]))[0]; if (!p) throw new HttpError(404, "not_found");
  const need = ((await q<{ value: unknown }>("SELECT value FROM app_config WHERE key='marketing.require_approval'"))[0]?.value ?? true) !== false;
  if (b.action === "schedule") { if (!["draft", "pending_approval", "approved"].includes(p.status) || !b.at) throw new HttpError(409, "invalid_state"); await q("UPDATE social_posts SET scheduled_at=$2 WHERE id=$1", [id, b.at]); }
  else if (b.action === "submit") { if (p.status !== "draft") throw new HttpError(409, "invalid_state"); await q("UPDATE social_posts SET status=$2 WHERE id=$1", [id, need ? "pending_approval" : "approved"]); }
  else if (b.action === "approve") { if (p.status !== "pending_approval") throw new HttpError(409, "invalid_state"); if (need && c.role !== "owner") throw new HttpError(403, "owner_approval_required"); await q("UPDATE social_posts SET status='approved',approved_by=$2 WHERE id=$1", [id, c.sub]); }
  else { if (!["pending_approval", "approved", "failed", "blocked_no_api_access"].includes(p.status)) throw new HttpError(409, "invalid_state"); await q("UPDATE social_posts SET status='draft',approved_by=NULL,error=NULL WHERE id=$1", [id]); }
  await audit(c, `marketing.post_${b.action}`, { type: "social_post", id }, {}, clientIp(r)); return json({ ok: true });
});
