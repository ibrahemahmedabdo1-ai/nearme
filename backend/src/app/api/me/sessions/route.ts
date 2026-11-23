import { handle, json, auth } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => { const c = await auth(r); return json({ current: c.sid, sessions: await q("SELECT id,created_at,expires_at,ip,device_id FROM sessions WHERE user_id=$1 AND revoked_at IS NULL AND expires_at>now() ORDER BY created_at DESC", [c.sub]), devices: await q("SELECT id,platform,model,app_version,first_seen_at,last_seen_at,revoked_at FROM devices WHERE user_id=$1 ORDER BY first_seen_at DESC", [c.sub]) }); });
