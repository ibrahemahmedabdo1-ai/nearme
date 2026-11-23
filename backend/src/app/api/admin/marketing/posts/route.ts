import { handle, json, requirePermission, body, str, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => { await requirePermission(r, "marketing.manage"); return json({ posts: await q("SELECT p.id,a.platform,p.body,p.scheduled_at,p.status,p.error,p.published_at,p.external_post_id,p.metrics,p.campaign_id FROM social_posts p JOIN social_accounts a ON a.id=p.account_id ORDER BY p.scheduled_at DESC NULLS LAST LIMIT 200") }); });
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "marketing.manage");
  const b = await body(r, x => { const d = x.scheduled_at ? new Date(x.scheduled_at) : null; if (d && isNaN(+d)) throw new Error("invalid_scheduled_at"); return { account: str(x.account_id, "account_id", 36, 36), text: str(x.text, "text", 1, 2000), media: x.media_key ? str(x.media_key, "media_key", 1, 300) : null, at: d ? d.toISOString() : null, campaign: x.campaign_id ? str(x.campaign_id, "campaign_id", 36, 36) : null }; });
  if (!(await q("SELECT 1 FROM social_accounts WHERE id=$1 AND status='linked'", [b.account])).length) throw new HttpError(404, "account_not_found");
  const id = (await q<{ id: string }>("INSERT INTO social_posts(account_id,body,scheduled_at,created_by,media_key,campaign_id) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id", [b.account, JSON.stringify({ text: b.text }), b.at, c.sub, b.media, b.campaign]))[0].id;
  await audit(c, "marketing.post_create", { type: "social_post", id }, {}, clientIp(r)); return json({ id }, 201);   // always starts as a draft
});
