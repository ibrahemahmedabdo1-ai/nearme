import { handle, json, requirePermission } from "@/lib/http";
import { q } from "@/lib/db";
// Real counts only. Metrics that have no data source yet are returned as null (UI shows "—"), never invented.
export const GET = handle(async (r) => {
  await requirePermission(r, "analytics.read");
  const [t] = await q<any>(`SELECT
    count(*) FILTER (WHERE role='customer' AND status<>'deleted')::int AS total_users,
    count(*) FILTER (WHERE created_at > now()-interval '7 days' AND role='customer')::int AS new_7d,
    count(*) FILTER (WHERE last_seen_at > now()-interval '1 day')::int AS dau,
    count(*) FILTER (WHERE last_seen_at > now()-interval '30 days')::int AS mau FROM users`);
  const [m] = await q<any>(`SELECT (SELECT count(*) FROM messages WHERE sent_at>now()-interval '1 day')::int AS messages_24h, (SELECT count(*) FROM matches WHERE created_at>now()-interval '1 day')::int AS matches_24h, (SELECT count(*) FROM reports WHERE status='open')::int AS open_reports, (SELECT count(*) FROM verifications WHERE status='pending')::int AS pending_verifications`);
  const countries = await q("SELECT country_code,count(*)::int AS n FROM users WHERE role='customer' AND country_code IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 10");
  const signups = await q("SELECT date_trunc('day',created_at)::date AS day,count(*)::int AS n FROM users WHERE created_at>now()-interval '30 days' AND role='customer' GROUP BY 1 ORDER BY 1");
  return json({ ...t, ...m, countries, signups, admob: null /* AdMob reporting API: awaiting Owner credentials */, retention: null /* needs >=30 days of data */ });
});
