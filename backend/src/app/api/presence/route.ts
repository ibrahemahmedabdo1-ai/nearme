import { handle, json, auth } from "@/lib/http";
import { q } from "@/lib/db";
export const POST = handle(async (r) => { const c = await auth(r); await q("UPDATE users SET last_seen_at=now() WHERE id=$1", [c.sub]); return json({ ok: true }); });   // heartbeat while the app is foreground; no location, no history
