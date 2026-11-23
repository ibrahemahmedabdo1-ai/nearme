import { handle, json, auth, body, str } from "@/lib/http";
import { q } from "@/lib/db";
export const POST = handle(async (r) => {
  const c = await auth(r); const { token } = await body(r, x => ({ token: str(x.fcm_token, "fcm_token", 20, 4096) }));
  await q("UPDATE devices SET fcm_token=$2,last_seen_at=now() WHERE id=(SELECT device_id FROM sessions WHERE id=$1) AND revoked_at IS NULL", [c.sid, token]);
  return json({ ok: true });
});
