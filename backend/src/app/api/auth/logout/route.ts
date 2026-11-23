import { handle, json, auth } from "@/lib/http";
import { q } from "@/lib/db";
export const POST = handle(async (r) => { const c = await auth(r); await q("UPDATE sessions SET revoked_at=now() WHERE id=$1", [c.sid]); return json({ ok: true }); });
