import { handle, json, requirePermission, body, str, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
/** Campaign reporting: per-campaign post counts and stored platform metrics. Paid campaigns stay 'draft' until the Owner authorizes. */
export const GET = handle(async (r) => { await requirePermission(r, "marketing.manage"); return json({ campaigns: await q("SELECT c.id,c.name,c.kind,c.status,c.budget_cents,c.authorized_by,c.created_at,count(p.id)::int AS posts,count(p.id) FILTER (WHERE p.status='published')::int AS published,count(p.id) FILTER (WHERE p.status='blocked_no_api_access')::int AS blocked FROM marketing_campaigns c LEFT JOIN social_posts p ON p.campaign_id=c.id GROUP BY c.id ORDER BY c.created_at DESC LIMIT 100") }); });
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "marketing.manage");
  const b = await body(r, x => { if (!["organic", "paid"].includes(x.kind)) throw new Error("invalid_kind"); if (x.budget_cents != null && (!Number.isInteger(x.budget_cents) || x.budget_cents < 0)) throw new Error("invalid_budget"); return { name: str(x.name, "name", 2, 80), kind: x.kind as string, budget: x.budget_cents ?? null, occasion: x.occasion_id ? str(x.occasion_id, "occasion_id", 36, 36) : null }; });
  const id = (await q<{ id: string }>("INSERT INTO marketing_campaigns(name,kind,budget_cents,occasion_id,created_by) VALUES ($1,$2,$3,$4,$5) RETURNING id", [b.name, b.kind, b.budget, b.occasion, c.sub]))[0].id;
  await audit(c, "marketing.campaign_create", { type: "campaign", id }, { kind: b.kind }, clientIp(r)); return json({ id, status: "draft" }, 201);
});
