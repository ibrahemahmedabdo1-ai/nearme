import { handle, json, requirePermission, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
/** ONLY the Owner can authorize a paid campaign. Authorizing does not spend money: no ad-platform API call is made by this system without separate credentials. */
export const POST = handle(async (r, { params }) => {
  const c = await requirePermission(r, "marketing.manage"); const { id } = await params;
  if (c.role !== "owner") throw new HttpError(403, "owner_only");
  const u = await q("UPDATE marketing_campaigns SET status='owner_authorized',authorized_by=$2,authorized_at=now() WHERE id=$1 AND kind='paid' AND status='draft' RETURNING id", [id, c.sub]);
  if (!u.length) throw new HttpError(409, "not_authorizable"); await audit(c, "marketing.campaign_authorize", { type: "campaign", id }, {}, clientIp(r)); return json({ ok: true });
});
