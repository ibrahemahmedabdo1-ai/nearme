import { handle, json, auth } from "@/lib/http";
import { q } from "@/lib/db";
/** My own login/security activity (what Security Center shows the member). */
export const GET = handle(async (r) => { const c = await auth(r); return json({ events: await q("SELECT kind,created_at,ip FROM security_events WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50", [c.sub]), logins: await q("SELECT created_at,ip FROM sessions WHERE user_id=$1 ORDER BY created_at DESC LIMIT 20", [c.sub]) }); });
