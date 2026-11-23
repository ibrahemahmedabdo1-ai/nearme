import { handle, json, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
import { env } from "@/lib/env";
import { getProviders } from "@/providers";
import { timingSafeEqual } from "node:crypto";
export const dynamic = "force-dynamic";
/** Vercel Cron target (see vercel.json). Authorization: Bearer $CRON_SECRET. Idempotent: occasion_sends PK prevents duplicate sends. */
export const GET = handle(async (r) => {
  const given = Buffer.from(r.headers.get("authorization") ?? ""), want = Buffer.from(`Bearer ${env("CRON_SECRET")}`);
  if (given.length !== want.length || !timingSafeEqual(given, want)) throw new HttpError(401, "unauthorized");
  const occ = await q<any>(`SELECT * FROM occasions WHERE starts_at<=now() AND (
      (recurrence='none' AND (ends_at IS NULL OR ends_at>now())) OR
      (recurrence='yearly' AND (to_char(now(),'MMDDHH24MI') >= to_char(starts_at,'MMDDHH24MI')) AND (ends_at IS NULL OR to_char(now(),'MMDDHH24MI') <= to_char(ends_at,'MMDDHH24MI'))))`);
  const year = new Date().getUTCFullYear(); const out: any[] = []; const prov = getProviders();
  for (const o of occ) {
    const users = await q<{ id: string; fcm_token: string | null; push: boolean; language: string }>(`SELECT u.id,(SELECT d.fcm_token FROM devices d WHERE d.user_id=u.id AND d.revoked_at IS NULL AND d.fcm_token IS NOT NULL LIMIT 1) AS fcm_token, p.push_enabled AND p.occasion_push_enabled AS push, p.language
      FROM users u JOIN preferences p ON p.user_id=u.id WHERE u.status='active' AND u.role='customer' AND ($1::text[] IS NULL OR u.country_code = ANY($1::text[])) AND ($2::text[] IS NULL OR p.language = ANY($2::text[]))`, [o.countries, o.languages]);
    let inApp = 0, pushed = 0, pushSkipped = 0;
    for (const u of users) {
      if (o.send_in_app) { const ins = await q("INSERT INTO occasion_sends(occasion_id,user_id,occurrence_year,channel) VALUES ($1,$2,$3,'in_app') ON CONFLICT DO NOTHING RETURNING 1", [o.id, u.id, year]); inApp += ins.length; if (ins.length) await q("INSERT INTO notifications(user_id,kind,title,body,data) VALUES ($1,'occasion',$2,$3,$4)", [u.id, o.name, String((o.message as any)?.[u.language] ?? (o.message as any)?.en ?? ""), JSON.stringify({ occasion: o.id, theme: o.theme_id })]); }
      if (o.send_push && u.push && u.fcm_token) {
        if ((await q("SELECT 1 FROM occasion_sends WHERE occasion_id=$1 AND user_id=$2 AND occurrence_year=$3 AND channel='push'", [o.id, u.id, year])).length) continue;
        const res = await prov.push.send([u.fcm_token], o.name, String((o.message as any)?.en ?? ""), { occasion: o.id });
        if (res.ok) { await q("INSERT INTO occasion_sends(occasion_id,user_id,occurrence_year,channel) VALUES ($1,$2,$3,'push') ON CONFLICT DO NOTHING", [o.id, u.id, year]); pushed++; } else pushSkipped++;   // never recorded as sent unless the provider confirmed
      }
    }
    out.push({ occasion: o.id, audience: users.length, in_app_new: inApp, push_sent: pushed, push_not_sent: pushSkipped });
  }
  return json({ processed: out });
});
