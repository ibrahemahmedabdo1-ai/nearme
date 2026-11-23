import { handle, json, requirePermission, body, str, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import { occasionInput } from "@/lib/occasions";
export const GET = handle(async (r) => { await requirePermission(r, "occasions.edit"); return json({ occasions: await q("SELECT o.*,(SELECT count(*)::int FROM occasion_sends s WHERE s.occasion_id=o.id AND s.channel='in_app') AS in_app_sent,(SELECT count(*)::int FROM occasion_sends s WHERE s.occasion_id=o.id AND s.channel='push') AS push_sent FROM occasions o ORDER BY starts_at DESC LIMIT 200") }); });   // reporting
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "occasions.edit"); const o = await body(r, occasionInput);
  const row = (await q<{ id: string }>("INSERT INTO occasions(name,starts_at,ends_at,recurrence,countries,languages,image_key,message,send_push,send_in_app,theme_id,audience,created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id", [o.name, o.starts, o.ends, o.recurrence, o.countries, o.languages, o.image, JSON.stringify(o.message), o.push, o.inApp, o.theme, JSON.stringify(o.audience), c.sub]))[0];
  await audit(c, "occasion.create", { type: "occasion", id: row.id }, {}, clientIp(r)); return json({ id: row.id }, 201);
});
