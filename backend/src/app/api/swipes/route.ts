import { handle, json, auth, body, str, guardMode, HttpError, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
const KINDS = ["like", "super_like", "pass", "favorite"];
export const POST = handle(async (r) => {
  const c = await auth(r); await guardMode("write", c); rateLimit(r, "swipe", 200, 3_600_000, c.sub);
  const b = await body(r, x => ({ to: str(x.to_user, "to_user", 36, 36), kind: KINDS.includes(x.kind) ? (x.kind as string) : (() => { throw new Error("invalid_kind"); })() }));
  if (b.to === c.sub) throw new HttpError(422, "invalid_target");
  const restricted = await q("SELECT 1 FROM punishments WHERE user_id=$1 AND kind='like_restriction' AND revoked_at IS NULL AND (ends_at IS NULL OR ends_at>now())", [c.sub]);
  if (restricted.length && b.kind !== "pass") throw new HttpError(403, "likes_restricted");
  if ((await q("SELECT 1 FROM blocks WHERE (blocker=$1 AND blocked=$2) OR (blocker=$2 AND blocked=$1)", [c.sub, b.to])).length) throw new HttpError(403, "blocked");
  await q("INSERT INTO swipes(from_user,to_user,kind) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING", [c.sub, b.to, b.kind]);
  let matched = false;
  if (b.kind === "like" || b.kind === "super_like") {
    const back = await q("SELECT 1 FROM swipes WHERE from_user=$2 AND to_user=$1 AND kind IN ('like','super_like')", [c.sub, b.to]);
    if (back.length) {
      const [lo, hi] = c.sub < b.to ? [c.sub, b.to] : [b.to, c.sub];
      await q("INSERT INTO matches(user_a,user_b) VALUES ($1,$2) ON CONFLICT DO NOTHING", [lo, hi]);
      await q("INSERT INTO conversations(user_a,user_b,kind,intro_status,initiator) VALUES ($1,$2,'match','accepted',$3) ON CONFLICT (user_a,user_b) DO UPDATE SET kind='match', intro_status='accepted'", [lo, hi, c.sub]);
      matched = true; // push + in-app match notification dispatched via PushProvider (awaiting FCM credentials)
    }
  }
  return json({ matched }, 201);
});
