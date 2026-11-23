import { handle, json, requirePermission, body, str, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
export function occasionInput(x: any) {
  const iso = (v: unknown, n: string, optional = false) => { if (v == null && optional) return null; const d = new Date(String(v)); if (isNaN(+d)) throw new Error("invalid_" + n); return d.toISOString(); };
  const list = (v: unknown, n: string, re: RegExp) => { if (v == null) return null; if (!Array.isArray(v) || v.length > 100 || v.some(e => typeof e !== "string" || !re.test(e))) throw new Error("invalid_" + n); return v as string[]; };
  const msg = x.message; if (!msg || typeof msg !== "object" || typeof msg.en !== "string" || typeof msg.ar !== "string" || msg.en.length > 300 || msg.ar.length > 300) throw new Error("invalid_message");
  return { name: str(x.name, "name", 2, 80), starts: iso(x.starts_at, "starts_at"), ends: iso(x.ends_at, "ends_at", true), recurrence: ["none", "yearly"].includes(x.recurrence ?? "none") ? (x.recurrence ?? "none") : (() => { throw new Error("invalid_recurrence"); })(),
    countries: list(x.countries, "countries", /^[A-Za-z]{2}$/)?.map(s => s.toUpperCase()) ?? null, languages: list(x.languages, "languages", /^(ar|en)$/), message: msg, push: x.send_push === true, inApp: x.send_in_app !== false, theme: x.theme_id ?? null, audience: x.audience && typeof x.audience === "object" ? x.audience : {}, image: x.image_key ?? null };
}
export const GET = handle(async (r) => { await requirePermission(r, "occasions.edit"); return json({ occasions: await q("SELECT o.*,(SELECT count(*)::int FROM occasion_sends s WHERE s.occasion_id=o.id AND s.channel='in_app') AS in_app_sent,(SELECT count(*)::int FROM occasion_sends s WHERE s.occasion_id=o.id AND s.channel='push') AS push_sent FROM occasions o ORDER BY starts_at DESC LIMIT 200") }); });   // reporting
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "occasions.edit"); const o = await body(r, occasionInput);
  const row = (await q<{ id: string }>("INSERT INTO occasions(name,starts_at,ends_at,recurrence,countries,languages,image_key,message,send_push,send_in_app,theme_id,audience,created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id", [o.name, o.starts, o.ends, o.recurrence, o.countries, o.languages, o.image, JSON.stringify(o.message), o.push, o.inApp, o.theme, JSON.stringify(o.audience), c.sub]))[0];
  await audit(c, "occasion.create", { type: "occasion", id: row.id }, {}, clientIp(r)); return json({ id: row.id }, 201);
});
