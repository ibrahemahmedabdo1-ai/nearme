import { handle, json, requirePermission, body, str, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
/** Seasonal automation: creates DRAFT posts (one per language) from an occasion. Never publishes; goes through the normal approval flow. */
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "marketing.manage");
  const b = await body(r, x => ({ occasion: str(x.occasion_id, "occasion_id", 36, 36), account: str(x.account_id, "account_id", 36, 36) }));
  const o = (await q<any>("SELECT name,message,starts_at FROM occasions WHERE id=$1", [b.occasion]))[0]; if (!o) throw new HttpError(404, "occasion_not_found");
  if (!(await q("SELECT 1 FROM social_accounts WHERE id=$1 AND status='linked'", [b.account])).length) throw new HttpError(404, "account_not_found");
  const camp = (await q<{ id: string }>("INSERT INTO marketing_campaigns(name,kind,occasion_id,created_by) VALUES ($1,'organic',$2,$3) RETURNING id", [o.name, b.occasion, c.sub]))[0].id;
  const ids: string[] = [];
  for (const lang of ["ar", "en"]) if (o.message?.[lang]) ids.push((await q<{ id: string }>("INSERT INTO social_posts(account_id,body,scheduled_at,created_by,campaign_id) VALUES ($1,$2,$3,$4,$5) RETURNING id", [b.account, JSON.stringify({ text: o.message[lang], lang }), o.starts_at, c.sub, camp]))[0].id);
  await audit(c, "marketing.from_occasion", { type: "occasion", id: b.occasion }, { drafts: ids.length }, clientIp(r)); return json({ campaign_id: camp, post_ids: ids }, 201);
});
