import { handle, json, body, str, rateLimit, HttpError, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import { hashRefresh } from "@/domain/tokens";
import { issueSession } from "@/lib/session";
export const POST = handle(async (r) => {
  rateLimit(r, "refresh", 60, 900_000);
  const { refresh_token } = await body(r, x => ({ refresh_token: str(x.refresh_token, "refresh_token", 20, 200) }));
  const s = (await q<any>("SELECT s.id,s.user_id,s.device_id,s.family_id,s.revoked_at,s.expires_at,u.role,u.status FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.refresh_hash=$1", [hashRefresh(refresh_token)]))[0];
  if (!s) throw new HttpError(401, "invalid_refresh");
  if (s.revoked_at) {   // reuse of a rotated token => theft suspected: revoke the whole family
    await q("UPDATE sessions SET revoked_at=now() WHERE family_id=$1 AND revoked_at IS NULL", [s.family_id]);
    await q("INSERT INTO security_events(user_id,kind) VALUES ($1,'refresh_token_reuse')", [s.user_id]);
    throw new HttpError(401, "invalid_refresh");
  }
  if (new Date(s.expires_at) < new Date() || ["banned", "deleted", "suspended"].includes(s.status)) throw new HttpError(401, "invalid_refresh");
  const upd = await q("UPDATE sessions SET revoked_at=now() WHERE id=$1 AND revoked_at IS NULL RETURNING id", [s.id]); // atomic: only one concurrent refresh wins
  if (!upd.length) throw new HttpError(401, "invalid_refresh");
  return json(await issueSession(s.user_id, s.role, s.device_id, clientIp(r), s.family_id));
});
